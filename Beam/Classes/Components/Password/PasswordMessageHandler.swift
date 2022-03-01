import Foundation
import BeamCore

enum PasswordMessages: String, CaseIterable {
    case PasswordManager_loaded
    case PasswordManager_textInputFields
    case PasswordManager_textInputFocusIn
    case PasswordManager_textInputFocusOut
    case PasswordManager_formSubmit
    case PasswordManager_resize
}

/**
 Handles password messages sent from web page's javascript.
 */
class PasswordMessageHandler: SimpleBeamMessageHandler {

    init() {
        let messages = PasswordMessages.self.allCases.map { $0.rawValue }
        super.init(messages: messages, jsFileName: "PasswordManager_prod")
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage, frameInfo: WKFrameInfo?) {
        guard let messageKey = PasswordMessages(rawValue: messageName) else {
            Logger.shared.logError("Unsupported message \(messageName) for password message handler", category: .web)
            return
        }
        guard let passwordOverlayController = webPage.passwordOverlayController else { return }
        switch messageKey {

        case .PasswordManager_loaded:
            Logger.shared.logDebug("JavaScript loaded for frame \(messageBody as? String ?? "<no url>")", category: .passwordManagerInternal)
            passwordOverlayController.requestInputFields(frameInfo: frameInfo)

        case .PasswordManager_textInputFields:
            guard let dict = messageBody as? [String: Any],
                let jsonString = dict["textFieldsString"] as? String else {
                Logger.shared.logError("Ignoring message as body is not a String", category: .web)
                return
            }
            passwordOverlayController.updateInputFields(with: jsonString, frameInfo: frameInfo)

        case .PasswordManager_textInputFocusIn:
            guard let dict = messageBody as? [String: Any],
                  let elementId = dict["id"] as? String
            else {
                Logger.shared.logError("Ignoring focus event: \(String(describing: messageBody))", category: .web)
                return
            }
            let text = dict["text"] as? String
            passwordOverlayController.inputFieldDidGainFocus(elementId, frameInfo: frameInfo, contents: text)

        case .PasswordManager_textInputFocusOut:
            guard let dict = messageBody as? [String: Any],
                  let elementId = dict["id"] as? String else {
                Logger.shared.logError("Ignoring message as body is not a String", category: .web)
                return
            }
            passwordOverlayController.inputFieldDidLoseFocus(elementId, frameInfo: frameInfo)

        case .PasswordManager_formSubmit:
            guard let dict = messageBody as? [String: Any],
                  let elementId = dict["id"] as? String else {
                Logger.shared.logError("Ignoring message as body is not a String", category: .web)
                return
            }
            passwordOverlayController.handleWebFormSubmit(with: elementId, frameInfo: frameInfo)

        case .PasswordManager_resize:
            let passwordBody = messageBody as? [String: Any]
            guard let dict = passwordBody,
                  let width = dict["width"] as? CGFloat,
                  let height = dict["height"] as? CGFloat
                    else {
                Logger.shared.logError("Password controller ignored resize: \(String(describing: messageBody))", category: .web)
                return
            }
            passwordOverlayController.updateViewSize(width: width, height: height)
        }
    }
}
