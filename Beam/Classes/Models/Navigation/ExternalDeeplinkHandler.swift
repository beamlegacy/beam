//
//  ExternalDeeplinkHandler.swift
//  Beam
//
//  Created by Florian Mari on 18/10/2021.
//

import Foundation

class ExternalDeeplinkHandler {
    static let internalSchemes: Set<String> = {
        let schemes: Set<String> = ["http", "https", "file", "blob", "about", "beam"]
        return schemes.union(NavigationRouter.customSchemes)
    }()

    /// We remember the choice for the current session only. Until we have actual user preferences.
    private static var allowedApplications = Set<String>()

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
            if Self.allowedApplications.contains(applicationName) {
                return true
            }
        } else {
            return false
        }

        let alert = NSAlert()
        alert.messageText = "Do you want to allow this page to open \(deeplinkName)?"
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            if let applicationName = applicationName {
                Self.allowedApplications.insert(applicationName)
            }
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
