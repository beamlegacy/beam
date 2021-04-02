import Foundation
import BeamCore

extension AppDelegate {
    @objc func handleURL(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let path = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: path) else {

            Logger.shared.logDebug("Could not parse \(String(describing: event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue)) \(reply)", category: .general)
            return
        }

        // Process the URL.
        guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true) else {
            Logger.shared.logDebug("Invalid URL or path missing", category: .general)
            return
        }

        switch components.scheme {
        case "http", "https":
            parseHTTPScheme(components: components)
        case "beam":
            parseBeamScheme(components: components)
        case .none:
            break
        case .some(let scheme):
            Logger.shared.logDebug("scheme found: \(scheme)", category: .general)
        }
    }

    private func parseBeamScheme(components: NSURLComponents) {
        Logger.shared.logDebug("parseBeamScheme components: \(components)", category: .general)

        // Process the URL.
        guard let urlPath = components.path else {
            Logger.shared.logDebug("Invalid URL or path missing", category: .general)
            return
        }

        switch urlPath.dropFirst() {
        case "configuration":
            guard let params = components.queryItems else { break }

            if let apiHostname = params.first(where: { $0.name == "apiHostname" })?.value {
                Logger.shared.logDebug("Found apiHostname: \(apiHostname)", category: .general)
                Configuration.apiHostname = apiHostname
            }

            if let publicHostname = params.first(where: { $0.name == "publicHostname" })?.value {
                Logger.shared.logDebug("Found publicHostname: \(publicHostname)", category: .general)
                Configuration.publicHostname = publicHostname
            }

            return
        default: break
        }

        Logger.shared.logInfo("Didn't detect link \(urlPath), urlPath first: \(urlPath.dropFirst())", category: .general)
    }

    @discardableResult
    func parseHTTPScheme(components: NSURLComponents) -> Bool {
        // Process the URL.
        guard let urlPath = components.path else {
            Logger.shared.logDebug("Invalid URL or path missing", category: .general)
            return false
        }

        // Open external url when Beam is used as default browser.
        if components.host != Configuration.publicHostname {
            guard let url = components.url else { return false }
            window.state.createTab(withURL: url, originalQuery: url.absoluteString)
            return false
        }

        guard components.host == Configuration.publicHostname else {
            Logger.shared.logDebug("components: \(components), host is different from Configuration: \(Configuration.publicHostname)", category: .general)
            return false
        }

        switch urlPath.dropFirst() {
//        case "note":
//            if let params = components.queryItems {
//                if let noteId = params.first(where: { $0.name == "id" })?.value {
////                    showNoteID(id: noteId)
//                    return true
//                } else if let noteTitle = params.first(where: { $0.name == "title" })?.value {
////                    showNoteTitle(title: noteTitle)
//                    return true
//                }
//            }
        default: break
        }

        Logger.shared.logInfo("Didn't detect link \(components)", category: .general)

        return false
    }
}
