import Foundation
import BeamCore

enum PasswordMessages: String, CaseIterable {
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

    init(page: BeamWebViewConfiguration) {
        super.init(config: page, messages: PasswordMessages.self, jsFileName: "PasswordManager")
    }

    override func onMessage(messageName: String, messageBody: Any?, from webPage: WebPage) {
        let passwordOverlayController = webPage.passwordOverlayController
        switch messageName {

        case PasswordMessages.password_textInputFields.rawValue:
            guard let jsonString = messageBody as? String else {
                Logger.shared.logError("Ignoring message as body is not a String", category: .web)
                return
            }
            passwordOverlayController.updateInputFields(with: jsonString)

        case PasswordMessages.password_textInputFocusIn.rawValue:
            guard let elementId = messageBody as? String else {
                Logger.shared.logError("Ignoring message as body is not a String", category: .web)
                return
            }
            passwordOverlayController.updateInputFocus(for: elementId, becomingActive: true)

        case PasswordMessages.password_textInputFocusOut.rawValue:
            guard let elementId = messageBody as? String else {
                Logger.shared.logError("Ignoring message as body is not a String", category: .web)
                return
            }
            passwordOverlayController.updateInputFocus(for: elementId, becomingActive: false)

        case PasswordMessages.password_formSubmit.rawValue:
            passwordOverlayController.handleWebFormSubmit()

        case PasswordMessages.password_scroll.rawValue:
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

        case PasswordMessages.password_resize.rawValue:
            let passwordBody = messageBody as? [String: AnyObject]
            guard let dict = passwordBody,
                  let width = dict["width"] as? CGFloat,
                  let height = dict["height"] as? CGFloat
                    else {
                Logger.shared.logError("Password controller ignored resize: \(String(describing: messageBody))", category: .web)
                return
            }
            passwordOverlayController.updateViewSize(width: width, height: height)

        default:
            break
        }
    }
}
