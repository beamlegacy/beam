import Foundation
import BeamCore

enum PasswordMessages: String, CaseIterable {
    case password_loaded
    case password_textInputFields
    case password_textInputFocusIn
    case password_textInputFocusOut
    case password_formSubmit
    case password_scroll
    case password_resize
}

/**
 Handles password messages sent from web page's javascript.
 */
class PasswordMessageHandler: BeamMessageHandler<PasswordMessages> {

    init(config: BeamWebViewConfiguration) {
        super.init(config: config, messages: PasswordMessages.self, jsFileName: "PasswordManager")
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage, frameInfo: WKFrameInfo?) {
        guard let messageKey = PasswordMessages(rawValue: messageName) else {
            Logger.shared.logError("Unsupported message \(messageName) for password message handler", category: .web)
            return
        }
        guard let passwordOverlayController = webPage.passwordOverlayController else { return }
        switch messageKey {

        case .password_loaded:
            Logger.shared.logDebug("JavaScript loaded for frame \(messageBody as? String ?? "<no url>")", category: .passwordManagerInternal)
            passwordOverlayController.requestInputFields(frameInfo: frameInfo)

        case .password_textInputFields:
            guard let jsonString = messageBody as? String else {
                Logger.shared.logError("Ignoring message as body is not a String", category: .web)
                return
            }
            passwordOverlayController.updateInputFields(with: jsonString, frameInfo: frameInfo)

        case .password_textInputFocusIn:
            guard let dict = messageBody as? [String: AnyObject],
                  let elementId = dict["id"] as? String
            else {
                Logger.shared.logError("Ignoring focus event: \(String(describing: messageBody))", category: .web)
                return
            }
            let text = dict["text"] as? String
            passwordOverlayController.inputFieldDidGainFocus(elementId, frameInfo: frameInfo, contents: text)

        case .password_textInputFocusOut:
            guard let elementId = messageBody as? String else {
                Logger.shared.logError("Ignoring message as body is not a String", category: .web)
                return
            }
            passwordOverlayController.inputFieldDidLoseFocus(elementId, frameInfo: frameInfo)

        case .password_formSubmit:
            guard let elementId = messageBody as? String else {
                Logger.shared.logError("Ignoring message as body is not a String", category: .web)
                return
            }
            passwordOverlayController.handleWebFormSubmit(with: elementId, frameInfo: frameInfo)

        case .password_scroll:
            let passwordBody = messageBody as? [String: AnyObject]
            guard let dict = passwordBody,
                  let x = dict["x"] as? CGFloat,
                  let y = dict["y"] as? CGFloat,
                  let width = dict["width"] as? CGFloat,
                  let height = dict["height"] as? CGFloat
                    else {
                Logger.shared.logError("Ignored scroll event: \(String(describing: messageBody))", category: .web)
                return
            }
            passwordOverlayController.updateScrollPosition(x: x, y: y, width: width, height: height)
            Logger.shared.logDebug("Password controller handled scroll: \(x), \(y)", category: .web)

        case .password_resize:
            let passwordBody = messageBody as? [String: AnyObject]
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
