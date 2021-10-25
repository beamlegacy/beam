//
//  PointAndShoot+Alert.swift
//  Beam
//
//  Created by Stef Kors on 27/08/2021.
//

import Foundation
import BeamCore

extension PointAndShoot {
    /// Triggers an alert modal to report collect failing
    /// - Parameters:
    ///   - group: ShootGroup to be collected
    ///   - elements: Array of collected BeamElements
    ///   - message: optional message to provide additional information
    func showAlert(_ group: ShootGroup, _ elements: [BeamElement], _ message: String = "") {
        // Set the message as the NSAlert text
        let message = """
        # Unsupported html found

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

        // Set the message as the NSAlert text
        let alert = NSAlert()
        alert.messageText = "Collect failed"
        alert.informativeText = "Please copy this bug report and share it on Linear"
        // Add an input NSTextField for the prompt
        let inputFrame = NSRect(
            x: 0,
            y: 0,
            width: 400,
            height: 300
        )

        let textField = NSTextField(frame: inputFrame)
        textField.stringValue = message
        textField.isEditable = true
        alert.accessoryView = textField
        // Store the message on the clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(message, forType: .string)

        // Add a confirmation button
        alert.addButton(withTitle: "OK")
        // and cancel button
        alert.addButton(withTitle: "Cancel")

        // Display the NSAlert
        alert.runModal()
    }
}
