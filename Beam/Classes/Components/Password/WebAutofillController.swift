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

import Combine

struct WebFieldAutofill: Codable {
    var id: String
    var value: String?
    var background: String?
}

enum PasswordSaveAction: Equatable {
    case save
    case update(entry: PasswordManagerEntry)
    case saveSilently
}

// swiftlint:disable type_body_length
class WebAutofillController: NSObject, WebPageRelated {
    private var scope = Set<AnyCancellable>()
    private let lock = RWLock()
    private let passwordManager: PasswordManager
    private let creditCardManager: CreditCardAutofillManager
    private let userInfoStore: UserInformationsStore
    private let credentialsBuilder: PasswordManagerCredentialsBuilder
    private let creditCardBuilder: CreditCardAutofillBuilder
    private let scrollUpdater = PassthroughSubject<WebFrames.FrameInfo, Never>()
    private var currentOverlay: WebFieldAutofillOverlay?
    private let encoder: JSONEncoder
    private let decoder: BeamJSONDecoder
    private var previouslyFocusedElementId: String?
    private var lastFocusOutTimestamp: Date = .distantPast
    private var disabledForSubmit = false
    private var valuesOnFocusOut: [String: String]?
    private var fieldsWithInstalledFocusHandler = Set<String>() // element = field beamId
    private var framesWithInstalledSubmitHandler = Set<String>() // element = frame href
    private var currentFrameIdentifier = 0
    private let JSObjectName = "PasswordManager"
    weak var page: WebPage?

    private lazy var fieldClassifiers: WebFieldClassifiers? = {
        guard let webFrames = self.page?.webFrames else { return nil }
        return WebFieldClassifiers(webFrames: webFrames)
    }()

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
            if !autofill && self?.currentOverlay?.autofillGroup.action.isPasswordRelated != false {
                self?.dismiss()
            }
        }.store(in: &scope)
        PreferencesManager.$autofillCreditCards.sink { [weak self] autofill in
            if !autofill && self?.currentOverlay?.autofillGroup.action == .payment {
                self?.dismiss()
            }
        }.store(in: &scope)
    }

    func prepareForLoading() {
        lock.write { [weak self] in
            guard let self = self else { return }
            self.credentialsBuilder.enterPage(url: self.page?.url)
            self.creditCardBuilder.enterPage(url: self.page?.url)
            self.fieldClassifiers?.clear()
            self.fieldsWithInstalledFocusHandler.removeAll()
            self.framesWithInstalledSubmitHandler.removeAll()
            self.clearInputFocus()
            self.currentFrameIdentifier = 0
        }
    }

    func webViewFinishedLoading() {
        Logger.shared.logDebug("Web view finished loading", category: .webAutofillInternal)
    }

    private func nextFrameIdentifier() -> Int {
        return lock.write { [weak self] in
            self?.currentFrameIdentifier += 1
            return self?.currentFrameIdentifier ?? 0
        }
    }

    private func isAutofillEnabled(for action: WebAutofillAction) -> Bool {
        switch action {
        case .login, .createAccount:
            return PreferencesManager.autofillUsernamePasswords
        case .payment:
            return PreferencesManager.autofillCreditCards
        case .personalInfo:
            return PreferencesManager.autofillAdresses
        }
    }

    private func isSaveEnabled(for action: WebAutofillAction) -> Bool {
        isAutofillEnabled(for: action)
    }

    func requestInputFields(frameInfo: WKFrameInfo?) {
        guard let frameHref = frameInfo?.request.url?.absoluteString, frameHref != "about:blank" else { return }
        let frameIdentifier = nextFrameIdentifier()
        page?.executeJS("sendTextFields('\(frameIdentifier)')", objectName: JSObjectName, frameInfo: frameInfo, successLogCategory: .webAutofillInternal)
    }

    func updateInputFields(with jsResult: String, frameInfo: WKFrameInfo?) {
        Logger.shared.logDebug("updateInputFields", category: .webAutofillInternal)
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
            Logger.shared.logDebug("Detected fields: \(elements.map { $0.debugDescription })", category: .webAutofillInternal)
        } catch {
            Logger.shared.logError(String(describing: error), category: .passwordManager)
            clearInputFocus()
            return
        }

        if let elementId = currentOverlay?.elementId ?? previouslyFocusedElementId, !elements.map(\.beamId).contains(elementId) {
            Logger.shared.logDebug("Focused field just disappeared", category: .webAutofillInternal)
            saveCredentialsIfChanged(allowEmptyUsername: false)
            clearInputFocus()
        }

        fieldClassifiers?.classify(fields: elements, host: getPageHost(), frameInfo: frameInfo)
        let values: [String: String] = elements.reduce(into: [:]) { dict, element in
            if let value = element.value {
                dict[element.beamId] = value
            }
        }
        if !values.isEmpty {
            self.updateStoredValues(with: values, userInput: false, frameInfo: frameInfo)
        }
        let newFieldsWithFocusHandler = lock.read { [fieldsWithInstalledFocusHandler] in
            elements
                .map(\.beamId)
                .filter { !fieldsWithInstalledFocusHandler.contains($0) }
        }
        if !newFieldsWithFocusHandler.isEmpty {
            installSubmitHandlerIfNeeded(frameInfo: frameInfo) {
                self.installFocusHandlers(addedIds: newFieldsWithFocusHandler, frameInfo: frameInfo)
            }
            self.page?.executeJS("passwordHelper.getFocusedField()", objectName: JSObjectName, frameInfo: frameInfo, successLogCategory: .webAutofillInternal) { result in
                switch result {
                case .success(let res):
                    if let focusedId = res as? String {
                        DispatchQueue.main.async {
                            self.inputFieldDidGainFocus(focusedId, frameInfo: frameInfo, contents: nil)
                        }
                    }
                case .failure(let error):
                    Logger.shared.logError("WebAutofillController error updating input fields: \(error)", category: .webAutofillInternal)
                }
            }
        }
        disabledForSubmit = false
    }

    private func installSubmitHandlerIfNeeded(frameInfo: WKFrameInfo?, completion: @escaping () -> Void) {
        guard let page = page,
              let frameHref = frameInfo?.request.url?.absoluteString
        else {
            return completion()
        }
        let alreadyInstalled = lock.read { [framesWithInstalledSubmitHandler] in
            framesWithInstalledSubmitHandler.contains(frameHref)
        }
        guard !alreadyInstalled else {
            return completion()
        }

        Task {
            page.executeJS("installSubmitHandler()", objectName: JSObjectName, frameInfo: frameInfo, successLogCategory: .webAutofillInternal)
            _ = lock.write { [weak self] in
                self?.framesWithInstalledSubmitHandler.insert(frameHref)
            }
            completion()
        }
    }

    private func installFocusHandlers(addedIds: [String], frameInfo: WKFrameInfo?) {
        let formattedList = addedIds.map { "\"\($0)\"" }.joined(separator: ",")
        let focusScript = "installFocusHandlers('[\(formattedList)]')"
        self.page?.executeJS(focusScript, objectName: JSObjectName, frameInfo: frameInfo, successLogCategory: .webAutofillInternal)
        lock.write { [weak self] in
            guard let self = self else { return }
            for fieldId in addedIds {
                self.fieldsWithInstalledFocusHandler.insert(fieldId)
            }
            Logger.shared.logDebug("Fields with focus handlers: \(self.fieldsWithInstalledFocusHandler)", category: .webAutofillInternal)
        }
    }

    func inputFieldDidGainFocus(_ elementId: String, frameInfo: WKFrameInfo?, contents: String?) {
        Logger.shared.logDebug("Text field \(elementId) gained focus.", category: .webAutofillInternal)
        guard page?.webviewWindow?.firstResponder == page?.webView else { return }
        guard elementId != currentOverlay?.elementId else { return }
        guard elementId != previouslyFocusedElementId || lastFocusOutTimestamp.timeIntervalSinceNow < -0.1 else {
            Logger.shared.logDebug("Focus in detected within 100ms after focus out on the same field, ignoring", category: .webAutofillInternal)
            return
        }
        guard let autofillGroup = fieldClassifiers?.autofillGroup(for: elementId, frameInfo: frameInfo) else {
            DispatchQueue.main.async {
                self.clearInputFocus()
                Task.init {
                    self.page?.executeJS("sendTextFields(null)", objectName: self.JSObjectName, frameInfo: frameInfo, successLogCategory: .webAutofillInternal)
                    if let autofillGroup = self.fieldClassifiers?.autofillGroup(for: elementId, frameInfo: frameInfo) {
                        self.handleInputFieldFocus(elementId: elementId, inGroup: autofillGroup, frameInfo: frameInfo, contents: contents)
                    }
                }
            }
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
                self.handleInputFieldFocus(elementId: elementId, inGroup: autofillGroup, frameInfo: frameInfo, contents: contents)
            }
        } else {
            handleInputFieldFocus(elementId: elementId, inGroup: autofillGroup, frameInfo: frameInfo, contents: contents)
        }
    }

    private func handleInputFieldFocus(elementId: String, inGroup autofillGroup: WebAutofillGroup, frameInfo: WKFrameInfo?, contents: String?) {
        guard isAutofillEnabled(for: autofillGroup.action) else { return }
        let menuOptions = menuOptions(for: elementId, emptyField: true, inGroup: autofillGroup)
        guard menuOptions != nil || autofillGroup.action == .payment else { return }
        let fieldEdgeInsets: BeamEdgeInsets
        if let host = page?.url?.minimizedHost, let role = autofillGroup.field(id: elementId)?.role {
            fieldEdgeInsets = WebAutofillPositionModifier.shared.inputFieldEdgeInsets(host: host, action: autofillGroup.action, role: role)
        } else {
            fieldEdgeInsets = .zero
        }
        let overlay = WebFieldAutofillOverlay(page: page, scrollUpdater: scrollUpdater, frameInfo: frameInfo, elementId: elementId, inGroup: autofillGroup, elementEdgeInsets: fieldEdgeInsets) { frameInfo in
            self.showWebFieldAutofillMenu(for: elementId, inGroup: autofillGroup, frameInfo: frameInfo)
        }
        overlay.showIcon(frameInfo: frameInfo)
        lock.write { [weak self] in
            self?.currentOverlay?.dismiss()
            self?.currentOverlay = overlay
        }
        if autofillMenuHasSignificantContents(autofillGroup: autofillGroup, menuOptions: menuOptions) {
            showWebFieldAutofillMenu(for: elementId, inGroup: autofillGroup, frameInfo: frameInfo)
        }
    }

    private func autofillMenuHasSignificantContents(autofillGroup: WebAutofillGroup, menuOptions: PasswordManagerMenuOptions?) -> Bool {
        if autofillGroup.action == .payment { return true }
        guard let menuOptions = menuOptions, let minimizedHost = getPageHost() else { return false }
        return menuOptions.suggestNewPassword || credentialsBuilder.suggestedEntry() != nil || !PasswordManager.shared.entries(for: minimizedHost, options: .fuzzy).isEmpty
    }

    private func showWebFieldAutofillMenu(for elementId: String, inGroup autofillGroup: WebAutofillGroup, frameInfo: WKFrameInfo?) {
        switch autofillGroup.action {
        case .login, .createAccount:
            showPasswordManagerMenu(for: elementId, inGroup: autofillGroup, frameInfo: frameInfo)
        case .payment:
            showCreditCardsMenu(for: elementId, inGroup: autofillGroup, frameInfo: frameInfo)
        default:
            break
        }
    }

    private func showPasswordManagerMenu(for elementId: String, inGroup autofillGroup: WebAutofillGroup, frameInfo: WKFrameInfo?) {
        checkSimilarFieldsEmpty(elementId: elementId, inGroup: autofillGroup, frameInfo: frameInfo) { empty in
            guard let host = self.page?.url, let options = self.menuOptions(for: elementId, emptyField: empty, inGroup: autofillGroup) else { return }
            let viewModel = self.passwordManagerViewModel(for: host, options: options)
            DispatchQueue.main.async {
                self.currentOverlay?.showPasswordManagerMenu(frameInfo: frameInfo, viewModel: viewModel)
            }
        }
    }

    private func showCreditCardsMenu(for elementId: String, inGroup autofillGroup: WebAutofillGroup, frameInfo: WKFrameInfo?) {
        let creditCards = creditCardManager.fetchAll()
        guard !creditCards.isEmpty else { return }
        let viewModel = CreditCardsMenuViewModel(entries: creditCards)
        viewModel.delegate = self
        DispatchQueue.main.async {
            self.currentOverlay?.showCreditCardsMenu(frameInfo: frameInfo, viewModel: viewModel)
        }
    }

    func inputFieldDidLoseFocus(_ elementId: String, frameInfo: WKFrameInfo?) {
        Logger.shared.logDebug("Text field \(elementId) lost focus.", category: .webAutofillInternal)
        requestValuesFromTextFields(frameInfo: frameInfo) { dict in
            if let dict = dict {
                self.valuesOnFocusOut = dict
                self.updateStoredValues(with: dict, userInput: true, frameInfo: frameInfo)
            }
        }
        clearInputFocus()
    }

    func updateScrollPosition(for frame: WebFrames.FrameInfo) {
        scrollUpdater.send(frame)
    }

    private func menuOptions(for elementId: String, emptyField: Bool, inGroup autofillGroup: WebAutofillGroup) -> PasswordManagerMenuOptions? {
        if autofillGroup.isAmbiguous, let fieldWithFocus = autofillGroup.field(id: elementId) {
            return fieldWithFocus.role.isPassword ? .ambiguousPassword : .login
        }
        switch autofillGroup.action {
        case .createAccount:
            guard let fieldWithFocus = autofillGroup.field(id: elementId), fieldWithFocus.role.isPassword else { return nil }
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

    private func clearInputFocus() {
        guard let overlay = currentOverlay else { return }
        previouslyFocusedElementId = overlay.elementId
        overlay.dismiss()
        lastFocusOutTimestamp = BeamDate.now
        currentOverlay = nil
    }

    func updateViewSize(width: CGFloat, height: CGFloat) {
        clearInputFocus()
    }

    func handleWebFormSubmit(with elementId: String, frameInfo: WKFrameInfo?) {
        Logger.shared.logDebug("Submit: \(elementId)", category: .webAutofillInternal)
        disabledForSubmit = true // disable focus handler temporarily, to prevent the password manager menu from reappearing if the JS code triggers a selection in a text field
        clearInputFocus()
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

    private func checkSimilarFieldsEmpty(elementId: String, inGroup autofillGroup: WebAutofillGroup, frameInfo: WKFrameInfo?, completion: @escaping (Bool) -> Void) {
        let similarFieldIds: [String]
        if autofillGroup.field(id: elementId)?.role.isPassword ?? false {
            similarFieldIds = autofillGroup.relatedFields
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
        self.page?.executeJS(script, objectName: JSObjectName, frameInfo: frameInfo, successLogCategory: .webAutofillInternal) { result in
            switch result {
            case .success(let jsResult):
                if let jsonString = jsResult as? String,
                   let jsonData = jsonString.data(using: .utf8),
                   let values = try? self.decoder.decode([String].self, from: jsonData) {
                    completion(values)
                } else {
                    Logger.shared.logWarning("Unable to decode text field values from \(String(describing: jsResult))", category: .webAutofillInternal)
                    completion(nil)
                }
            case .failure(let error):
                Logger.shared.logError("WebAutofillController error requesting value from text fields: \(error)", category: .webAutofillInternal)
            }
        }
    }

    private func updateStoredValues(with values: [String: String], userInput: Bool, frameInfo: WKFrameInfo?) {
        var fieldsWithContents = values.filter { !$0.value.isEmpty }
        for elementId in fieldsWithContents.keys {
            guard let autofillGroup = fieldClassifiers?.autofillGroup(for: elementId, frameInfo: frameInfo),
                  let role = autofillGroup.relatedFields.first(where: { $0.id == elementId })?.role,
                  let value = fieldsWithContents[elementId]
            else { continue }
            switch autofillGroup.action {
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
        Logger.shared.logDebug("Saving password for \(credentials.username ?? "<empty username>")", category: .webAutofillInternal)
        confirmSavePassword(username: credentials.username ?? "", action: saveAction) { save in
            guard save else { return }
            if saveAction != .saveSilently, let browserTab = (self.page as? BrowserTab) {
                browserTab.passwordManagerToast(saved: saveAction == .save)
            }
            let savedHostname: String
            switch saveAction {
            case .save, .saveSilently:
                savedHostname = HostnameCanonicalizer.shared.canonicalHostname(for: hostname) ?? hostname
            case .update(let entry):
                savedHostname = entry.minimizedHost
            }
            self.passwordManager.save(hostname: savedHostname, username: credentials.username ?? "", password: credentials.password)
        }
    }

    private func saveCredentialsAction(hostname: String, credentials: PasswordManagerCredentialsBuilder.StoredCredentials) -> PasswordSaveAction? {
        if let storedEntry = passwordManager.bestMatchingEntry(hostname: hostname, exactUsername: credentials.username ?? ""),
           let storedPassword = try? passwordManager.password(hostname: storedEntry.minimizedHost, username: credentials.username ?? "", markUsed: false) {
            guard credentials.password != storedPassword else { return nil }
            return .update(entry: storedEntry)
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
            Logger.shared.logDebug("Storage: new password field(s) found", category: .webAutofillInternal)
            usernameIds = inputFields.filter { $0.role == .newUsername }.map(\.id)
        } else {
            Logger.shared.logDebug("Storage: current password field(s) found", category: .webAutofillInternal)
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

extension WebAutofillController: WebAutofillMenuDelegate {
    func dismissMenu() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentOverlay?.dismissMenu()
        }
    }

    func dismiss() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.togglePasswordField(visibility: false)
            self.clearInputFocus()
        }
    }
}

extension WebAutofillController: PasswordManagerMenuDelegate {
    func deleteCredentials(_ entries: [PasswordManagerEntry]) {
        for entry in entries {
            passwordManager.markDeleted(hostname: entry.minimizedHost, for: entry.username)
        }
    }

    func fillCredentials(_ entry: PasswordManagerEntry) {
        guard let autofillGroup = currentOverlay?.autofillGroup, autofillGroup.action == .login || autofillGroup.isAmbiguous else {
            Logger.shared.logError("Classifier (login) mismatch for id \(String(describing: currentOverlay?.elementId))", category: .passwordManager)
            clearInputFocus()
            return
        }
        do {
            let password = try passwordManager.password(hostname: entry.minimizedHost, username: entry.username, markUsed: true)
            currentOverlay?.revertMenuToDefault()
            credentialsBuilder.autofill(host: entry.minimizedHost, username: entry.username, password: password)
            Logger.shared.logDebug("Filling fields: \(String(describing: autofillGroup.relatedFields))", category: .webAutofillInternal)
            let backgroundColor = BeamColor.Autocomplete.clickedBackground.hexColor
            let autofill = autofillGroup.relatedFields.compactMap { field -> WebFieldAutofill? in
                switch field.role {
                case .currentUsername:
                    return WebFieldAutofill(id: field.id, value: entry.username, background: backgroundColor)
                case .newUsername:
                    return autofillGroup.isAmbiguous ? WebFieldAutofill(id: field.id, value: entry.username, background: backgroundColor) : nil
                case .currentPassword:
                    return WebFieldAutofill(id: field.id, value: password, background: backgroundColor)
                case .newPassword:
                    return autofillGroup.isAmbiguous ? WebFieldAutofill(id: field.id, value: password, background: backgroundColor) : nil
                default:
                    return nil
                }
            }
            self.fillWebTextFields(autofill)
            clearInputFocus()
        } catch {
            Logger.shared.logError("PasswordStore did not provide password for selected entry.", category: .passwordManager)
            showAlert(error: error)
        }
    }

    func fillNewPassword(_ password: String, dismiss: Bool = true) {
        guard let autofillGroup = currentOverlay?.autofillGroup, autofillGroup.action == .createAccount || autofillGroup.isAmbiguous else {
            Logger.shared.logError("Classifier (createAccount) mismatch for id \(String(describing: currentOverlay?.elementId))", category: .passwordManager)
            clearInputFocus()
            return
        }
        credentialsBuilder.storeGeneratedPassword(password)
        let backgroundColor = BeamColor.Autocomplete.clickedBackground.hexColor
        let autofill = autofillGroup.relatedFields.compactMap { field -> WebFieldAutofill? in
            switch field.role {
            case .newPassword:
                return WebFieldAutofill(id: field.id, value: password, background: backgroundColor)
            case .currentPassword:
                return autofillGroup.isAmbiguous ? WebFieldAutofill(id: field.id, value: password, background: backgroundColor) : nil
            default:
                return nil
            }
        }
        self.fillWebTextFields(autofill)
        self.togglePasswordField(visibility: true)
        if dismiss {
            currentOverlay?.dismiss() // keep autocompleteGroup around while password is visible
        }
    }

    func emptyPasswordField() {
        let emptyParams = passwordFieldIds.map { id in
            WebFieldAutofill(id: id, value: "", background: nil)
        }
        self.togglePasswordField(visibility: false)
        self.fillWebTextFields(emptyParams)
        clearInputFocus()
    }

    private var passwordFieldIds: [String] {
        guard let autofillGroup = currentOverlay?.autofillGroup else {
            return []
        }
        return autofillGroup.relatedFields
            .filter { $0.role.isPassword }
            .map(\.id)
    }

    private func fillWebTextFields(_ params: [WebFieldAutofill]) {
        do {
            let data = try encoder.encode(params)
            guard let jsonString = String(data: data, encoding: .utf8)?.javascriptEscaped() else { return }
            let script = "passwordHelper.setTextFieldValues('\(jsonString)')"
            self.page?.executeJS(script, objectName: JSObjectName, frameInfo: currentOverlay?.frameInfo, successLogCategory: .webAutofillInternal)
            Logger.shared.logDebug("passwordOverlay text fields set.", category: .webAutofillInternal)
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
            self.page?.executeJS(script, objectName: JSObjectName, frameInfo: currentOverlay?.frameInfo, successLogCategory: .webAutofillInternal)
        } catch {
            Logger.shared.logError("JSON encoding failure: \(error.localizedDescription))", category: .general)
        }
    }

    private func showAlert(error: Error) {
        DispatchQueue.main.async {
            self.clearInputFocus()
            if let error = error as? PasswordManager.Error {
                let alert = NSAlert()
                switch error {
                case .databaseError(errorMsg: let message):
                    alert.messageText = "Could not read password from database."
                    alert.informativeText = message
                case .decryptionError(errorMsg: let message):
                    alert.messageText = "Could not decrypt password."
                    alert.informativeText = message
                case .encryptionError(errorMsg: let message):
                    alert.messageText = "Could not encrypt password."
                    alert.informativeText = message
                }
                alert.runModal()
            } else {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }
}

extension WebAutofillController: CreditCardsMenuDelegate {
    func deleteCreditCards(_ entries: [CreditCardEntry]) {
        for entry in entries {
            creditCardManager.markDeleted(entry: entry)
        }
    }

    func fillCreditCard(_ entry: CreditCardEntry) {
        guard let autofillGroup = currentOverlay?.autofillGroup, autofillGroup.action == .payment else {
            Logger.shared.logError("Classifier (payment) mismatch for id \(String(describing: currentOverlay?.elementId))", category: .passwordManager)
            clearInputFocus()
            return
        }
        currentOverlay?.revertMenuToDefault()
        creditCardBuilder.autofill(creditCard: entry)
        Logger.shared.logDebug("Filling fields: \(String(describing: autofillGroup.relatedFields))", category: .webAutofillInternal)
        let backgroundColor = BeamColor.Autocomplete.clickedBackground.hexColor
        let autofill = autofillGroup.relatedFields.compactMap { field -> WebFieldAutofill? in
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
        fillWebTextFields(autofill)
        clearInputFocus()
    }
}
