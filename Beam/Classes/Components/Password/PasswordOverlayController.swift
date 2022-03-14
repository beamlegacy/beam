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
import Combine

struct WebFieldAutofill: Codable {
    var id: String
    var value: String?
    var background: String?
}

enum PasswordSaveAction {
    case save
    case update
    case saveSilently
}

class PasswordOverlayController: NSObject, WebPageRelated {
    private var scope = Set<AnyCancellable>()
    private let userInfoStore: UserInformationsStore
    private let credentialsBuilder: PasswordManagerCredentialsBuilder
    private let scrollUpdater = PassthroughSubject<WebPositions.FrameInfo, Never>()
    private var passwordMenuPopover: WebAutofillPopoverContainer?
    private let encoder: JSONEncoder
    private let decoder: BeamJSONDecoder
    private var fieldWithIcon: String?
    private var buttonPopover: WebAutofillPopoverContainer?
    private var currentlyFocusedElementId: String?
    private var previouslyFocusedElementId: String?
    private var lastFocusOutTimestamp: Date = .distantPast
    private var disabledForSubmit = false
    private var valuesOnFocusOut: [String: String]?
    private var currentPasswordManagerViewModel: PasswordManagerMenuViewModel?
    private var currentInputFrame: WKFrameInfo? // web frame containing the selected field when the menu is displayed (used in menu delegate)
    private var currentFrameIdentifier = 0
    private let JSObjectName = "PasswordManager"
    weak var page: WebPage?

    private lazy var fieldClassifiers: WebFieldClassifiers? = {
        guard let webFrames = self.page?.webFrames else { return nil }
        return WebFieldClassifiers(webFrames: webFrames)
    }()

    init(userInfoStore: UserInformationsStore) {
        self.userInfoStore = userInfoStore
        credentialsBuilder = PasswordManagerCredentialsBuilder()
        encoder = JSONEncoder()
        decoder = BeamJSONDecoder()
        super.init()
        PreferencesManager.$autofillUsernamePasswords.sink { [weak self] autofill in
            if !autofill {
                self?.dismiss()
            }
        }.store(in: &scope)
    }

    func prepareForLoading() {
        credentialsBuilder.enterPage(url: self.page?.url)
        fieldClassifiers?.clear()
        dismissPasswordManagerMenu()
        clearInputFocus()
        currentFrameIdentifier = 0
    }

    func webViewFinishedLoading() {
        Logger.shared.logDebug("Web view finished loading", category: .passwordManagerInternal)
    }

    private func nextFrameIdentifier() -> Int {
        currentFrameIdentifier += 1
        return currentFrameIdentifier
    }

    func requestInputFields(frameInfo: WKFrameInfo?) {
        self.page?.executeJS("sendTextFields('\(nextFrameIdentifier())')", objectName: JSObjectName, frameInfo: frameInfo, successLogCategory: .passwordManagerInternal)
    }

    func updateInputFields(with jsResult: String, frameInfo: WKFrameInfo?) {
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
            Logger.shared.logDebug("Detected fields: \(elements.map { $0.debugDescription })", category: .passwordManagerInternal)
        } catch {
            Logger.shared.logError(String(describing: error), category: .passwordManager)
            dismissPasswordManagerMenu()
            clearInputFocus()
            return
        }

        guard PreferencesManager.autofillUsernamePasswords else {
            return
        }

        if let elementId = currentlyFocusedElementId ?? previouslyFocusedElementId, !elements.map(\.beamId).contains(elementId) {
            Logger.shared.logDebug("Focused field just disappeared", category: .passwordManagerInternal)
            dismissPasswordManagerMenu()
            saveCredentialsIfChanged(allowEmptyUsername: false)
            clearInputFocus()
        }

        let addedIds = fieldClassifiers?.classify(fields: elements, host: getPageHost(), frameInfo: frameInfo) ?? []
        let values: [String: String] = elements.reduce(into: [:]) { dict, element in
            if let value = element.value {
                dict[element.beamId] = value
            }
        }
        if !values.isEmpty {
            self.updateStoredValues(with: values, userInput: false, frameInfo: frameInfo)
        }
        if !addedIds.isEmpty {
            self.page?.executeJS("installSubmitHandler()", objectName: JSObjectName, frameInfo: frameInfo, successLogCategory: .passwordManagerInternal).then { _ in
                self.installFocusHandlers(addedIds: addedIds, frameInfo: frameInfo)
            }
            self.page?.executeJS("passwordHelper.getFocusedField()", objectName: JSObjectName, frameInfo: frameInfo, successLogCategory: .passwordManagerInternal).then { result in
                if let focusedId = result as? String {
                    DispatchQueue.main.async {
                        self.inputFieldDidGainFocus(focusedId, frameInfo: frameInfo, contents: nil)
                    }
                }
            }
        }
        disabledForSubmit = false
    }

    private func installFocusHandlers(addedIds: [String], frameInfo: WKFrameInfo?) {
        let formattedList = addedIds.map { "\"\($0)\"" }.joined(separator: ",")
        let focusScript = "installFocusHandlers('[\(formattedList)]')"
        self.page?.executeJS(focusScript, objectName: JSObjectName, frameInfo: frameInfo, successLogCategory: .passwordManagerInternal)
    }

    func inputFieldDidGainFocus(_ elementId: String, frameInfo: WKFrameInfo?, contents: String?) {
        Logger.shared.logDebug("Text field \(elementId) gained focus.", category: .passwordManagerInternal)
        guard PreferencesManager.autofillUsernamePasswords else {
            return
        }
        guard elementId != currentlyFocusedElementId else {
            return
        }
        guard elementId != previouslyFocusedElementId || lastFocusOutTimestamp.timeIntervalSinceNow < -0.1 else {
            Logger.shared.logDebug("Focus in detected within 100ms after focus out on the same field, ignoring", category: .passwordManagerInternal)
            return
        }
        guard let autocompleteGroup = fieldClassifiers?.autocompleteGroup(for: elementId, frameInfo: frameInfo) else {
            dismissPasswordManagerMenu()
            clearInputFocus()
            return
        }
        guard !disabledForSubmit else {
            disabledForSubmit = false
            return
        }
        currentlyFocusedElementId = elementId
        currentInputFrame = frameInfo
        if let contents = contents, contents.isEmpty, autocompleteGroup.action.isPasswordRelated, !autocompleteGroup.isAmbiguous {
            checkSimilarFieldsEmpty(elementId: elementId, inGroup: autocompleteGroup, frameInfo: frameInfo) { empty in
                self.showPasswordManagerMenu(for: elementId, frameInfo: frameInfo, emptyField: empty, inGroup: autocompleteGroup)
            }
        } else {
            dismissPasswordManagerMenu()
        }
        if autocompleteGroup.action.isPasswordRelated {
            showIcon(onField: elementId, frameInfo: frameInfo)
        }
    }

    func inputFieldDidLoseFocus(_ elementId: String, frameInfo: WKFrameInfo?) {
        Logger.shared.logDebug("Text field \(elementId) lost focus.", category: .passwordManagerInternal)
        requestValuesFromTextFields(frameInfo: frameInfo) { dict in
            if let dict = dict {
                self.valuesOnFocusOut = dict
                self.updateStoredValues(with: dict, userInput: true, frameInfo: frameInfo)
            }
        }
        dismissPasswordManagerMenu()
        lastFocusOutTimestamp = BeamDate.now
        previouslyFocusedElementId = elementId
        clearInputFocus()
    }

    func updateScrollPosition(for frame: WebPositions.FrameInfo) {
        scrollUpdater.send(frame)
    }

    private func showIcon(onField elementId: String, frameInfo: WKFrameInfo?) {
        guard fieldWithIcon != elementId else { return }
        if fieldWithIcon != nil {
            clearIcon()
        }
        requestWebFieldFrame(elementId: elementId, frameInfo: frameInfo) { rect in
            if let rect = rect {
                DispatchQueue.main.async {
                    let location = CGRect(x: rect.origin.x + rect.width - 24 - 16, y: rect.origin.y - rect.height / 2 - 24 - 12, width: 24, height: 24)
                    guard let page = self.page,
                          let webView = (page as? BrowserTab)?.webView,
                          let buttonWindow = CustomPopoverPresenter.shared.presentPopoverChildWindow(canBecomeKey: false, canBecomeMain: false, withShadow: false, movable: false, storedInPresenter: true)
                    else { return }
                    buttonWindow.isMovableByWindowBackground = false
                    let buttonPopover = WebAutofillPopoverContainer(window: buttonWindow, page: page, frameURL: frameInfo?.request.url?.absoluteString, scrollUpdater: self.scrollUpdater)
                    self.passwordMenuPopover?.orderFront()
                    let buttonView = WebFieldAutofillButton { [weak self] in
                        if let self = self, self.passwordMenuPopover == nil, let autocompleteGroup = self.fieldClassifiers?.autocompleteGroup(for: elementId, frameInfo: frameInfo) {
                            self.checkSimilarFieldsEmpty(elementId: elementId, inGroup: autocompleteGroup, frameInfo: frameInfo) { empty in
                                self.showPasswordManagerMenu(for: elementId, frameInfo: frameInfo, emptyField: empty, inGroup: autocompleteGroup)
                            }
                        }
                    }
                    buttonWindow.setView(with: buttonView, at: self.convertRect(location, relativeTo: webView).origin, fromTopLeft: true)
                    self.buttonPopover = buttonPopover
                    self.fieldWithIcon = elementId
                }
            }
        }
    }

    private func clearIcon() {
        guard fieldWithIcon != nil else { return }
        CustomPopoverPresenter.shared.dismissPopovers(animated: false)
        fieldWithIcon = nil
    }

    private func showPasswordManagerMenu(for elementId: String, frameInfo: WKFrameInfo?, emptyField: Bool, inGroup autocompleteGroup: WebAutocompleteGroup) {
        if autocompleteGroup.isAmbiguous, let fieldWithFocus = autocompleteGroup.field(id: elementId) {
            self.showPasswordManagerMenu(for: elementId, frameInfo: frameInfo, options: fieldWithFocus.role.isPassword ? .ambiguousPassword : .login)
        } else {
            switch autocompleteGroup.action {
            case .createAccount:
                self.showPasswordManagerMenu(for: elementId, frameInfo: frameInfo, options: emptyField ? .createAccount : .createAccountWithMenu)
            case .login:
                self.showPasswordManagerMenu(for: elementId, frameInfo: frameInfo, options: .login)
            default:
                break
            }
        }
    }

    private func showPasswordManagerMenu(for elementId: String, frameInfo: WKFrameInfo?, options: PasswordManagerMenuOptions) {
        requestWebFieldFrame(elementId: elementId, frameInfo: frameInfo) { frame in
            if let frame = frame {
                DispatchQueue.main.async {
                    guard self.currentlyFocusedElementId == elementId else {
                        return
                    }
                    self.showPasswordManagerMenu(at: frame, frameInfo: frameInfo, options: options)
                }
            } else {
                Logger.shared.logError("Could not get frame for element \(elementId)", category: .passwordManager)
            }
        }
    }

    private func showPasswordManagerMenu(at location: CGRect, frameInfo: WKFrameInfo?, options: PasswordManagerMenuOptions) {
        guard let host = self.page?.url else { return }
        if passwordMenuPopover != nil {
            dismissPasswordManagerMenu()
        }
        currentInputFrame = frameInfo
        let viewModel = passwordManagerViewModel(for: host, options: options)
        let passwordManagerMenu = PasswordManagerMenu(viewModel: viewModel)
        guard let page = page,
              let webView = (page as? BrowserTab)?.webView,
              let passwordWindow = CustomPopoverPresenter.shared.presentPopoverChildWindow(canBecomeKey: false, canBecomeMain: false, withShadow: false, useBeamShadow: true, lightBeamShadow: true, storedInPresenter: true)
        else { return }
        var updatedRect = convertRect(location, relativeTo: webView)
        updatedRect.origin.y += location.height
        passwordWindow.setView(with: passwordManagerMenu, at: updatedRect.origin, fromTopLeft: true)
        passwordWindow.delegate = viewModel.passwordGeneratorViewModel
        passwordMenuPopover = WebAutofillPopoverContainer(window: passwordWindow, page: page, frameURL: frameInfo?.request.url?.absoluteString, scrollUpdater: scrollUpdater, topEdgeHeight: 24)
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
        passwordMenuPopover = nil
        currentPasswordManagerViewModel = nil
        clearIcon() // required: the child window containing the icon is not visible anymore, but fieldWithIcon has not been reset
    }

    private func clearInputFocus() {
        currentInputFrame = nil
        currentlyFocusedElementId = nil
    }

    private func convertRect(_ rect: CGRect, relativeTo webView: WKWebView) -> CGRect {
        var rect = webView.convert(rect, to: nil)
        rect.origin.y -= webView.topContentInset
        return rect
    }

    func updateViewSize(width: CGFloat, height: CGFloat) {
        guard passwordMenuPopover != nil || buttonPopover != nil else {
            return
        }
        DispatchQueue.main.async {
            if self.passwordMenuPopover != nil {
                self.dismissPasswordManagerMenu()
                self.clearInputFocus()
            }
            self.clearIcon()
        }
    }

    private func requestWebFieldFrame(elementId: String, frameInfo: WKFrameInfo?, completion: @escaping (CGRect?) -> Void) {
        let script = "passwordHelper.getElementRects('[\"\(elementId)\"]')"
        self.page?.executeJS(script, objectName: JSObjectName, frameInfo: frameInfo).then { [weak self] jsResult in
            guard let self = self, let jsonString = jsResult as? String, let jsonData = jsonString.data(using: .utf8), let rects = try? self.decoder.decode([DOMRect?].self, from: jsonData), let rect = rects.first??.rect else {
                return completion(nil)
            }
            let offset: CGPoint
            if let href = frameInfo?.request.url?.absoluteString, let webPositions = self.page?.webPositions {
                offset = webPositions.viewportOffset(href: href)
            } else {
                offset = .zero
            }
            let scale = self.page?.webView.zoomLevel() ?? 1
            Logger.shared.logDebug("Frame for \(elementId): \(rect), with offset \(offset), scale: \(scale)", category: .passwordManagerInternal)
            let frame = CGRect(x: (rect.minX + offset.x) * scale, y: (rect.minY + offset.y + rect.height) * scale, width: rect.width * scale, height: rect.height * scale)
            completion(frame)
        }
    }

    func handleWebFormSubmit(with elementId: String, frameInfo: WKFrameInfo?) {
        Logger.shared.logDebug("Submit: \(elementId)", category: .passwordManagerInternal)
        disabledForSubmit = true // disable focus handler temporarily, to prevent the password manager menu from reappearing if the JS code triggers a selection in a text field
        dismissPasswordManagerMenu()
        requestValuesFromTextFields(frameInfo: frameInfo) { [weak self] dict in
            guard let self = self else { return }
            if let values = dict ?? self.valuesOnFocusOut {
                self.updateStoredValues(with: values, userInput: true, frameInfo: frameInfo)
                self.saveCredentialsIfChanged(allowEmptyUsername: true)
            }
            self.fieldClassifiers?.clear()
        }
    }

    fileprivate func getPageHost() -> String? {
        guard let host = self.page?.url?.minimizedHost else {
            if let url = self.page?.url?.absoluteString,
               url.starts(with: "file:///"),
               let localfile = url.split(separator: "/").last,
               let localfileWithoutQueryparams = localfile.split(separator: "?").first {
                return String(localfileWithoutQueryparams)
            }
            return nil
        }
        return host
    }

    private func checkSimilarFieldsEmpty(elementId: String, inGroup autocompleteGroup: WebAutocompleteGroup, frameInfo: WKFrameInfo?, completion: @escaping (Bool) -> Void) {
        let similarFieldIds: [String]
        if autocompleteGroup.field(id: elementId)?.role.isPassword ?? false {
            similarFieldIds = autocompleteGroup.relatedFields
                .filter { $0.role.isPassword }
                .map(\.id)
        } else {
            similarFieldIds = [elementId]
        }
        requestValuesFromTextFields(ids: similarFieldIds, frameInfo: frameInfo) { values in
            let allEmpty = (values?.first { !$0.isEmpty }) == nil
            completion(allEmpty)
        }
    }

    private func requestValuesFromTextFields(frameInfo: WKFrameInfo?, completion: @escaping (([String: String]?) -> Void)) {
        let ids = fieldClassifiers?.allInputFieldIds(frameInfo: frameInfo) ?? []
        requestValuesFromTextFields(ids: ids, frameInfo: frameInfo) { values in
            if let values = values {
                let dict = Dictionary(uniqueKeysWithValues: zip(ids, values))
                completion(dict)
            } else {
                completion(nil)
            }
        }
    }

    private func requestValuesFromTextFields(ids: [String], frameInfo: WKFrameInfo?, completion: @escaping (([String]?) -> Void)) {
        let formattedList = ids.map { "\"\($0)\"" }.joined(separator: ",")
        let script = "passwordHelper.getTextFieldValues('[\(formattedList)]')"
        self.page?.executeJS(script, objectName: JSObjectName, frameInfo: frameInfo, successLogCategory: .passwordManagerInternal).then { jsResult in
            if let jsonString = jsResult as? String,
               let jsonData = jsonString.data(using: .utf8),
               let values = try? self.decoder.decode([String].self, from: jsonData) {
                completion(values)
            } else {
                Logger.shared.logWarning("Unable to decode text field values from \(String(describing: jsResult))", category: .passwordManagerInternal)
                completion(nil)
            }
        }
    }

    private func updateStoredValues(with values: [String: String], userInput: Bool, frameInfo: WKFrameInfo?) {
        let (loginFieldIds, passwordFieldIds) = passwordFieldIdsForStorage(frameInfo: frameInfo)
        let firstNonEmptyLogin = values.valuesMatchingKeys(in: loginFieldIds).first { !$0.isEmpty }
        let firstNonEmptyPassword = values.valuesMatchingKeys(in: passwordFieldIds).first { !$0.isEmpty }
        credentialsBuilder.updateValues(username: firstNonEmptyLogin, password: firstNonEmptyPassword, userInput: userInput)
    }

    private func saveCredentialsIfChanged(allowEmptyUsername: Bool) {
        guard let hostname = getPageHost(),
              let credentials = credentialsBuilder.unsavedCredentials(allowEmptyUsername: allowEmptyUsername),
              let saveAction = saveCredentialsAction(hostname: hostname, credentials: credentials)
        else { return }
        // This code may be called multiple times for a given submit action.
        // Here we must mark credentials as saved regardless of the user's choice (if the user decides not to save, we don't want to present the dialog again, until the credentials have been changed again.)
        credentialsBuilder.markSaved()
        // TODO: make special case for credentials.username == nil
        Logger.shared.logDebug("Saving password for \(credentials.username ?? "<empty username>")", category: .passwordManagerInternal)
        confirmSavePassword(username: credentials.username ?? "", action: saveAction) { save in
            guard save else { return }
            if saveAction != .saveSilently, let browserTab = (self.page as? BrowserTab) {
                browserTab.passwordManagerToast(saved: saveAction == .save)
            }
            PasswordManager.shared.save(hostname: hostname, username: credentials.username ?? "", password: credentials.password)
        }
    }

    private func saveCredentialsAction(hostname: String, credentials: PasswordManagerCredentialsBuilder.StoredCredentials) -> PasswordSaveAction? {
        if let storedPassword = PasswordManager.shared.password(hostname: hostname, username: credentials.username ?? "") {
            guard credentials.password != storedPassword else { return nil }
            return .update
        }
        return credentials.askSaveConfirmation ? .save : .saveSilently
    }

    private func confirmSavePassword(username: String, action: PasswordSaveAction, onDismiss: @escaping (Bool) -> Void) {
        guard let window = self.page?.webviewWindow else {
            return onDismiss(true)
        }
        let alertMessage: String
        let saveButtonTitle: String
        switch action {
        case .save:
            alertMessage = "Would you like to save this password?"
            saveButtonTitle = "Save Password"
        case .update:
            alertMessage = "Would you like to update the saved password for \(username)?"
            saveButtonTitle = "Update Password"
        case .saveSilently:
            return onDismiss(true)
        }
        let alert = NSAlert()
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

    private func passwordFieldIdsForStorage(frameInfo: WKFrameInfo?) -> (usernameIds: [String], passwordIds: [String]) {
        let inputFields = fieldClassifiers?.allInputFields(frameInfo: frameInfo) ?? []
        let newPasswordIds = inputFields.filter { $0.role == .newPassword }.map(\.id)
        let currentPasswordIds = inputFields.filter { $0.role == .currentPassword }.map(\.id)
        let passwordIds = newPasswordIds + currentPasswordIds
        var usernameIds: [String]
        if !newPasswordIds.isEmpty {
            Logger.shared.logDebug("Storage: new password field(s) found", category: .passwordManagerInternal)
            usernameIds = inputFields.filter { $0.role == .newUsername }.map(\.id)
        } else {
            Logger.shared.logDebug("Storage: current password field(s) found", category: .passwordManagerInternal)
            usernameIds = []
        }
        usernameIds += inputFields.filter { $0.role == .currentUsername }.map(\.id)
        usernameIds += inputFields.filter { $0.role == .email }.map(\.id)
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
            PasswordManager.shared.markDeleted(hostname: entry.minimizedHost, for: entry.username)
        }
    }

    func fillCredentials(_ entry: PasswordManagerEntry) {
        guard let elementId = currentlyFocusedElementId, let autocompleteGroup = fieldClassifiers?.autocompleteGroup(for: elementId, frameInfo: currentInputFrame), autocompleteGroup.action == .login || autocompleteGroup.isAmbiguous else {
            Logger.shared.logError("AutocompleteContext (login) mismatch for id \(String(describing: currentlyFocusedElementId))", category: .passwordManager)
            dismissPasswordManagerMenu()
            return
        }
        guard let password = PasswordManager.shared.password(hostname: entry.minimizedHost, username: entry.username) else {
            Logger.shared.logError("PasswordStore did not provide password for selected entry.", category: .passwordManager)
            return
        }
        currentPasswordManagerViewModel?.revertToFirstItem()
        credentialsBuilder.autofill(host: entry.minimizedHost, username: entry.username, password: password)
        Logger.shared.logDebug("Filling fields: \(String(describing: autocompleteGroup.relatedFields))", category: .passwordManagerInternal)
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
        guard let elementId = currentlyFocusedElementId, let autocompleteGroup = fieldClassifiers?.autocompleteGroup(for: elementId, frameInfo: currentInputFrame), autocompleteGroup.action == .createAccount || autocompleteGroup.isAmbiguous else {
            Logger.shared.logError("AutocompleteContext (createAccount) mismatch for id \(String(describing: currentlyFocusedElementId))", category: .passwordManager)
            dismissPasswordManagerMenu()
            return
        }
        credentialsBuilder.storeGeneratedPassword(password)
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismissPasswordManagerMenu()
            self.togglePasswordField(visibility: false)
        }
    }

    private var passwordFieldIds: [String] {
        guard let elementId = currentlyFocusedElementId, let autocompleteGroup = fieldClassifiers?.autocompleteGroup(for: elementId, frameInfo: currentInputFrame) else {
            return []
        }
        return autocompleteGroup.relatedFields
            .filter { $0.role.isPassword }
            .map(\.id)
    }

    private func fillWebTextFields(_ params: [WebFieldAutofill]) {
        do {
            let data = try encoder.encode(params)
            guard let jsonString = String(data: data, encoding: .utf8) else { return }
            let script = "passwordHelper.setTextFieldValues('\(jsonString)')"
            self.page?.executeJS(script, objectName: JSObjectName, frameInfo: currentInputFrame, successLogCategory: .passwordManagerInternal).then { _ in
                Logger.shared.logDebug("passwordOverlay text fields set.", category: .passwordManagerInternal)
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
            let script = "passwordHelper.togglePasswordFieldVisibility('\(jsonString)', '\(visibility.description)')"
            self.page?.executeJS(script, objectName: JSObjectName, frameInfo: currentInputFrame, successLogCategory: .passwordManagerInternal)
        } catch {
            Logger.shared.logError("JSON encoding failure: \(error.localizedDescription))", category: .general)
        }
    }
}
