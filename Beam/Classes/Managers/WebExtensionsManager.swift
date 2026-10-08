//
//  WebExtensionsManager.swift
//  Beam
//

import Foundation
import Combine
import WebKit
import BeamCore

/// An extension installed by the user, persisted in the user defaults.
struct WebExtensionRecord: Codable, Identifiable, Equatable {
    enum Source: String, Codable {
        /// Safari web extension embedded in an installed app (e.g. Dashlane, Bitwarden).
        case appExtension
        /// Unpacked extension directory or zip archive, copied into Beam's storage.
        case resources
    }

    var id: String
    var source: Source
    var path: String
    var isEnabled = true
    var allowsPrivateBrowsing = false
}

/// Hosts WebKit web extensions (macOS 15.4+) and bridges Beam's windows and tabs to them.
@available(macOS 15.4, *)
@MainActor
final class WebExtensionsManager: NSObject, ObservableObject {
    static let shared = WebExtensionsManager()

    struct InstalledExtension: Identifiable {
        var record: WebExtensionRecord
        var context: WKWebExtensionContext?
        var loadError: Swift.Error?

        var id: String { record.id }
        @MainActor var displayName: String {
            context?.webExtension.displayName ?? URL(fileURLWithPath: record.path).deletingPathExtension().lastPathComponent
        }
    }

    /// A Safari web extension found in an installed app, which can be added to Beam.
    struct AvailableAppExtension: Identifiable, Hashable {
        var path: String
        var name: String
        var id: String { path }
    }

    enum Error: LocalizedError {
        case extensionNotFound
        case cancelled
        case alreadyInstalled

        var errorDescription: String? {
            switch self {
            case .extensionNotFound: return "The extension could not be found."
            case .cancelled: return "The installation was cancelled."
            case .alreadyInstalled: return "This extension is already installed."
            }
        }
    }

    let controller: WKWebExtensionController
    @Published private(set) var installedExtensions: [InstalledExtension] = []
    /// Incremented whenever an extension action (icon, badge, label, enabled state) changes.
    @Published private(set) var actionsRevision = 0

    /// View the next action popup should be anchored to, set by the toolbar button before performing the action.
    weak var popupAnchorView: NSView?

    private static let recordsDefaultsKey = "WebExtensions.installed"
    private var didLoadInstalledExtensions = false
    private var tabObservers: [ObjectIdentifier: [AnyCancellable]] = [:]

    private override init() {
        controller = WKWebExtensionController(configuration: .default())
        super.init()
        controller.delegate = self
    }

    var loadedContexts: [WKWebExtensionContext] {
        installedExtensions.compactMap { $0.context }
    }

    // MARK: - Persistence

    private var storedRecords: [WebExtensionRecord] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.recordsDefaultsKey),
                  let records = try? JSONDecoder().decode([WebExtensionRecord].self, from: data) else { return [] }
            return records
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: Self.recordsDefaultsKey)
        }
    }

    private func saveRecords() {
        storedRecords = installedExtensions.map(\.record)
    }

    private static var storageDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WebExtensions", isDirectory: true)
    }

    // MARK: - Loading

    func loadInstalledExtensions() {
        guard !didLoadInstalledExtensions else { return }
        didLoadInstalledExtensions = true
        installedExtensions = storedRecords.map { InstalledExtension(record: $0) }
        for record in storedRecords where record.isEnabled {
            Task { await load(record) }
        }
    }

    private func makeWebExtension(source: WebExtensionRecord.Source, path: String) async throws -> WKWebExtension {
        let url = URL(fileURLWithPath: path)
        switch source {
        case .appExtension:
            guard let bundle = Bundle(url: url) else { throw Error.extensionNotFound }
            return try await WKWebExtension(appExtensionBundle: bundle)
        case .resources:
            guard FileManager.default.fileExists(atPath: path) else { throw Error.extensionNotFound }
            return try await WKWebExtension(resourceBaseURL: url)
        }
    }

    private func load(_ record: WebExtensionRecord) async {
        do {
            let webExtension = try await makeWebExtension(source: record.source, path: record.path)
            let context = WKWebExtensionContext(for: webExtension)
            // Stable identifiers keep the extension storage and origin across launches.
            context.uniqueIdentifier = record.id
            if let baseURL = URL(string: "webkit-extension://\(record.id.lowercased())/") {
                context.baseURL = baseURL
            }
            context.hasAccessToPrivateData = record.allowsPrivateBrowsing
            #if DEBUG
            context.isInspectable = true
            #endif
            // The user approved the requested permissions when installing the extension.
            for permission in webExtension.requestedPermissions {
                context.setPermissionStatus(.grantedExplicitly, for: permission)
            }
            for matchPattern in webExtension.allRequestedMatchPatterns {
                context.setPermissionStatus(.grantedExplicitly, for: matchPattern)
            }
            try controller.load(context)
            updateInstalledExtension(record.id) {
                $0.context = context
                $0.loadError = nil
            }
            webExtension.errors.forEach {
                Logger.shared.logWarning("Web extension \(webExtension.displayName ?? record.id): \($0.localizedDescription)", category: .web)
            }
        } catch {
            Logger.shared.logError("Failed to load web extension at \(record.path): \(error.localizedDescription)", category: .web)
            updateInstalledExtension(record.id) {
                $0.context = nil
                $0.loadError = error
            }
        }
    }

    private func unload(_ id: String) {
        guard let context = installedExtensions.first(where: { $0.id == id })?.context else { return }
        try? controller.unload(context)
        updateInstalledExtension(id) { $0.context = nil }
    }

    private func updateInstalledExtension(_ id: String, _ update: (inout InstalledExtension) -> Void) {
        guard let index = installedExtensions.firstIndex(where: { $0.id == id }) else { return }
        update(&installedExtensions[index])
    }

    // MARK: - Installation

    /// Safari web extensions embedded in apps installed in /Applications.
    func availableAppExtensions() -> [AvailableAppExtension] {
        let fileManager = FileManager.default
        let installedPaths = Set(installedExtensions.map(\.record.path))
        var apps = (try? fileManager.contentsOfDirectory(at: URL(fileURLWithPath: "/Applications"), includingPropertiesForKeys: nil)) ?? []
        apps += apps.filter { $0.pathExtension != "app" }.flatMap {
            (try? fileManager.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)) ?? []
        }
        var result: [AvailableAppExtension] = []
        for app in apps where app.pathExtension == "app" {
            let plugIns = app.appendingPathComponent("Contents/PlugIns", isDirectory: true)
            let appExtensions = (try? fileManager.contentsOfDirectory(at: plugIns, includingPropertiesForKeys: nil)) ?? []
            for appExtension in appExtensions where appExtension.pathExtension == "appex" {
                guard !installedPaths.contains(appExtension.path),
                      let info = Bundle(url: appExtension)?.infoDictionary,
                      (info["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String == "com.apple.Safari.web-extension"
                else { continue }
                let appName = app.deletingPathExtension().lastPathComponent
                result.append(AvailableAppExtension(path: appExtension.path, name: appName))
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func installAppExtension(at path: String) async throws {
        try await install(source: .appExtension, path: path)
    }

    /// Installs an unpacked extension directory or a zip archive, which is copied into Beam's storage.
    func installExtensionResources(at url: URL) async throws {
        let webExtension = try await makeWebExtension(source: .resources, path: url.path)
        guard confirmInstallation(of: webExtension) else { throw Error.cancelled }

        let id = UUID().uuidString
        let destination = Self.storageDirectory.appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent(url.lastPathComponent)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: url, to: destination)
        await add(WebExtensionRecord(id: id, source: .resources, path: destination.path))
    }

    private func install(source: WebExtensionRecord.Source, path: String) async throws {
        guard !installedExtensions.contains(where: { $0.record.path == path }) else { throw Error.alreadyInstalled }
        let webExtension = try await makeWebExtension(source: source, path: path)
        guard confirmInstallation(of: webExtension) else { throw Error.cancelled }
        await add(WebExtensionRecord(id: UUID().uuidString, source: source, path: path))
    }

    private func add(_ record: WebExtensionRecord) async {
        installedExtensions.append(InstalledExtension(record: record))
        saveRecords()
        await load(record)
    }

    func uninstall(_ id: String) async {
        guard let installed = installedExtensions.first(where: { $0.id == id }) else { return }
        if let context = installed.context {
            let dataTypes = WKWebExtensionController.allExtensionDataTypes
            if let dataRecord = await controller.dataRecord(ofTypes: dataTypes, for: context) {
                await controller.removeData(ofTypes: dataTypes, from: [dataRecord])
            }
            try? controller.unload(context)
        }
        if installed.record.source == .resources {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: installed.record.path).deletingLastPathComponent())
        }
        installedExtensions.removeAll { $0.id == id }
        saveRecords()
    }

    func setEnabled(_ enabled: Bool, for id: String) {
        guard let record = installedExtensions.first(where: { $0.id == id })?.record, record.isEnabled != enabled else { return }
        updateInstalledExtension(id) { $0.record.isEnabled = enabled }
        saveRecords()
        if enabled {
            Task { await load(record) }
        } else {
            unload(id)
        }
    }

    func setAllowsPrivateBrowsing(_ allowed: Bool, for id: String) {
        updateInstalledExtension(id) {
            $0.record.allowsPrivateBrowsing = allowed
            $0.context?.hasAccessToPrivateData = allowed
        }
        saveRecords()
    }

    func openOptionsPage(for id: String) {
        guard let url = installedExtensions.first(where: { $0.id == id })?.context?.optionsPageURL else { return }
        openTab(with: url, in: nil, active: true)
    }

    private func confirmInstallation(of webExtension: WKWebExtension) -> Bool {
        let name = webExtension.displayName ?? "this extension"
        let alert = NSAlert()
        alert.messageText = "Add “\(name)” to Beam?"
        var details: [String] = []
        let patterns = webExtension.allRequestedMatchPatterns
        if patterns.contains(where: { $0.matchesAllHosts || $0.matchesAllURLs }) {
            details.append("It will be able to read and change data on all websites.")
        } else if !patterns.isEmpty {
            let hosts = Set(patterns.compactMap(\.host)).sorted().prefix(8).joined(separator: ", ")
            details.append("It will be able to read and change data on: \(hosts).")
        }
        let permissions = webExtension.requestedPermissions.map(\.rawValue).sorted()
        if !permissions.isEmpty {
            details.append("Permissions: \(permissions.joined(separator: ", ")).")
        }
        alert.informativeText = details.joined(separator: "\n\n")
        alert.icon = webExtension.icon(for: CGSize(width: 64, height: 64))
        alert.addButton(withTitle: "Add Extension")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: - Tabs and windows events

    /// Runs `block` on the main actor, synchronously when already on the main thread.
    nonisolated static func performOnMain(_ block: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated(block)
        } else {
            DispatchQueue.main.async { MainActor.assumeIsolated(block) }
        }
    }

    func tabsDidChange(from oldTabs: [BrowserTab], to newTabs: [BrowserTab]) {
        let oldIds = Set(oldTabs.map(ObjectIdentifier.init))
        let newIds = Set(newTabs.map(ObjectIdentifier.init))
        for tab in oldTabs where !newIds.contains(ObjectIdentifier(tab)) {
            tabObservers[ObjectIdentifier(tab)] = nil
            controller.didCloseTab(tab, windowIsClosing: false)
        }
        for tab in newTabs where !oldIds.contains(ObjectIdentifier(tab)) {
            observe(tab)
            controller.didOpenTab(tab)
        }
    }

    func currentTabDidChange(from previousTab: BrowserTab?, to tab: BrowserTab?) {
        guard let tab = tab, previousTab !== tab else { return }
        controller.didActivateTab(tab, previousActiveTab: previousTab)
    }

    func windowsDidChange(from oldWindows: [BeamWindow], to newWindows: [BeamWindow]) {
        for window in oldWindows where !newWindows.contains(where: { $0 === window }) {
            controller.didCloseWindow(window)
        }
        for window in newWindows where !oldWindows.contains(where: { $0 === window }) {
            controller.didOpenWindow(window)
        }
    }

    func windowDidBecomeMain(_ window: BeamWindow) {
        controller.didFocusWindow(window)
    }

    private func observe(_ tab: BrowserTab) {
        func notify<P: Publisher>(_ publisher: P, _ properties: WKWebExtension.TabChangedProperties) -> AnyCancellable where P.Failure == Never {
            // @Published emits before the value is stored, so report the change on the next run loop iteration.
            publisher.dropFirst().receive(on: RunLoop.main).sink { [weak self, weak tab] _ in
                MainActor.assumeIsolated {
                    guard let self = self, let tab = tab else { return }
                    self.controller.didChangeTabProperties(properties, for: tab)
                }
            }
        }
        tabObservers[ObjectIdentifier(tab)] = [
            notify(tab.$title, .title),
            notify(tab.$url, .URL),
            notify(tab.$isLoading, .loading),
            notify(tab.$isPinned, .pinned),
            notify(tab.$mediaPlayerController.map { $0?.isMuted }.removeDuplicates(), .muted),
            notify(tab.$mediaPlayerController.map { $0?.isPlaying }.removeDuplicates(), [.playingAudio])
        ]
    }

    // MARK: - Helpers

    @discardableResult
    func openTab(with url: URL?, in window: BeamWindow?, active: Bool) -> BrowserTab? {
        guard let window = window ?? AppDelegate.main.window ?? AppDelegate.main.windows.first ?? AppDelegate.main.createWindow(frame: nil) else { return nil }
        let state = window.state
        let tab: BrowserTab
        if let url = url {
            tab = state.createTab(withURLRequest: URLRequest(url: url), setCurrent: active)
        } else {
            tab = state.addNewTab(origin: nil, setCurrent: active)
        }
        if active {
            state.mode = .web
            window.makeKeyAndOrderFront(nil)
        }
        return tab
    }

    fileprivate func windows(for context: WKWebExtensionContext) -> [BeamWindow] {
        let ordered = NSApp.orderedWindows.compactMap { $0 as? BeamWindow }
        let windows = ordered + AppDelegate.main.windows.filter { window in !ordered.contains { $0 === window } }
        return windows.filter { !$0.state.isIncognito || context.hasAccessToPrivateData }
    }
}

// MARK: - WKWebExtensionControllerDelegate

@available(macOS 15.4, *)
extension WebExtensionsManager: WKWebExtensionControllerDelegate {

    func webExtensionController(_ controller: WKWebExtensionController, openWindowsFor extensionContext: WKWebExtensionContext) -> [any WKWebExtensionWindow] {
        windows(for: extensionContext)
    }

    func webExtensionController(_ controller: WKWebExtensionController, focusedWindowFor extensionContext: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        guard let window = AppDelegate.main.window else { return nil }
        return windows(for: extensionContext).contains { $0 === window } ? window : nil
    }

    func webExtensionController(_ controller: WKWebExtensionController, openNewTabUsing configuration: WKWebExtension.TabConfiguration,
                                for extensionContext: WKWebExtensionContext,
                                completionHandler: @escaping ((any WKWebExtensionTab)?, (any Swift.Error)?) -> Void) {
        let tab = openTab(with: configuration.url, in: configuration.window as? BeamWindow, active: configuration.shouldBeActive)
        if let tab = tab, configuration.shouldBePinned {
            tab.state?.browserTabsManager.pinTab(tab)
        }
        completionHandler(tab, nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, openNewWindowUsing configuration: WKWebExtension.WindowConfiguration,
                                for extensionContext: WKWebExtensionContext,
                                completionHandler: @escaping ((any WKWebExtensionWindow)?, (any Swift.Error)?) -> Void) {
        let frame = configuration.frame
        let hasFrame = !frame.isNull && !frame.isEmpty && frame.origin.x.isFinite && frame.origin.y.isFinite
        guard let window = AppDelegate.main.createWindow(frame: hasFrame ? frame : nil, isIncognito: configuration.shouldBePrivate,
                                                         becomeMain: configuration.shouldBeFocused) else {
            completionHandler(nil, nil)
            return
        }
        for url in configuration.tabURLs {
            openTab(with: url, in: window, active: true)
        }
        for case let tab as BrowserTab in configuration.tabs {
            tab.state?.browserTabsManager.removeTab(tabId: tab.id)
            window.state.browserTabsManager.addNewTabAndNeighborhood(tab, setCurrent: true)
        }
        if !configuration.tabURLs.isEmpty || !configuration.tabs.isEmpty {
            window.state.mode = .web
        }
        completionHandler(window, nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, openOptionsPageFor extensionContext: WKWebExtensionContext,
                                completionHandler: @escaping ((any Swift.Error)?) -> Void) {
        guard let url = extensionContext.optionsPageURL else {
            completionHandler(Error.extensionNotFound)
            return
        }
        openTab(with: url, in: nil, active: true)
        completionHandler(nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissions permissions: Set<WKWebExtension.Permission>,
                                in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext,
                                completionHandler: @escaping (Set<WKWebExtension.Permission>, Date?) -> Void) {
        let list = permissions.map(\.rawValue).sorted().joined(separator: ", ")
        let allowed = askPermission(for: extensionContext, details: "It is requesting these additional permissions: \(list).")
        completionHandler(allowed ? permissions : [], nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionToAccess urls: Set<URL>,
                                in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext,
                                completionHandler: @escaping (Set<URL>, Date?) -> Void) {
        let hosts = Set(urls.compactMap(\.host)).sorted().joined(separator: ", ")
        let allowed = askPermission(for: extensionContext, details: "It wants to read and change data on: \(hosts).")
        completionHandler(allowed ? urls : [], nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, promptForPermissionMatchPatterns matchPatterns: Set<WKWebExtension.MatchPattern>,
                                in tab: (any WKWebExtensionTab)?, for extensionContext: WKWebExtensionContext,
                                completionHandler: @escaping (Set<WKWebExtension.MatchPattern>, Date?) -> Void) {
        let description = matchPatterns.contains { $0.matchesAllHosts || $0.matchesAllURLs }
            ? "all websites"
            : matchPatterns.map(\.string).sorted().joined(separator: ", ")
        let allowed = askPermission(for: extensionContext, details: "It wants to read and change data on \(description).")
        completionHandler(allowed ? matchPatterns : [], nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, didUpdate action: WKWebExtension.Action,
                                forExtensionContext context: WKWebExtensionContext) {
        actionsRevision += 1
    }

    func webExtensionController(_ controller: WKWebExtensionController, presentActionPopup action: WKWebExtension.Action,
                                for context: WKWebExtensionContext, completionHandler: @escaping ((any Swift.Error)?) -> Void) {
        guard let popover = action.popupPopover else {
            completionHandler(Error.extensionNotFound)
            return
        }
        let anchor = popupAnchorView?.window != nil ? popupAnchorView : nil
        if let anchor = anchor {
            popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: anchor.isFlipped ? .maxY : .minY)
        } else if let contentView = AppDelegate.main.window?.contentView {
            // Opened programmatically (e.g. browser.action.openPopup()): anchor below the top right corner of the window.
            let rect = NSRect(x: contentView.bounds.maxX - 60, y: contentView.isFlipped ? 0 : contentView.bounds.maxY - Toolbar.height,
                              width: 1, height: Toolbar.height)
            popover.show(relativeTo: rect, of: contentView, preferredEdge: contentView.isFlipped ? .maxY : .minY)
        } else {
            completionHandler(Error.extensionNotFound)
            return
        }
        completionHandler(nil)
    }

    func webExtensionController(_ controller: WKWebExtensionController, sendMessage message: Any, toApplicationWithIdentifier applicationIdentifier: String?,
                                for extensionContext: WKWebExtensionContext, replyHandler: @escaping (Any?, (any Swift.Error)?) -> Void) {
        // Native messaging goes to the extension's containing app in Safari; Beam has no bridge to it.
        replyHandler(nil, NSError(domain: "co.beamapp.WebExtensions", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Native messaging is not supported in Beam."]))
    }

    private func askPermission(for context: WKWebExtensionContext, details: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Allow “\(context.webExtension.displayName ?? "this extension")”?"
        alert.informativeText = details
        alert.icon = context.webExtension.icon(for: CGSize(width: 64, height: 64))
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Don’t Allow")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
