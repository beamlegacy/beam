//
//  ExternalDeeplinkHandler.swift
//  Beam
//
//  Created by Florian Mari on 18/10/2021.
//

import Foundation

class ExternalDeeplinkHandler {
    static let internalSchemes: Set<String> = ["http", "https", "file", "blob", "about", "beam"]

    let request: URLRequest

    init(request: URLRequest) {
        self.request = request
    }

    func isDeeplink() -> Bool {
        guard let scheme = request.url?.scheme?.lowercased() else {
            return false
        }

        guard !Self.internalSchemes.contains(scheme) else {
            return false
        }
        return true
    }

    func shouldOpenDeeplink() -> Bool {
        guard let requestUrl = request.url else { return false }

        if !shouldPresentAlert() {
            return true
        }

        var deeplinkName = requestUrl.scheme?.capitalized ?? "an external application"

        let applicationName = NSWorkspace.shared.urlForApplication(toOpen: requestUrl)?.lastPathComponent
        if let applicationName = applicationName {
            deeplinkName = (applicationName as NSString).deletingPathExtension
        } else {
            return false
        }

        let alert = NSAlert()
        alert.messageText = "Do you want to allow this page to open \(deeplinkName) ?"
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            return true
        }
        return false
    }

    private func shouldPresentAlert() -> Bool {
        guard let requestUrl = request.url else { return false }

        switch requestUrl.scheme {
        case "mailto":
            return false
        default:
            return true
        }
    }
}
