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
    private let queue = DispatchQueue(label: "WebFieldAutofillOverlay")
    private let passwordManager: PasswordManager
    private let creditCardManager: CreditCardAutofillManager
    private let userInfoStore: UserInformationsStore
    private let credentialsBuilder: PasswordManagerCredentialsBuilder
    private let creditCardBuilder: CreditCardAutofillBuilder
    private let scrollUpdater = PassthroughSubject<WebFrames.FrameInfo, Never>()
    private var currentOverlayInternal: WebFieldAutofillOverlay?
    private let encoder: JSONEncoder
    private let decoder: BeamJSONDecoder
    private var previouslyFocusedElementId: String?
    private var lastFocusOutTimestamp: Date = .distantPast
    private var disabledForSubmit = false
    private var valuesOnFocusOut: [String: String]?
    private var currentFrameIdentifier = 0
    private let JSObjectName = "PasswordManager"
    weak var page: WebPage?

    private lazy var fieldClassifiers: WebFieldClassifiers? = {
        guard let webFrames = self.page?.webFrames else { return nil }
        return WebFieldClassifiers(webFrames: webFrames)
    }()

    private var currentOverlay: WebFieldAutofillOverlay? {
        get {
            queue.sync {
                self.currentOverlayInternal
            }
        }
        set {
            queue.sync {
                self.currentOverlayInternal = newValue
            }
        }
    }

    init(passwordManager: PasswordManager = .shared, creditCardManager: CreditCardAutofillManager = .shared, userInfoStore: UserInformationsStore) {
        self.passwordManager = passwordManager
        self.creditCardManager = creditCardManager
        self.userInfoStore = userInfoStore
        credentialsBuilder = PasswordManagerCredentialsBuilder()
        creditCardBuilder = CreditCardAutofillBuilder()
        encoder = JSONEncoder()
        decoder = BeamJSONDecoder()
        super.init()
        PreferencesManager.$autofillUsernamePasswords.sink { [weak self] autofill in
            if !autofill && self?.currentOverlay?.autocompleteGroup.action.isPasswordRelated != false {
                self?.dismiss()
            }
        }.store(in: &scope)
        PreferencesManager.$autofillCreditCards.sink { [weak self] autofill in
            if !autofill && self?.currentOverlay?.autocompleteGroup.action == .payment {
                self?.dismiss()
            }
        }.store(in: &scope)
    }

    func prepareForLoading() {
        credentialsBuilder.enterPage(url: self.page?.url)
        creditCardBuilder.enterPage(url: self.page?.url)
        fieldClassifiers?.clear()
        dismissPasswordManager()
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

    private func isAutofillEnabled(for action: WebAutocompleteAction) -> Bool {
        switch action {
        case .login, .createAccount:
            return PreferencesManager.autofillUsernamePasswords
        case .payment:
            return PreferencesManager.autofillCreditCards
        case .personalInfo:
            return PreferencesManager.autofillAdresses
        }
    }

    private func isSaveEnabled(for action: WebAutocompleteAction) -> Bool {
        isAutofillEnabled(for: action)
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
            dismissPasswordManager()
            clearInputFocus()
            return
        }

        if let elementId = currentOverlay?.elementId ?? previouslyFocusedElementId, !elements.map(\.beamId).contains(elementId) {
            Logger.shared.logDebug("Focused field just disappeared", category: .passwordManagerInternal)
            dismissPasswordManager()
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
        guard page?.webviewWindow?.firstResponder == page?.webView else { return }
        guard elementId != currentOverlay?.elementId else { return }
        guard elementId != previouslyFocusedElementId || lastFocusOutTimestamp.timeIntervalSinceNow < -0.1 else {
            Logger.shared.logDebug("Focus in detected within 100ms after focus out on the same field, ignoring", category: .passwordManagerInternal)
            return
        }
        guard let autocompleteGroup = fieldClassifiers?.autocompleteGroup(for: elementId, frameInfo: frameInfo) else {
            dismissPasswordManager()
            clearInputFocus()
            return
        }
        guard !disabledForSubmit else {
            disabledForSubmit = false
            return
        }
        if let frameInfo = frameInfo, let href = frameInfo.request.url?.absoluteString, page?.webFrames?.isConnectedToMain(href: href) == false {
            Logger.shared.logWarning("Disconnected frame for \(href)", category: .passwordManager)
            page?.executeJS("dispatchEvent(new Event('beam_historyLoad'))", objectName: nil, frameInfo: nil)
            page?.executeJS("dispatchEvent(new Event('beam_historyLoad'))", objectName: nil, frameInfo: frameInfo)
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                self.handleInputFieldFocus(elementId: elementId, inGroup: autocompleteGroup, frameInfo: frameInfo, contents: contents)
            }
        } else {
            handleInputFieldFocus(elementId: elementId, inGroup: autocompleteGroup, frameInfo: frameInfo, contents: contents)
        }
    }

    private func handleInputFieldFocus(elementId: String, inGroup autocompleteGroup: WebAutocompleteGroup, frameInfo: WKFrameInfo?, contents: String?) {
        guard isAutofillEnabled(for: autocompleteGroup.action) else { return }
        guard menuOptions(for: elementId, emptyField: true, inGroup: autocompleteGroup) != nil || autocompleteGroup.action == .payment else { return }
        let fieldEdgeInsets: BeamEdgeInsets
        if let host = page?.url?.minimizedHost, let role = autocompleteGroup.field(id: elementId)?.role {
            fieldEdgeInsets = WebAutofillPositionModifier.shared.inputFieldEdgeInsets(host: host, action: autocompleteGroup.action, role: role)
        } else {
            fieldEdgeInsets = .zero
        }
        let overlay = WebFieldAutofillOverlay(page: page, scrollUpdater: scrollUpdater, frameInfo: frameInfo, elementId: elementId, inGroup: autocompleteGroup, elementEdgeInsets: fieldEdgeInsets) { frameInfo in
            self.showPasswordManagerMenu(for: elementId, inGroup: autocompleteGroup, frameInfo: frameInfo)
        }
        overlay.showIcon(frameInfo: frameInfo)
        currentOverlay = overlay
        showPasswordManagerMenu(for: elementId, inGroup: autocompleteGroup, frameInfo: frameInfo)
    }

    private func showWebFieldAutofillMenu(for elementId: String, inGroup autocompleteGroup: WebAutocompleteGroup, frameInfo: WKFrameInfo?) {
        switch autocompleteGroup.action {
        case .login, .createAccount:
            showPasswordManagerMenu(for: elementId, inGroup: autocompleteGroup, frameInfo: frameInfo)
        case .payment:
            showCreditCardsMenu(for: elementId, inGroup: autocompleteGroup, frameInfo: frameInfo)
        default:
            break
        }
    }

    private func showPasswordManagerMenu(for elementId: String, inGroup autocompleteGroup: WebAutocompleteGroup, frameInfo: WKFrameInfo?) {
        checkSimilarFieldsEmpty(elementId: elementId, inGroup: autocompleteGroup, frameInfo: frameInfo) { empty in
            guard let host = self.page?.url, let options = self.menuOptions(for: elementId, emptyField: empty, inGroup: autocompleteGroup) else { return }
            let viewModel = self.passwordManagerViewModel(for: host, options: options)
            DispatchQueue.main.async {
                self.currentOverlay?.showPasswordManagerMenu(frameInfo: frameInfo, viewModel: viewModel)
            }
        }
    }

    private func showCreditCardsMenu(for elementId: String, inGroup autocompleteGroup: WebAutocompleteGroup, frameInfo: WKFrameInfo?) {
        let creditCards = creditCardManager.fetchAll()
        guard !creditCards.isEmpty else { return }
        let viewModel = CreditCardsMenuViewModel(entries: creditCards)
        viewModel.delegate = self
        DispatchQueue.main.async {
            self.currentOverlay?.showCreditCardsMenu(frameInfo: frameInfo, viewModel: viewModel)
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
        dismissPasswordManager()
        lastFocusOutTimestamp = BeamDate.now
        previouslyFocusedElementId = elementId
        clearInputFocus()
    }

    func updateScrollPosition(for frame: WebFrames.FrameInfo) {
        scrollUpdater.send(frame)
    }

    private func menuOptions(for elementId: String, emptyField: Bool, inGroup autocompleteGroup: WebAutocompleteGroup) -> PasswordManagerMenuOptions? {
        if autocompleteGroup.isAmbiguous, let fieldWithFocus = autocompleteGroup.field(id: elementId) {
            return fieldWithFocus.role.isPassword ? .ambiguousPassword : .login
        }
        switch autocompleteGroup.action {
        case .createAccount:
            guard let fieldWithFocus = autocompleteGroup.field(id: elementId), fieldWithFocus.role.isPassword else { return nil }
            return emptyField ? .createAccount : .createAccountWithMenu
        case .login:
            return .login
        default:
            return nil
        }
    }

    private func passwordManagerViewModel(for host: URL, options: PasswordManagerMenuOptions) -> PasswordManagerMenuViewModel {
        let viewModel = PasswordManagerMenuViewModel(host: host, credentialsBuilder: credentialsBuilder, userInfoStore: userInfoStore, options: options)
        viewModel.delegate = self
        return viewModel
    }

    private func dismissPasswordManager() {
        guard let overlay = currentOverlay else { return }
        overlay.dismissPasswordManagerMenu()
        overlay.clearIcon()
    }

    private func clearInputFocus() {
        currentOverlay = nil
    }

    func updateViewSize(width: CGFloat, height: CGFloat) {
        DispatchQueue.main.async {
            self.dismissPasswordManager()
        }
    }

    func handleWebFormSubmit(with elementId: String, frameInfo: WKFrameInfo?) {
        Logger.shared.logDebug("Submit: \(elementId)", category: .passwordManagerInternal)
        disabledForSubmit = true // disable focus handler temporarily, to prevent the password manager menu from reappearing if the JS code triggers a selection in a text field
        dismissPasswordManager()
        requestValuesFromTextFields(frameInfo: frameInfo) { [weak self] dict in
            guard let self = self else { return }
            if let values = dict ?? self.valuesOnFocusOut {
                self.updateStoredValues(with: values, userInput: true, frameInfo: frameInfo)
                self.saveCreditCardIfChanged()
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
        var fieldsWithContents = values.filter { !$0.value.isEmpty }
        for elementId in fieldsWithContents.keys {
            guard let autocompleteGroup = fieldClassifiers?.autocompleteGroup(for: elementId, frameInfo: frameInfo),
                  let role = autocompleteGroup.relatedFields.first(where: { $0.id == elementId })?.role,
                  let value = fieldsWithContents[elementId]
            else { continue }
            switch autocompleteGroup.action {
            case .payment:
                creditCardBuilder.update(value: value, forRole: role)
                fieldsWithContents[elementId] = nil
            default:
                break
            }
        }
        // all remaining fields can be considered for sign in / sign up.
        let (loginFieldIds, passwordFieldIds) = passwordFieldIdsForStorage(frameInfo: frameInfo)
        let firstNonEmptyLogin = fieldsWithContents.valuesMatchingKeys(in: loginFieldIds).first { !$0.isEmpty }
        let firstNonEmptyPassword = fieldsWithContents.valuesMatchingKeys(in: passwordFieldIds).first { !$0.isEmpty }
        credentialsBuilder.updateValues(username: firstNonEmptyLogin, password: firstNonEmptyPassword, userInput: userInput)
    }

    private func saveCredentialsIfChanged(allowEmptyUsername: Bool) {
        guard isSaveEnabled(for: .login),
              let hostname = getPageHost(),
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
            let savedHostname: String
            switch saveAction {
            case .save, .saveSilently:
                savedHostname = HostnameCanonicalizer.shared.canonicalHostname(for: hostname) ?? hostname
            case .update:
                savedHostname = hostname
            }
            self.passwordManager.save(hostname: savedHostname, username: credentials.username ?? "", password: credentials.password)
        }
    }

    private func saveCredentialsAction(hostname: String, credentials: PasswordManagerCredentialsBuilder.StoredCredentials) -> PasswordSaveAction? {
        if let storedPassword = passwordManager.password(hostname: hostname, username: credentials.username ?? "") {
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

    private func saveCreditCardIfChanged() {
        guard isSaveEnabled(for: .payment), var creditCard = creditCardBuilder.unsavedCreditCard() else {
            return
        }
        creditCardBuilder.markSaved()
        if creditCard.databaseID == nil && creditCard.cardDescription.isEmpty {
            creditCard.cardDescription = creditCard.cardHolder
        }
        confirmSaveCreditCard(update: creditCard.databaseID != nil, description: creditCard.cardDescription) { [weak self] save in
            guard save else { return }
            self?.creditCardManager.save(entry: creditCard)
        }
    }

    private func confirmSaveCreditCard(update: Bool, description: String, onDismiss: @escaping (Bool) -> Void) {
        guard let window = self.page?.webviewWindow else {
            return onDismiss(false)
        }
        let alertMessage: String
        let saveButtonTitle: String
        if update {
            alertMessage = "Would you like to update this credit card?"
            saveButtonTitle = "Update Credit Card"
        } else {
            alertMessage = "Would you like to save this credit card?"
            saveButtonTitle = "Save Credit Card"
        }
        let alert = NSAlert()
        alert.messageText = alertMessage
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
            passwordManager.markDeleted(hostname: entry.minimizedHost, for: entry.username)
        }
    }

    func fillCredentials(_ entry: PasswordManagerEntry) {
        guard let autocompleteGroup = currentOverlay?.autocompleteGroup, autocompleteGroup.action == .login || autocompleteGroup.isAmbiguous else {
            Logger.shared.logError("AutocompleteContext (login) mismatch for id \(String(describing: currentOverlay?.elementId))", category: .passwordManager)
            dismissPasswordManager()
            return
        }
        guard let password = passwordManager.password(hostname: entry.minimizedHost, username: entry.username) else {
            Logger.shared.logError("PasswordStore did not provide password for selected entry.", category: .passwordManager)
            return
        }
        currentOverlay?.revertMenuToDefault()
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
            self.dismissPasswordManager()
        }
    }

    func fillNewPassword(_ password: String, dismiss: Bool = true) {
        guard let autocompleteGroup = currentOverlay?.autocompleteGroup, autocompleteGroup.action == .createAccount || autocompleteGroup.isAmbiguous else {
            Logger.shared.logError("AutocompleteContext (createAccount) mismatch for id \(String(describing: currentOverlay?.elementId))", category: .passwordManager)
            dismissPasswordManager()
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
                self.dismissPasswordManager()
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
            self.dismissPasswordManager()
        }
    }

    func dismissMenu() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentOverlay?.dismissPasswordManagerMenu()
        }
    }

    func dismiss() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismissPasswordManager()
            self.togglePasswordField(visibility: false)
        }
    }

    private var passwordFieldIds: [String] {
        guard let autocompleteGroup = currentOverlay?.autocompleteGroup else {
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
            self.page?.executeJS(script, objectName: JSObjectName, frameInfo: currentOverlay?.frameInfo, successLogCategory: .passwordManagerInternal).then { _ in
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
            self.page?.executeJS(script, objectName: JSObjectName, frameInfo: currentOverlay?.frameInfo, successLogCategory: .passwordManagerInternal)
        } catch {
            Logger.shared.logError("JSON encoding failure: \(error.localizedDescription))", category: .general)
        }
    }
}

extension PasswordOverlayController: CreditCardsMenuDelegate {
    func deleteCreditCards(_ entries: [CreditCardEntry]) {
        for entry in entries {
            creditCardManager.markDeleted(entry: entry)
        }
    }

    func fillCreditCard(_ entry: CreditCardEntry) {
        guard let autocompleteGroup = currentOverlay?.autocompleteGroup, autocompleteGroup.action == .payment else {
            Logger.shared.logError("AutocompleteContext (payment) mismatch for id \(String(describing: currentOverlay?.elementId))", category: .passwordManager)
            dismissPasswordManager()
            return
        }
        currentOverlay?.revertMenuToDefault()
        creditCardBuilder.autofill(creditCard: entry)
        Logger.shared.logDebug("Filling fields: \(String(describing: autocompleteGroup.relatedFields))", category: .passwordManagerInternal)
        let backgroundColor = BeamColor.Autocomplete.clickedBackground.hexColor
        let autofill = autocompleteGroup.relatedFields.compactMap { field -> WebFieldAutofill? in
            switch field.role {
            case .cardNumber:
                return WebFieldAutofill(id: field.id, value: entry.cardNumber, background: backgroundColor)
            case .cardHolder:
                return WebFieldAutofill(id: field.id, value: entry.cardHolder, background: backgroundColor)
            case .cardExpirationDate:
                return WebFieldAutofill(id: field.id, value: entry.formattedDate, background: backgroundColor)
            case .cardExpirationMonth:
                return WebFieldAutofill(id: field.id, value: entry.formattedMonth, background: backgroundColor)
            case .cardExpirationYear:
                return WebFieldAutofill(id: field.id, value: entry.formattedYear, background: backgroundColor)
            default:
                return nil
            }
        }
        self.fillWebTextFields(autofill)
        DispatchQueue.main.async {
            self.dismissPasswordManager()
        }
    }
}
