import Foundation
import BeamCore
import OAuthSwift
import Combine

/// A file supported for opening.
private struct OpeningFile {
    /// The kind of supported files.
    enum Kind {
        case download
        case note
        case noteCollection
        case other

        static func kind(for url: URL) -> Kind {
            switch url.pathExtension {
            case BeamDownloadDocument.fileExtension: return .download
            case BeamNoteDocumentWrapper.fileExtension: return .note
            case BeamNoteCollectionWrapper.fileExtension: return .noteCollection
            default: return .other
            }
        }
    }

    let kind: Kind
    let url: URL

    var fileWrapper: FileWrapper {
        get throws {
            try FileWrapper(url: url)
        }
    }

    init(url: URL) {
        self.kind = Kind.kind(for: url)
        self.url = url
    }
}

extension AppDelegate {
    func handleOpenFileURL(_ url: URL) -> Bool {
        let file = OpeningFile(url: url)
        switch file.kind {
        case .download:
            do {
                try self.data.downloadManager.downloadFile(from: try BeamDownloadDocument(openingFile: file))
            } catch {
                Logger.shared.logError("Can't open Download Document from disk", category: .downloader)
                return false
            }
        case .note:
            do {
                let doc = try BeamNoteDocumentWrapper(openingFile: file)
                try doc.importNote()
            } catch {
                Logger.shared.logError("Can't import note document \(file.url) from disk", category: .downloader)
                return false
            }
        case .noteCollection:
            do {
                let doc = try BeamNoteCollectionWrapper(openingFile: file)
                try doc.importNotes()
            } catch {
                Logger.shared.logError("Can't import note collection from disk \(file.url)", category: .downloader)
                return false
            }
        case .other:
            return handleURL(file.url)
        }
        return true
    }
}

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
        guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true), components.path != nil else {
            Logger.shared.logDebug("Invalid URL or path missing", category: .general)
            return false
        }
        Logger.shared.logDebug("Processing URL: \(url.absoluteString)", category: .general)

        if components.scheme == "beam" {
            processBeamURL(components: components)
        } else if url.absoluteString.mayBeWebURL || url.absoluteString.mayBeFileURL {
            return processWebURL(components: components)
        } else {
            OAuthSwift.handle(url: url)
            Logger.shared.logDebug("scheme found: \(components.scheme ?? "none")", category: .general)
        }

        return false
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

            if let publicAPIpublishServer = params.first(where: { $0.name == "publicAPIpublishServer" })?.value {
                Logger.shared.logDebug("Found publicAPIpublishServer: \(publicAPIpublishServer)", category: .general)
                Configuration.publicAPIpublishServer = publicAPIpublishServer
            }

            if let publicAPIembed = params.first(where: { $0.name == "publicAPIembed" })?.value {
                Logger.shared.logDebug("Found publicAPIembed: \(publicAPIembed)", category: .general)
                Configuration.publicAPIembed = publicAPIembed
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
            createWindow(frame: nil, restoringTabs: false)
        }

        let canProcessWebURL = components.url != nil

        guard var window = window ?? windows.first else {
            Logger.shared.logDebug("Window not ready to open url. Waiting for it", category: .general)
            waitForWindowToProcessURL(components)
            return canProcessWebURL
        }

        // Open external url when Beam is used as default browser.
        if let url = components.url {
            Logger.shared.logDebug("Opened external URL: \(url.absoluteString)", category: .general)

            if let (existingTab, tabWindow) = existingOpenedTab(for: url) {
                window = tabWindow
                tabWindow.state.browserTabsManager.setCurrentTab(existingTab)
                tabWindow.state.mode = .web
            } else {
                window.state.createTab(withURLRequest: URLRequest(url: url), originalQuery: url.absoluteString)
            }

            NSApp.activate(ignoringOtherApps: true)
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)

            return true
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

    private func existingOpenedTab(for url: URL) -> (BrowserTab, BeamWindow)? {
        for window in windows {
            if let tab = window.state.browserTabsManager.openedTab(for: url) {
                return (tab, window)
            }
        }
        return nil
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

private extension BeamDownloadDocument {
    convenience init(openingFile: OpeningFile) throws {
        try self.init(fileWrapper: try openingFile.fileWrapper)
        self.fileURL = openingFile.url
    }
}

private extension BeamNoteDocumentWrapper {
    convenience init(openingFile: OpeningFile) throws {
        try self.init(fileWrapper: try openingFile.fileWrapper)
        self.fileURL = openingFile.url
    }
}

private extension BeamNoteCollectionWrapper {
    convenience init(openingFile: OpeningFile) throws {
        try self.init(fileWrapper: try openingFile.fileWrapper)
        self.fileURL = openingFile.url
    }
}
