import Foundation
import BeamCore
import OAuthSwift
import Combine

extension AppDelegate {
    @objc func handleURLEvent(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {

            Logger.shared.logDebug("Could not parse \(String(describing: event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue)) \(reply)", category: .general)
            return
        }
        handleURL(url)
    }

    /// - Returns: `true` if it was handled by the app
    @discardableResult
    func handleURL(_ url: URL) -> Bool {

        guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true) else {
            Logger.shared.logDebug("Invalid URL or path missing", category: .general)
            return false
        }
        Logger.shared.logDebug("Processing URL: \(url.absoluteString)", category: .general)

        let scheme = components.scheme
        var handled = false
        if scheme == "beam" {
            processBeamURL(components: components)
        } else if url.absoluteString.mayBeWebURL || url.absoluteString.mayBeFileURL {
            handled = processWebURL(components: components)
        } else {
            OAuthSwift.handle(url: url)
            if let scheme = scheme {
                Logger.shared.logDebug("scheme found: \(scheme)", category: .general)
            }
        }
        return handled
    }

    private func processBeamURL(components: NSURLComponents) {
        Logger.shared.logDebug("processBeamURL components: \(components)", category: .general)

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
        case "callback":
            if let url = components.url {
                OAuthSwift.handle(url: url)
                return
            }
        default: break
        }

        Logger.shared.logInfo("Didn't detect link \(urlPath), urlPath first: \(urlPath.dropFirst())", category: .general)
    }

    /// - Returns: `true` if it was handled by the app
    @discardableResult
    func processWebURL(components: NSURLComponents) -> Bool {
        if windows.isEmpty && isActive {
            createWindow(frame: nil)
        }

        guard let window = window ?? windows.first else {
            Logger.shared.logDebug("Window not ready to open url. Waiting for it", category: .general)
            waitForWindowToProcessURL(components)
            return false
        }
        guard components.path != nil else {
            Logger.shared.logDebug("Invalid URL or path missing", category: .general)
            return false
        }

        // Open external url when Beam is used as default browser.
        if components.host != Configuration.publicHostname {
            guard let url = components.url else { return false }
            Logger.shared.logDebug("Opened external URL: \(url.absoluteString)", category: .general)
            NSApp.activate(ignoringOtherApps: true)
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)

            _ = window.state.createTab(withURL: url, originalQuery: url.absoluteString)
            return true
        }

        guard components.host == Configuration.publicHostname else {
            Logger.shared.logDebug("components: \(components), host is different from Configuration: \(Configuration.publicHostname)", category: .general)
            return false
        }

//        switch urlPath.dropFirst() {
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
//        default: break
//        }

        Logger.shared.logInfo("Didn't detect link \(components)", category: .general)

        return false
    }

    private func waitForWindowToProcessURL(_ components: NSURLComponents) {
        var cancellable: AnyCancellable?
        cancellable = NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard self?.window != nil else { return }
                self?.processWebURL(components: components)
                cancellable?.cancel()
            }
    }
}
