//
//  PointAndShoot+Alert.swift
//  Beam
//
//  Created by Stef Kors on 27/08/2021.
//

import Foundation
import BeamCore
import Sentry

extension PointAndShoot {
    /// Triggers an alert modal to report collect failing
    /// - Parameters:
    ///   - group: ShootGroup to be collected
    ///   - elements: Array of collected BeamElements
    ///   - message: optional message to provide additional information
    func showAlert(_ group: ShootGroup, _ elements: [BeamElement], _ message: String = "", completion: @escaping () -> Void) {
        if UserDefaults.standard.bool(forKey: "PNS_AlertSuppression") {
            completion()
        } else {
            // Set the message as the NSAlert text
            let alert = NSAlert()
            alert.messageText = "Collect failed"
            alert.informativeText = "We don't support collecting the content you targeted. If you would like us to support this content please send us a bug report"
            // Add an input NSTextField for the prompt
            let inputFrame = NSRect(
                x: 0,
                y: 0,
                width: 400,
                height: 70
            )

            let textField = NSTextField(frame: inputFrame)
            textField.placeholderString = "E.g. When I tried to collect the top left Beam Logo it failed."
            // textField.stringValue = message
            textField.isEditable = true
            alert.accessoryView = textField
            alert.showsSuppressionButton = true
            // Store the message on the clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(message, forType: .string)

            // Add a confirmation button
            let saveButton = alert.addButton(withTitle: "Send bug report")
            // and cancel button
            let cancelButton = alert.addButton(withTitle: "Not Now")
            saveButton.tag = NSApplication.ModalResponse.OK.rawValue
            cancelButton.tag = NSApplication.ModalResponse.cancel.rawValue

            guard let window = page?.webviewWindow else {
                return
            }

            var host = group.href
            if let url = URL(string: group.href), let urlHost = url.minimizedHost {
                host = urlHost
            }

            // Display the NSAlert
            alert.beginSheetModal(for: window) { response in
                if let suppressionButton = alert.suppressionButton, suppressionButton.state == .on {
                    UserDefaults.standard.set(true, forKey: "PNS_AlertSuppression")
                }

                if response == .OK {
                    let report = self.generateReport(group, elements, message)
                    if Configuration.env != .test {
                        self.sendFeedback(title: "Point and Shoot failed on: \(host)", report: report, comments: textField.stringValue)
                    } else {
                        Logger.shared.logDebug("Skipping sending PNS sentry report: \(report)", category: .pointAndShoot)
                    }
                }
                completion()
            }
        }
    }

    func generateReport(_ group: ShootGroup, _ elements: [BeamElement], _ message: String = "") -> String {
        return """

        ## ShootGroup
         - href: \(group.href)
         - noteInfo: \(group.noteInfo)
         - numberOfElements: \(group.numberOfElements)

        ## HTML
        ```Html
        \(group.html())
        ```

        ## [BeamElement]
        \(elements.count) elements collected
        ```Swift
        \(elements)
        ```

        ## Additional Information
        \(message)
        """
    }

    func sendFeedback(title: String, report: String, comments: String) {
        let eventId = SentrySDK.capture(message: title + report)
        let userFeedback = UserFeedback(eventId: eventId)
        userFeedback.comments = comments.isEmpty ? "no comments submitted..." : comments
        userFeedback.email = "john.doe@example.com"
        userFeedback.name = "John Doe"
        SentrySDK.capture(userFeedback: userFeedback)
    }
}
