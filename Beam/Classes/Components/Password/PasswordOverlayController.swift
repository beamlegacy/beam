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
    private let userInfoStore: UserInformationsStore
    private var passwordMenuWindow: NSWindow?
    private var passwordMenuPosition: CGPoint = .zero
    private var webViewScrollPosition: CGPoint = .zero
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var autocompleteContext: WebAutocompleteContext
    private var currentlyFocusedElementId: String?

    init(passwordStore: PasswordStore, userInfoStore: UserInformationsStore) {
        self.passwordStore = passwordStore
        self.userInfoStore = userInfoStore
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        autocompleteContext = WebAutocompleteContext(passwordStore: passwordStore)
    }

    func detectInputFields() {
        autocompleteContext.clear()
        dismissPasswordManagerMenu()
        page.executeJS("password_sendTextFields()", objectName: nil)
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
            Logger.shared.logDebug("🔑 decoded: \(elements)")
        } catch {
            Logger.shared.logError(String(describing: error), category: .javascript)
            return
        }

        let addedIds = autocompleteContext.update(with: elements) // + webPage
        if !addedIds.isEmpty {
            page.executeJS("beam_installSubmitHandler()", objectName: nil).then { _ in
                self.installFocusHandlers(addedIds: addedIds)
            }
        }
    }

    private func installFocusHandlers(addedIds: [String]) {
        let formattedList = addedIds.map { "\"\($0)\"" }.joined(separator: ",")
        let focusScript = "beam_installFocusHandlers('[\(formattedList)]')"
        page.executeJS(focusScript, objectName: nil)
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
        guard let autocompleteGroup = autocompleteContext.autocompleteGroup(for: elementId) else {
            dismissPasswordManagerMenu()
            currentlyFocusedElementId = nil
            return
        }
        currentlyFocusedElementId = elementId
        requestWebFieldFrame(elementId: elementId) { frame in
            if let frame = frame {
                DispatchQueue.main.async {
                    switch autocompleteGroup.action {
                    case .createAccount:
                        self.showPasswordManagerMenu(at: frame, withPasswordGenerator: true)
                    case .login:
                        self.showPasswordManagerMenu(at: frame, withPasswordGenerator: false)
                    default:
                        break
                    }
                }
            }
        }
    }

    private func showPasswordManagerMenu(at location: CGRect, withPasswordGenerator passwordGenerator: Bool) {
        guard let host = page.url else { return }
        if passwordMenuWindow != nil {
            dismissPasswordManagerMenu()
        }
        let viewModel = PasswordManagerMenuViewModel(host: host, passwordStore: passwordStore, userInfoStore: userInfoStore, withPasswordGenerator: passwordGenerator)
        viewModel.delegate = self
        let passwordManagerMenu = PasswordManagerMenu(width: location.size.width, viewModel: viewModel)
        guard let webView = (page as? BrowserTab)?.webView,
              let passwordWindow = ContextMenuPresenter.shared.present(view: BeamHostingView(rootView: passwordManagerMenu), from: webView, atPoint: location.origin) else { return }
//        passwordMenuPosition = bottomLeftOnScreen(for: location) // Not needed atm
        passwordWindow.makeKeyAndOrderFront(nil)
        passwordMenuWindow = passwordWindow
    }

    private func dismissPasswordManagerMenu() {
        ContextMenuPresenter.shared.dismissMenu()
        passwordMenuWindow = nil
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
        let script = "beam_getElementRects('[\"\(elementId)\"]')"
        page.executeJS(script, objectName: nil).then { jsResult in
            if let jsonString = jsResult as? String, let jsonData = jsonString.data(using: .utf8), let rects = try? self.decoder.decode([DOMRect?].self, from: jsonData), let rect = rects.first??.rect {
                let frame = CGRect(x: rect.minX, y: rect.minY + rect.height, width: rect.width, height: rect.height)
                completion(frame)
            } else {
                completion(nil)
            }
        }
    }

    private func bottomLeftOnScreen(for windowRect: CGRect) -> CGPoint {
        guard let window = page.webviewWindow else {
            fatalError()
        }
        let windowHeight = window.contentRect(forFrameRect: page.frame).size.height
        let localPoint = CGPoint(x: windowRect.origin.x, y: windowHeight - windowRect.origin.y)
        return window.convertPoint(toScreen: localPoint)
    }

    func handleWebFormSubmit() {
        let fields = autocompleteContext.allInputFields
        let ids = fields.map(\.id)
        let formattedList = ids.map { "\"\($0)\"" }.joined(separator: ",")
        let script = "beam_getTextFieldValues('[\(formattedList)]')"
        page.executeJS(script, objectName: nil).then { jsResult in
            if let jsonString = jsResult as? String,
               let jsonData = jsonString.data(using: .utf8),
               let values = try? self.decoder.decode([String].self, from: jsonData) {
                let dict = Dictionary(uniqueKeysWithValues: zip(ids, values))
                self.updateStoredValues(dict)
            } else {
                Logger.shared.logWarning("Unable to decode text field values from \(String(describing: jsResult))", category: .general)
            }
        }
    }

    fileprivate func getPageHost() -> String? {
        guard let host = page.url?.minimizedHost else {
            if let url = page.url?.absoluteString,
               url.starts(with: "file:///"),
                let localfile = url.split(separator: "/").last,
                let localfileWithoutQueryparams = localfile.split(separator: "?").first {
                return String(localfileWithoutQueryparams)
            }
            return nil
        }
        return host
    }

    private func updateStoredValues(_ values: [String: String]) {
        guard let host = getPageHost() else { return }
        guard let (loginFieldIds, passwordFieldIds) = passwordFieldIdsForStorage() else {
            Logger.shared.logDebug("Login/password fields not found")
            return
        }
        guard let login = values.valuesMatchingKeys(in: loginFieldIds).first, let password = values.valuesMatchingKeys(in: passwordFieldIds).first else {
            Logger.shared.logDebug("No field match for submitted values in \(values)")
            return
        }
        Logger.shared.logDebug("FOUND login: \(login), password: \(password)")
        passwordStore.password(host: host, username: login) { storedPassword in
            if let storedPassword = storedPassword {
                if password != storedPassword && password.count > 2 && login.count > 2 {
                    if let browserTab = (self.page as? BrowserTab) {
                        browserTab.passwordManagerToast(saved: false)
                    }
                    self.passwordStore.save(host: host, username: login, password: password)
                }
            } else {
                if password.count > 2 && login.count > 2 {
                    if let browserTab = (self.page as? BrowserTab) {
                        browserTab.passwordManagerToast(saved: true)
                    }
                    self.passwordStore.save(host: host, username: login, password: password)
                }
            }
        }
    }

    private func passwordFieldIdsForStorage() -> (usernameIds: [String], passwordIds: [String])? {
        let inputFields = autocompleteContext.allInputFields
        let newPasswordIds = inputFields.filter { $0.role == .newPassword }.map(\.id)
        let currentPasswordIds = inputFields.filter { $0.role == .currentPassword }.map(\.id)
        let passwordIds = newPasswordIds + currentPasswordIds
        guard !passwordIds.isEmpty else {
            return nil
        }
        var usernameIds: [String]
        if !newPasswordIds.isEmpty {
            usernameIds = inputFields.filter { $0.role == .newUsername }.map(\.id)
        } else {
            usernameIds = []
        }
        usernameIds += inputFields.filter { $0.role == .currentUsername }.map(\.id)
        usernameIds += inputFields.filter { $0.role == .email }.map(\.id)
        guard !usernameIds.isEmpty else {
            return nil
        }
        return (usernameIds: usernameIds, passwordIds: passwordIds)
    }
}

extension PasswordOverlayController: PasswordManagerMenuDelegate {
    func deleteCredentials(_ entry: PasswordManagerEntry) {
        passwordStore.delete(host: entry.minimizedHost, username: entry.username)
    }

    func fillCredentials(_ entry: PasswordManagerEntry) {
        guard let elementId = currentlyFocusedElementId, let autocompleteGroup = autocompleteContext.autocompleteGroup(for: elementId), autocompleteGroup.action == .login else {
            Logger.shared.logError("AutocompleteContext mismatch for id \(String(describing: currentlyFocusedElementId))", category: .general)
            dismissPasswordManagerMenu()
            return
        }
        passwordStore.password(host: entry.minimizedHost, username: entry.username) { password in
            guard let password = password else {
                Logger.shared.logError("PasswordStore did not provide password for selected entry.", category: .general)
                return
            }
            let autofill = autocompleteGroup.relatedFields.compactMap { field -> WebFieldAutofill? in
                switch field.role {
                case .currentUsername:
                    return WebFieldAutofill(id: field.id, value: entry.username, background: nil)
                case .currentPassword:
                    return WebFieldAutofill(id: field.id, value: password, background: nil)
                default:
                    return nil
                }
            }
            self.fillWebTextFields(autofill)
        }
        DispatchQueue.main.async {
            self.dismissPasswordManagerMenu()
        }
    }

    func fillNewPassword(_ password: String, dismiss: Bool = true) {
        guard let elementId = currentlyFocusedElementId, let autocompleteGroup = autocompleteContext.autocompleteGroup(for: elementId), autocompleteGroup.action == .createAccount else {
            Logger.shared.logError("AutocompleteContext mismatch for id \(String(describing: currentlyFocusedElementId))", category: .general)
            dismissPasswordManagerMenu()
            return
        }
        let autofill = autocompleteGroup.relatedFields.compactMap { field -> WebFieldAutofill? in
            if field.role == .newPassword {
                return WebFieldAutofill(id: field.id, value: password, background: nil)
            } else {
                return nil
            }
        }
        self.fillWebTextFields(autofill)
        self.togglePasswordField(visibility: true)
        if dismiss {
            DispatchQueue.main.async {
                self.dismissPasswordManagerMenu()
            }
        }
    }

    func emptyPasswordField() {
        let emptyParams = passwordFieldIds.map { id in
            WebFieldAutofill(id: id, value: "", background: nil)
        }
        self.togglePasswordField(visibility: false)
        self.fillWebTextFields(emptyParams)
        DispatchQueue.main.async {
            self.dismissPasswordManagerMenu()
        }
    }

    func dismiss() {
        DispatchQueue.main.async {
            self.dismissPasswordManagerMenu()
        }
    }

    private var passwordFieldIds: [String] {
        guard let elementId = currentlyFocusedElementId, let autocompleteGroup = autocompleteContext.autocompleteGroup(for: elementId) else {
            return []
        }
        return autocompleteGroup.relatedFields
            .filter { $0.role == .currentPassword || $0.role == .newPassword }
            .map(\.id)
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

    private func togglePasswordField(visibility: Bool) {
        let passwordParams = passwordFieldIds.map { id in
            WebFieldAutofill(id: id, value: nil, background: nil)
        }
        do {
            let data = try encoder.encode(passwordParams)
            guard let jsonString = String(data: data, encoding: .utf8) else { return }
            let script = "beam_togglePasswordFieldVisibility('\(jsonString)', '\(visibility.description)')"
            page.executeJS(script, objectName: nil)
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
