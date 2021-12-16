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

enum PasswordSaveAction {
    case save
    case update
}

class PasswordOverlayController: WebPageHolder {
    private let userInfoStore: UserInformationsStore
    private let credentialsBuilder: PasswordManagerCredentialsBuilder
    private var passwordMenuWindow: PopoverWindow?
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
    private let JSObjectName = "PMng"

    init(userInfoStore: UserInformationsStore) {
        self.userInfoStore = userInfoStore
        credentialsBuilder = PasswordManagerCredentialsBuilder()
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        autocompleteContext = WebAutocompleteContext()
    }

    func detectInputFields() {
        credentialsBuilder.enterPage(url: page.url)
        autocompleteContext.clear()
        dismissPasswordManagerMenu()
        page.executeJS("beam_sendTextFields()", objectName: JSObjectName)
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
            Logger.shared.logDebug("Detected fields: \(elements.map { $0.debugDescription })", category: .passwordManager)
        } catch {
            Logger.shared.logError(String(describing: error), category: .passwordManager)
            return
        }

        let addedIds = autocompleteContext.update(with: elements, on: getPageHost())
        if !addedIds.isEmpty {
            page.executeJS("beam_installSubmitHandler()", objectName: JSObjectName).then { _ in
                self.installFocusHandlers(addedIds: addedIds)
            }
            page.executeJS("beam_getFocusedField()", objectName: JSObjectName).then { result in
                if let focusedId = result as? String {
                    DispatchQueue.main.async {
                        self.inputFieldDidGainFocus(focusedId)
                    }
                }
            }
        }
        disabledForSubmit = false
    }

    private func installFocusHandlers(addedIds: [String]) {
        let formattedList = addedIds.map { "\"\($0)\"" }.joined(separator: ",")
        let focusScript = "beam_installFocusHandlers('[\(formattedList)]')"
        page.executeJS(focusScript, objectName: JSObjectName)
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
        if autocompleteGroup.isAmbiguous, let fieldWithFocus = autocompleteGroup.field(id: elementId) {
            self.showPasswordManagerMenu(for: elementId, options: fieldWithFocus.role.isPassword ? .ambiguousPassword : .login)
        } else {
            switch autocompleteGroup.action {
            case .createAccount:
                self.showPasswordManagerMenu(for: elementId, options: .createAccount)
            case .login:
                self.showPasswordManagerMenu(for: elementId, options: .login)
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

    private func showPasswordManagerMenu(for elementId: String, options: PasswordManagerMenuOptions) {
        requestWebFieldFrame(elementId: elementId) { frame in
            if let frame = frame {
                DispatchQueue.main.async {
                    guard self.currentlyFocusedElementId == elementId else {
                        return
                    }
                    self.showPasswordManagerMenu(at: frame, options: options)
                }
            } else {
                Logger.shared.logError("Could not get frame for element \(elementId)", category: .passwordManager)
            }
        }
    }

    private func showPasswordManagerMenu(at location: CGRect, options: PasswordManagerMenuOptions) {
        guard let host = page.url else { return }
        if passwordMenuWindow != nil {
            dismissPasswordManagerMenu()
        }
        let viewModel = passwordManagerViewModel(for: host, options: options)
        let passwordManagerMenu = PasswordManagerMenu(width: location.size.width, viewModel: viewModel)
        guard let webView = (page as? BrowserTab)?.webView,
              let passwordWindow = CustomPopoverPresenter.shared.presentPopoverChildWindow(canBecomeKey: false, canBecomeMain: false, withShadow: true, storedInPresenter: true)
        else { return }
        var updatedRect = convertRect(location, relativeTo: webView)
        updatedRect.origin.y += location.height
        passwordWindow.setView(with: passwordManagerMenu, at: updatedRect.origin, fromTopLeft: true)
        passwordMenuWindow = passwordWindow
    }

    private func passwordManagerViewModel(for host: URL, options: PasswordManagerMenuOptions) -> PasswordManagerMenuViewModel {
        if let viewModel = currentPasswordManagerViewModel {
            if viewModel.host != host || viewModel.options != options {
                currentPasswordManagerViewModel = nil
            }
        }
        if let viewModel = currentPasswordManagerViewModel {
            return viewModel
        }
        let viewModel = PasswordManagerMenuViewModel(host: host, credentialsBuilder: credentialsBuilder, userInfoStore: userInfoStore, options: options)
        viewModel.delegate = self
        currentPasswordManagerViewModel = viewModel
        return viewModel
    }

    private func dismissPasswordManagerMenu() {
        CustomPopoverPresenter.shared.dismissPopovers()
        passwordMenuWindow = nil
        currentPasswordManagerViewModel = nil
    }

    private func convertRect(_ rect: CGRect, relativeTo webView: WKWebView) -> CGRect {
        var rect = webView.convert(rect, to: nil)
        rect.origin.y -= webView.topContentInset
        return rect
    }

    func updateScrollPosition(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        webViewScrollPosition.x = x
        webViewScrollPosition.y = y
        DispatchQueue.main.async {
            if self.passwordMenuWindow != nil {
                self.dismissPasswordManagerMenu()
            }
            Logger.shared.logDebug("scrolled to \(x) \(y) \(width) \(height)", category: .passwordManager)
        }
    }

    func updateViewSize(width: CGFloat, height: CGFloat) {
        guard let elementId = currentlyFocusedElementId, let menuWindow = passwordMenuWindow else {
            return
        }
        requestWebFieldFrame(elementId: elementId) { frame in
            if let frame = frame {
                DispatchQueue.main.async { [unowned self] in
                    var position = self.page.webView.convert(frame.origin, to: nil)
                    position.y -= menuWindow.frame.size.height + self.page.webView.topContentInset
                    self.passwordMenuPosition = position
                    menuWindow.setOrigin(self.passwordMenuPosition)
                    // TODO: update width
                }
            }
        }
    }

    private func requestWebFieldFrame(elementId: String, completion: @escaping (CGRect?) -> Void) {
        let script = "beam_getElementRects('[\"\(elementId)\"]')"
        page.executeJS(script, objectName: JSObjectName).then { jsResult in
            if let jsonString = jsResult as? String, let jsonData = jsonString.data(using: .utf8), let rects = try? self.decoder.decode([DOMRect?].self, from: jsonData), let rect = rects.first??.rect {
                let frame = CGRect(x: rect.minX, y: rect.minY + rect.height, width: rect.width, height: rect.height)
                completion(frame)
            } else {
                completion(nil)
            }
        }
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
        page.executeJS(script, objectName: JSObjectName).then { jsResult in
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
        guard let hostname = getPageHost() else { return }
        guard let (loginFieldIds, passwordFieldIds) = passwordFieldIdsForStorage() else {
            Logger.shared.logDebug("Login/password fields not found", category: .passwordManager)
            return
        }
        let firstNonEmptyLogin = values.valuesMatchingKeys(in: loginFieldIds).first { !$0.isEmpty }
        let firstNonEmptyPassword = values.valuesMatchingKeys(in: passwordFieldIds).first { !$0.isEmpty }
        guard let login = credentialsBuilder.updatedUsername(firstNonEmptyLogin), let password = firstNonEmptyPassword else {
            Logger.shared.logDebug("No field match for submitted values in \(values)", category: .passwordManager)
            return
        }
        Logger.shared.logDebug("FOUND login: \(login), password: (redacted)", category: .passwordManager)
        if password.count > 2 && login.count > 2 {
            var saveAction: PasswordSaveAction?
            if let storedPassword = PasswordManager.shared.password(hostname: hostname, username: login) {
                if password != storedPassword {
                    saveAction = .update
                }
            } else {
                saveAction = .save
            }
            if let action = saveAction {
                confirmSavePassword(username: login, action: action) { save in
                    guard save else { return }
                    if let browserTab = (self.page as? BrowserTab) {
                        browserTab.passwordManagerToast(saved: action == .save)
                    }
                    PasswordManager.shared.save(hostname: hostname, username: login, password: password)
                }
            }
        }
    }

    private func confirmSavePassword(username: String, action: PasswordSaveAction, onDismiss: @escaping (Bool) -> Void) {
        guard let window = page.webviewWindow else {
            return onDismiss(true)
        }
        let alertMessage: String
        let saveButtonTitle: String
        let alert = NSAlert()
        switch action {
        case .save:
            alertMessage = "Would you like to save this password?"
            saveButtonTitle = "Save Password"
        case .update:
            alertMessage = "Would you like to update the saved password for \(username)?"
            saveButtonTitle = "Update Password"
        }
        alert.messageText = alertMessage
        alert.informativeText = "You can view and remove saved passwords in Beam Passwords preferences."
        let saveButton = alert.addButton(withTitle: saveButtonTitle)
        let cancelButton = alert.addButton(withTitle: "Not Now")
        saveButton.tag = NSApplication.ModalResponse.OK.rawValue
        cancelButton.tag = NSApplication.ModalResponse.cancel.rawValue
        alert.beginSheetModal(for: window) { response in
            onDismiss(response == .OK)
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
            PasswordManager.shared.delete(hostname: entry.minimizedHost, for: entry.username)
        }
    }

    func fillCredentials(_ entry: PasswordManagerEntry) {
        guard let elementId = currentlyFocusedElementId, let autocompleteGroup = autocompleteContext.autocompleteGroup(for: elementId), autocompleteGroup.action == .login || autocompleteGroup.isAmbiguous else {
            Logger.shared.logError("AutocompleteContext (login) mismatch for id \(String(describing: currentlyFocusedElementId))", category: .passwordManager)
            dismissPasswordManagerMenu()
            return
        }
        guard let password = PasswordManager.shared.password(hostname: entry.minimizedHost, username: entry.username) else {
            Logger.shared.logError("PasswordStore did not provide password for selected entry.", category: .passwordManager)
            return
        }
        currentPasswordManagerViewModel?.revertToFirstItem()
        credentialsBuilder.selectCredentials(entry)
        Logger.shared.logDebug("Filling fields: \(String(describing: autocompleteGroup.relatedFields))", category: .passwordManager)
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
            page.executeJS(script, objectName: JSObjectName).then { _ in
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
            page.executeJS(script, objectName: JSObjectName)
        } catch {
            Logger.shared.logError("JSON encoding failure: \(error.localizedDescription))", category: .general)
        }
    }
}
