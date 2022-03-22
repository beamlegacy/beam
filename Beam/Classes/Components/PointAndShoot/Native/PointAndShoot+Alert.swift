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
        guard PreferencesManager.showsCollectFeedbackAlert else {
            self.sendFeedback(group, elements, message)
            completion()
            return
        }
        // Set the message as the NSAlert text
        let alert = NSAlert()
        alert.messageText = "Ooops..."
        alert.informativeText = "Beam failed to capture this item. \n To help us do better next time, please send us a bug report."
        alert.showsSuppressionButton = true
        alert.suppressionButton?.state = .on
        // Store the message on the clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(message, forType: .string)

        // Add a confirmation button
        let saveButton = alert.addButton(withTitle: "Send Bug Report")
        // and cancel button
        let cancelButton = alert.addButton(withTitle: "Don't Send")
        saveButton.tag = NSApplication.ModalResponse.OK.rawValue
        cancelButton.tag = NSApplication.ModalResponse.cancel.rawValue

        guard let window = page?.webviewWindow else {
            completion()
            return
        }

        // Display the NSAlert
        alert.beginSheetModal(for: window) { response in
            if let suppressionButton = alert.suppressionButton, suppressionButton.state == .on {
                // When suppression is enabled hide alert
                PreferencesManager.showsCollectFeedbackAlert = false
            } else {
                PreferencesManager.showsCollectFeedbackAlert = true
            }

            if response == .OK {
                // When .OK user consents to sending feedback.
                self.sendFeedback(group, elements, message)
                PreferencesManager.isCollectFeedbackEnabled = true
            } else {
                // else don't send feedback
                PreferencesManager.isCollectFeedbackEnabled = false
            }

            completion()
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

    func sendFeedback(_ group: ShootGroup, _ elements: [BeamElement], _ message: String = "") {
        guard Configuration.env != .test else { return }
        guard PreferencesManager.isCollectFeedbackEnabled else { return }
        var host = group.href
        if let url = URL(string: group.href), let urlHost = url.minimizedHost {
            host = urlHost
        }

        let title = "Point and Shoot failed on: \(host)"
        let report = self.generateReport(group, elements, message)
        let eventId = SentrySDK.capture(message: title + report)
        let userFeedback = UserFeedback(eventId: eventId)
        userFeedback.comments = "no comments submitted..."
        userFeedback.email = "john.doe@example.com"
        userFeedback.name = "John Doe"
        SentrySDK.capture(userFeedback: userFeedback)
    }
}
