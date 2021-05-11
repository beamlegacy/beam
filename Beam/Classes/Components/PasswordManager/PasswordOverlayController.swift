//
//  PasswordOverlayController.swift
//  Beam
//
//  Created by Frank Lefebvre on 23/03/2021.
//

import Foundation
import BeamCore
import SwiftUI
import Promises

struct WebFieldAutofill: Codable {
    var id: String
    var value: String?
    var background: String?
}

class PasswordOverlayController: WebPageHolder {
    private let passwordStore: PasswordStore
    private let passwordManager: PasswordManager
    private var passwordMenuWindow: NSWindow?
    private var passwordMenuPosition: CGPoint = .zero
    private var webViewScrollPosition: CGPoint = .zero
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var inputFields: [String: AutofillInputField]
    private var currentlyFocusedElementId: String?

    private var loginFields: [String: AutofillInputField] {
        inputFields.filter { $0.value.type == .login }
    }

    private var passwordFields: [String: AutofillInputField] {
        inputFields.filter { $0.value.type == .password || $0.value.type == .newPassword }
    }

    init(passwordStore: PasswordStore, passwordManager: PasswordManager = .shared) {
        self.passwordStore = passwordStore
        self.passwordManager = passwordManager
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        inputFields = [:]
    }

    func detectInputFields() {
        page.executeJS("password_sendTextFields();", objectName: nil)
    }

    func updateInputFields(with jsResult: String) {
        guard let jsonData = jsResult.data(using: .utf8) else { return }
        let elements: [DOMInputElement]
        do {
            let decoded = try decoder.decode([DOMInputElement].self, from: jsonData)
            var unique = Set<DOMInputElement>()
            var deduplicated = [DOMInputElement]()
            for element in decoded {
                if !unique.contains(element) {
                    deduplicated.append(element)
                    unique.insert(element)
                }
            }
            elements = deduplicated
            Logger.shared.logDebug("🔑 decoded: \(elements)") // TODO: remove duplicates
        } catch {
            Logger.shared.logError(String(describing: error), category: .javascript)
            return
        }

        let passwordRelatedFields = passwordManager.autofillFields(from: elements)
        let initialIds = Set(inputFields.keys)
        let finalIds = Set(passwordRelatedFields.map(\.id))
        let addedIds = finalIds.subtracting(initialIds)

        // TODO: move evaluateJavaScript strings to constants
        if !addedIds.isEmpty {
            page.executeJS("beam_installSubmitHandler()", objectName: nil).then { _ in
                self.installFocusHandlers(addedIds: addedIds, webPage: self.page, passwordRelatedFields: passwordRelatedFields)
            }
        } else {
            installFocusHandlers(addedIds: addedIds, webPage: page, passwordRelatedFields: passwordRelatedFields)
        }
    }

    private func installFocusHandlers(addedIds: Set<String>, webPage: WebPage, passwordRelatedFields: [AutofillInputField]) {
        let formattedList = addedIds.map { "\"\($0)\"" }.joined(separator: ",")
        let focusScript = "beam_installFocusHandlers('[\(formattedList)]');"
        page.executeJS(focusScript, objectName: nil).then { _ in
            let addedInputFields = passwordRelatedFields.reduce(into: [String: AutofillInputField]()) { (dict, field) in
                if addedIds.contains(field.id) {
                    dict[field.id] = field
                }
            }
            self.inputFields.merge(addedInputFields) { (_, new) in new }
        }
    }

    func updateInputFocus(for elementId: String, becomingActive: Bool) {
        Logger.shared.logDebug("Text field \(elementId) changed focus to \(becomingActive).")
        guard becomingActive else {
            dismissPasswordManagerMenu()
            currentlyFocusedElementId = nil
            return
        }
        guard elementId != currentlyFocusedElementId else {
            return
        }
        currentlyFocusedElementId = elementId
        guard let inputField = inputFields[elementId] else {
            return
        }
        requestWebFieldFrame(elementId: elementId) { frame in
            if let frame = frame {
                DispatchQueue.main.async {
                    self.showPasswordManagerMenu(at: frame, withPasswordGenerator: inputField.type == .newPassword || inputField.type == .password) // TODO: when detection is more reliable, only newPassword fields will trigger password generator.
                }
            }
        }
    }

    private func showPasswordManagerMenu(at location: CGRect, withPasswordGenerator passwordGenerator: Bool) {
        guard let host = page.url else { return }
        if passwordMenuWindow != nil {
            dismissPasswordManagerMenu()
        }
        let viewModel = PasswordManagerMenuViewModel(host: host, passwordStore: passwordStore, withPasswordGenerator: passwordGenerator)
        viewModel.delegate = self
        let rootView = PasswordManagerMenu(width: location.size.width, viewModel: viewModel)
        let window = FirstResponderWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        window.contentViewController = NSHostingController(rootView: rootView)
        page.window?.addChildWindow(window, ordered: .above)
        passwordMenuPosition = bottomLeftOnScreen(for: location)
        window.setFrameTopLeftPoint(passwordMenuPosition)
        window.makeKeyAndOrderFront(nil)
        passwordMenuWindow = window
    }

    private func dismissPasswordManagerMenu() {
        guard let window = passwordMenuWindow else { return }
        page.window?.removeChildWindow(window)
        window.setIsVisible(false)
        passwordMenuWindow = nil
    }

    func updateOverlay(moving movedFields: [String: AutofillInputField]) {
//        movedFields.values.forEach { field in
//            overlay?.moveButton(inputField: field)
//        }
    }

    func updateScrollPosition(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        let offset = CGPoint(x: x - webViewScrollPosition.x, y: y - webViewScrollPosition.y)
        webViewScrollPosition.x = x
        webViewScrollPosition.y = y
        guard let menuWindow = passwordMenuWindow else { return }
        DispatchQueue.main.async {
            self.passwordMenuPosition.x += offset.x
            self.passwordMenuPosition.y += offset.y
            menuWindow.setFrameTopLeftPoint(self.passwordMenuPosition)
            Logger.shared.logDebug("scrolled to \(x) \(y) \(width) \(height)")
        }
    }

    func updateViewSize(width: CGFloat, height: CGFloat) {
        guard let elementId = currentlyFocusedElementId, let menuWindow = passwordMenuWindow else {
            return
        }
        requestWebFieldFrame(elementId: elementId) { frame in
            if let frame = frame {
                DispatchQueue.main.async {
                    self.passwordMenuPosition = self.bottomLeftOnScreen(for: frame)
                    menuWindow.setFrameTopLeftPoint(self.passwordMenuPosition)
                    // TODO: update width
                }
            }
        }
    }

    private func requestWebFieldFrame(elementId: String, completion: @escaping (CGRect?) -> Void) {
        let script = "beam_getElementRects('[\"\(elementId)\"]');"
        page.executeJS(script, objectName: nil).then { jsResult in
            if let jsonString = jsResult as? String, let jsonData = jsonString.data(using: .utf8), let rects = try? self.decoder.decode([DOMRect?].self, from: jsonData), let rect = rects.first??.rect {
                let frame = CGRect(x: rect.minX, y: rect.minY + rect.height, width: rect.width, height: 0)
                completion(frame)
            } else {
                completion(nil)
            }
        }
    }

    private func bottomLeftOnScreen(for windowRect: CGRect) -> CGPoint {
        guard let window = page.window else {
            fatalError()
        }
        let windowHeight = window.contentRect(forFrameRect: page.frame).size.height
        let localPoint = CGPoint(x: windowRect.origin.x, y: windowHeight - windowRect.origin.y)
        return window.convertPoint(toScreen: localPoint)
    }

    func handleWebFormSubmit() {
        let ids = inputFields.keys
        let formattedList = ids.map { "\"\($0)\"" }.joined(separator: ",")
        let script = "beam_getTextFieldValues('[\(formattedList)]');"
        page.executeJS(script, objectName: nil).then { jsResult in
            if let jsonString = jsResult as? String, let jsonData = jsonString.data(using: .utf8), let values = try? self.decoder.decode([String].self, from: jsonData) {
                let dict = Dictionary(uniqueKeysWithValues: zip(ids, values))
                self.updateStoredValues(dict)
            } else {
                Logger.shared.logWarning("Unable to decode text field values from \(String(describing: jsResult))", category: .general)
            }
        }
    }

    private func updateStoredValues(_ values: [String: String]) {
        guard let host = page.url else { return }
        guard let login = values.valuesMatchingKeys(in: Array(loginFields.keys)).first, let password = values.valuesMatchingKeys(in: Array(passwordFields.keys)).first else {
            Logger.shared.logDebug("No field match for submitted values in \(values)")
            return
        }
        Logger.shared.logDebug("FOUND login: \(login), password: \(password)")
        passwordStore.password(host: host, username: login) { storedPassword in
            if let storedPassword = storedPassword {
                if password != storedPassword {
                    // TODO: display password update panel
                    self.passwordStore.save(host: host, username: login, password: password)
                }
            } else {
                // TODO: display password save panel
                self.passwordStore.save(host: host, username: login, password: password)
            }
        }
    }
}

extension PasswordOverlayController: PasswordManagerMenuDelegate {
    func fillCredentials(_ entry: PasswordManagerEntry) {
        passwordStore.password(host: entry.host, username: entry.username) { password in
            guard let password = password else {
                Logger.shared.logError("PasswordStore did not provide password for selected entry.", category: .general)
                return
            }
            let loginParams = self.loginFields.keys.map { id in
                WebFieldAutofill(id: id, value: entry.username, background: nil)
            }
            let passwordParams = self.passwordFields.keys.map { id in
                WebFieldAutofill(id: id, value: password, background: nil)
            }
            self.fillWebTextFields(loginParams + passwordParams)
        }
        DispatchQueue.main.async {
            self.dismissPasswordManagerMenu()
        }
    }

    func fillNewPassword(_ password: String) {
        let passwordParams = passwordFields.keys.map { id in
            WebFieldAutofill(id: id, value: password, background: nil)
        }
        fillWebTextFields(passwordParams)
        DispatchQueue.main.async {
            self.dismissPasswordManagerMenu()
        }
    }

    private func fillWebTextFields(_ params: [WebFieldAutofill]) {
        do {
            let data = try encoder.encode(params)
            guard let jsonString = String(data: data, encoding: .utf8) else { return }
            let script = "beam_setTextFieldValues('\(jsonString)')"
            page.executeJS(script, objectName: nil).then { _ in
                Logger.shared.logDebug("passwordOverlay text fields set.")
            }
        } catch {
            Logger.shared.logError("JSON encoding failure: \(error.localizedDescription))", category: .general)
        }
    }
}

private class FirstResponderWindow: NSWindow {
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
