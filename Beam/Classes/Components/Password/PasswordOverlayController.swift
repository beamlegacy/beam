//
//  PasswordOverlayController.swift
//  Beam
//
//  Created by Frank Lefebvre on 23/03/2021.
//
// swiftlint:disable file_length

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
    private let passwordManager: PasswordManager = PasswordManager()
    private let userInfoStore: UserInformationsStore
    private var passwordMenuWindow: NSWindow?
    private var passwordMenuPosition: CGPoint = .zero
    private var webViewScrollPosition: CGPoint = .zero
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var autocompleteContext: WebAutocompleteContext
    private var currentlyFocusedElementId: String?
    private var previouslyFocusedElementId: String?
    private var lastFocusOutTimestamp: Date = .distantPast
    private var disabledForSubmit = false
    private var valuesOnFocusOut: [String: String]?
    private var currentPasswordManagerViewModel: PasswordManagerMenuViewModel?

    init(userInfoStore: UserInformationsStore) {
        self.userInfoStore = userInfoStore
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        autocompleteContext = WebAutocompleteContext()
    }

    func detectInputFields() {
        autocompleteContext.clear()
        dismissPasswordManagerMenu()
        page.executeJS("beam_sendTextFields()", objectName: nil)
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
            Logger.shared.logDebug("Detected fields: \(elements)", category: .passwordManager)
        } catch {
            Logger.shared.logError(String(describing: error), category: .passwordManager)
            return
        }

        let addedIds = autocompleteContext.update(with: elements, on: getPageHost())
        if !addedIds.isEmpty {
            page.executeJS("beam_installSubmitHandler()", objectName: nil).then { _ in
                self.installFocusHandlers(addedIds: addedIds)
            }
        }
        disabledForSubmit = false
    }

    private func installFocusHandlers(addedIds: [String]) {
        let formattedList = addedIds.map { "\"\($0)\"" }.joined(separator: ",")
        let focusScript = "beam_installFocusHandlers('[\(formattedList)]')"
        page.executeJS(focusScript, objectName: nil)
    }

    func inputFieldDidGainFocus(_ elementId: String) {
        Logger.shared.logDebug("Text field \(elementId) gained focus.", category: .passwordManager)
        guard elementId != currentlyFocusedElementId else {
            return
        }
        guard elementId != previouslyFocusedElementId || lastFocusOutTimestamp.timeIntervalSinceNow < -0.1 else {
            Logger.shared.logDebug("Focus in detected within 100ms after focus out on the same field, ignoring", category: .passwordManager)
            return
        }
        guard let autocompleteGroup = autocompleteContext.autocompleteGroup(for: elementId) else {
            dismissPasswordManagerMenu()
            currentlyFocusedElementId = nil
            return
        }
        guard !disabledForSubmit else {
            disabledForSubmit = false
            return
        }
        currentlyFocusedElementId = elementId
        if autocompleteGroup.isAmbiguous, let host = page.url?.minimizedHost {
            let entries = passwordManager.entries(for: host, exact: false)
            let createAccount = entries.isEmpty
            self.showPasswordManagerMenu(for: elementId, withPasswordGenerator: createAccount)
        } else {
            switch autocompleteGroup.action {
            case .createAccount:
                self.showPasswordManagerMenu(for: elementId, withPasswordGenerator: true)
            case .login:
                self.showPasswordManagerMenu(for: elementId, withPasswordGenerator: false)
            default:
                break
            }
        }
    }

    func inputFieldDidLoseFocus(_ elementId: String) {
        Logger.shared.logDebug("Text field \(elementId) lost focus.", category: .passwordManager)
        requestValuesFromTextFields { dict in
            self.valuesOnFocusOut = dict
        }
        dismissPasswordManagerMenu()
        lastFocusOutTimestamp = BeamDate.now
        previouslyFocusedElementId = elementId
        currentlyFocusedElementId = nil
    }

    private func showPasswordManagerMenu(for elementId: String, withPasswordGenerator passwordGenerator: Bool) {
        requestWebFieldFrame(elementId: elementId) { frame in
            if let frame = frame {
                DispatchQueue.main.async {
                    guard self.currentlyFocusedElementId == elementId else {
                        return
                    }
                    self.showPasswordManagerMenu(at: frame, withPasswordGenerator: passwordGenerator)
                }
            } else {
                Logger.shared.logError("Could not get frame for element \(elementId)", category: .passwordManager)
            }
        }
    }

    private func showPasswordManagerMenu(at location: CGRect, withPasswordGenerator passwordGenerator: Bool) {
        guard let host = page.url else { return }
        if passwordMenuWindow != nil {
            dismissPasswordManagerMenu()
        }
        let viewModel = passwordManagerViewModel(for: host, withPasswordGenerator: passwordGenerator)
        let passwordManagerMenu = PasswordManagerMenu(width: location.size.width, viewModel: viewModel)
        guard let webView = (page as? BrowserTab)?.webView,
              let passwordWindow = CustomPopoverPresenter.shared.present(view: BeamHostingView(rootView: passwordManagerMenu), from: webView, atPoint: location.origin) else { return }
        passwordWindow.makeKeyAndOrderFront(nil)
        passwordMenuWindow = passwordWindow
    }

    private func passwordManagerViewModel(for host: URL, withPasswordGenerator passwordGenerator: Bool) -> PasswordManagerMenuViewModel {
        if let viewModel = currentPasswordManagerViewModel {
            let viewModelHasPasswordGenerator = viewModel.passwordGeneratorViewModel != nil
            if viewModel.host != host || viewModelHasPasswordGenerator != passwordGenerator {
                currentPasswordManagerViewModel = nil
            }
        }
        if let viewModel = currentPasswordManagerViewModel {
            return viewModel
        }
        let viewModel = PasswordManagerMenuViewModel(host: host, userInfoStore: userInfoStore, withPasswordGenerator: passwordGenerator)
        viewModel.delegate = self
        currentPasswordManagerViewModel = viewModel
        return viewModel
    }

    private func dismissPasswordManagerMenu() {
        CustomPopoverPresenter.shared.dismissMenu()
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
            Logger.shared.logDebug("scrolled to \(x) \(y) \(width) \(height)", category: .passwordManager)
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

    func handleWebFormSubmit(with elementId: String) {
        Logger.shared.logDebug("Submit: \(elementId)", category: .passwordManager)
        disabledForSubmit = true // disable focus handler temporarily, to prevent the password manager menu from reappearing if the JS code triggers a selection in a text field
        requestValuesFromTextFields { dict in
            if let values = dict ?? self.valuesOnFocusOut {
                self.updateStoredValues(with: values)
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

    private func requestValuesFromTextFields(completion: @escaping (([String: String]?) -> Void)) {
        let ids = autocompleteContext.allInputFieldIds
        let formattedList = ids.map { "\"\($0)\"" }.joined(separator: ",")
        let script = "beam_getTextFieldValues('[\(formattedList)]')"
        page.executeJS(script, objectName: nil).then { jsResult in
            if let jsonString = jsResult as? String,
               let jsonData = jsonString.data(using: .utf8),
               let values = try? self.decoder.decode([String].self, from: jsonData) {
                let dict = Dictionary(uniqueKeysWithValues: zip(ids, values))
                completion(dict)
            } else {
                Logger.shared.logWarning("Unable to decode text field values from \(String(describing: jsResult))", category: .passwordManager)
                completion(nil)
            }
        }
    }

    private func updateStoredValues(with values: [String: String]) {
        guard let host = getPageHost() else { return }
        guard let (loginFieldIds, passwordFieldIds) = passwordFieldIdsForStorage() else {
            Logger.shared.logDebug("Login/password fields not found", category: .passwordManager)
            return
        }
        let firstNonEmptyLogin = values.valuesMatchingKeys(in: loginFieldIds).first { !$0.isEmpty }
        let firstNonEmptyPassword = values.valuesMatchingKeys(in: passwordFieldIds).first { !$0.isEmpty }
        guard let login = firstNonEmptyLogin, let password = firstNonEmptyPassword else {
            Logger.shared.logDebug("No field match for submitted values in \(values)", category: .passwordManager)
            return
        }
        Logger.shared.logDebug("FOUND login: \(login), password: \(password)", category: .passwordManager)
        if let storedPassword = passwordManager.password(host: host, username: login) {
            if password != storedPassword && password.count > 2 && login.count > 2 {
                if let browserTab = (self.page as? BrowserTab) {
                    browserTab.passwordManagerToast(saved: false)
                }
                self.passwordManager.save(host: host, username: login, password: password)
            }
        } else {
            if password.count > 2 && login.count > 2 {
                if let browserTab = (self.page as? BrowserTab) {
                    browserTab.passwordManagerToast(saved: true)
                }
                self.passwordManager.save(host: host, username: login, password: password)
            }
        }
    }

    private func passwordFieldIdsForStorage() -> (usernameIds: [String], passwordIds: [String])? {
        let inputFields = autocompleteContext.allInputFields
        let newPasswordIds = inputFields.filter { $0.role == .newPassword }.map(\.id)
        let currentPasswordIds = inputFields.filter { $0.role == .currentPassword }.map(\.id)
        let passwordIds = newPasswordIds + currentPasswordIds
        guard !passwordIds.isEmpty else {
            Logger.shared.logWarning("Storage: password fields not found", category: .passwordManager)
            dumpInputFields(inputFields)
            return nil
        }
        var usernameIds: [String]
        if !newPasswordIds.isEmpty {
            Logger.shared.logDebug("Storage: new password field(s) found", category: .passwordManager)
            usernameIds = inputFields.filter { $0.role == .newUsername }.map(\.id)
        } else {
            Logger.shared.logDebug("Storage: current password field(s) found", category: .passwordManager)
            usernameIds = []
        }
        usernameIds += inputFields.filter { $0.role == .currentUsername }.map(\.id)
        usernameIds += inputFields.filter { $0.role == .email }.map(\.id)
        guard !usernameIds.isEmpty else {
            Logger.shared.logWarning("Storage: login fields not found", category: .passwordManager)
            dumpInputFields(inputFields)
            return nil
        }
        return (usernameIds: usernameIds, passwordIds: passwordIds)
    }

    private func dumpInputFields(_ inputFields: [WebInputField]) {
        for field in inputFields {
            Logger.shared.logDebug(" - field id \(field.id), role: \(field.role)")
        }
    }
}

extension PasswordOverlayController: PasswordManagerMenuDelegate {
    func deleteCredentials(_ entries: [PasswordManagerEntry]) {
        for entry in entries {
            passwordManager.delete(host: entry.minimizedHost, for: entry.username)
        }
    }

    func fillCredentials(_ entry: PasswordManagerEntry) {
        guard let elementId = currentlyFocusedElementId, let autocompleteGroup = autocompleteContext.autocompleteGroup(for: elementId), autocompleteGroup.action == .login || autocompleteGroup.isAmbiguous else {
            Logger.shared.logError("AutocompleteContext (login) mismatch for id \(String(describing: currentlyFocusedElementId))", category: .passwordManager)
            dismissPasswordManagerMenu()
            return
        }
        guard let password = passwordManager.password(host: entry.minimizedHost, username: entry.username) else {
            Logger.shared.logError("PasswordStore did not provide password for selected entry.", category: .passwordManager)
            return
        }
        Logger.shared.logDebug(String(describing: autocompleteGroup.relatedFields), category: .passwordManager)
        let backgroundColor = BeamColor.Autocomplete.clickedBackground.hexColor
        let autofill = autocompleteGroup.relatedFields.compactMap { field -> WebFieldAutofill? in
            switch field.role {
            case .currentUsername:
                return WebFieldAutofill(id: field.id, value: entry.username, background: backgroundColor)
            case .newUsername:
                return autocompleteGroup.isAmbiguous ? WebFieldAutofill(id: field.id, value: entry.username, background: backgroundColor) : nil
            case .currentPassword:
                return WebFieldAutofill(id: field.id, value: password, background: backgroundColor)
            case .newPassword:
                return autocompleteGroup.isAmbiguous ? WebFieldAutofill(id: field.id, value: password, background: backgroundColor) : nil
            default:
                return nil
            }
        }
        self.fillWebTextFields(autofill)
        DispatchQueue.main.async {
            self.dismissPasswordManagerMenu()
        }
    }

    func fillNewPassword(_ password: String, dismiss: Bool = true) {
        guard let elementId = currentlyFocusedElementId, let autocompleteGroup = autocompleteContext.autocompleteGroup(for: elementId), autocompleteGroup.action == .createAccount || autocompleteGroup.isAmbiguous else {
            Logger.shared.logError("AutocompleteContext (createAccount) mismatch for id \(String(describing: currentlyFocusedElementId))", category: .passwordManager)
            dismissPasswordManagerMenu()
            return
        }
        let backgroundColor = BeamColor.Autocomplete.clickedBackground.hexColor
        let autofill = autocompleteGroup.relatedFields.compactMap { field -> WebFieldAutofill? in
            switch field.role {
            case .newPassword:
                return WebFieldAutofill(id: field.id, value: password, background: backgroundColor)
            case .currentPassword:
                return autocompleteGroup.isAmbiguous ? WebFieldAutofill(id: field.id, value: password, background: backgroundColor) : nil
            default:
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
                Logger.shared.logDebug("passwordOverlay text fields set.", category: .passwordManager)
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
