//
//  BeamWindow.swift
//  Beam
//
//  Created by Sebastien Metrot on 23/09/2020.
//

import Cocoa
import Combine
import SwiftUI
import BeamCore
import AutoUpdate

class BeamHostingView<Content>: NSHostingView<Content> where Content: View {
    required public init(rootView: Content) {
        super.init(rootView: rootView)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        assert(false)
    }

    public override var allowsVibrancy: Bool { false }
}

class BeamWindow: NSWindow, NSDraggingDestination {
    var state: BeamState!
    var data: BeamData

    var versionChecker: VersionChecker

    private var trafficLights: [NSButton?]?
    private var titlebarAccessoryViewHeight = 28
    private var trafficLightLeftMargin: CGFloat = 20

    // This is a hack to prevent a crash with swiftUI being dumb about the initialFirstResponder
    override var initialFirstResponder: NSView? {
        get {
            nil
        }
        set { }
    }

    init(contentRect: NSRect, data: BeamData, reloadState: Bool) {
        self.data = data

        if reloadState && !NSEvent.modifierFlags.contains(.option) && Configuration.env != "test" {
            if let savedData = UserDefaults.standard.data(forKey: Self.savedTabsKey) {
                let decoder = JSONDecoder()
                let state = try? decoder.decode(BeamState.self, from: savedData)
                self.state = state
            }
        }

        if state == nil {
            state = BeamState()
        }

        data.setupJournal()

        if let feed = URL(string: Configuration.updateFeedURL) {
            self.versionChecker = VersionChecker(feedURL: feed, autocheckEnabled: Configuration.autoUpdate)
        } else {
            self.versionChecker = VersionChecker(mockedReleases: AppRelease.mockedReleases(), autocheckEnabled: true)
        }

        super.init(contentRect: contentRect, styleMask: [.titled, .closable, .miniaturizable, .resizable, .unifiedTitleAndToolbar, .fullSizeContentView],
                   backing: .buffered, defer: false)

        self.delegate = self
        self.toolbar?.isVisible = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden

        self.tabbingMode = .disallowed
        setFrameAutosaveName("BeamWindow")

        self.setupUI()
        self.setTitleBarAccessoryView()

        // Create the SwiftUI view and set the context as the value for the managedObjectContext environment keyPath.
        // Add `@Environment(\.managedObjectContext)` in the views that will need the context.
        let mainView = ContentView()
            .environmentObject(state)
            .environmentObject(data)
            .environmentObject(state.browserTabsManager)
            .environmentObject(versionChecker)
            .frame(minWidth: contentRect.width, maxWidth: .infinity, minHeight: contentRect.height, maxHeight: .infinity)

        let hostingView = BeamHostingView(rootView: mainView)
        hostingView.frame = contentRect

        hostingView.translatesAutoresizingMaskIntoConstraints = false

        self.contentView = NSView(frame: contentRect)
        self.contentView?.addSubview(hostingView)
        self.isMovableByWindowBackground = false

        guard let contentView = contentView else { return }

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        registerForDraggedTypes([.fileURL])
    }

    deinit {
        AppDelegate.main.windows.removeAll { window in
            window === self
        }
    }

    override func performClose(_ sender: Any?) {
        if state.mode != .web, state.hasBrowserTabs {
            state.mode = .web
            return
        }
        if state.browserTabsManager.closeCurrentTab() { return }
        super.performClose(sender)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        state.windowIsResizing = true
        super.setFrame(frameRect, display: flag)
        state.windowIsResizing = false
        self.setTrafficLightsLayout()
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        self.setTrafficLightsLayout()
    }

    override func orderFront(_ sender: Any?) {
        super.orderFront(sender)
        self.setTrafficLightsLayout()
    }

    // MARK: - Setup UI

    private func setupUI() {
        trafficLights = [
            standardWindowButton(.closeButton),
            standardWindowButton(.miniaturizeButton),
            standardWindowButton(.zoomButton)
        ]
    }

    private func setTitleBarAccessoryView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 10, height: titlebarAccessoryViewHeight))
        let dummyAccessoryViewController = NSTitlebarAccessoryViewController()

        dummyAccessoryViewController.view = view
        addTitlebarAccessoryViewController(dummyAccessoryViewController)
        self.setTrafficLightsLayout()
    }

    private func setTrafficLightsLayout() {
        guard let trafficLights = trafficLights else { return }

        for (index, trafficLight) in trafficLights.enumerated() {
            let originY = trafficLight!.superview!.frame.height / 2 - trafficLight!.frame.height / 2
            var frame = trafficLight!.frame

            frame.origin.y = Constants.runningOnBigSur ? originY + 2 : originY
            frame.origin.x = trafficLightLeftMargin + CGFloat(index) * (frame.width + 6)

            trafficLight?.frame = frame
        }
    }

    private func toggleTitleBarAccessoryView() {
        guard let titlebarAccessoryView = titlebarAccessoryViewControllers.first else { return }
        titlebarAccessoryView.isHidden.toggle()
        self.state.isFullScreen.toggle()
    }

    // MARK: - IBAction

    @IBAction func newDocument(_ sender: Any?) {
        AppDelegate.main.createWindow(reloadState: false)
    }

    @IBAction func showPreviousTab(_ sender: Any?) {
        state.browserTabsManager.showPreviousTab()
    }

    @IBAction func showNextTab(_ sender: Any?) {
        state.browserTabsManager.showNextTab()
    }

    @IBAction func showJournal(_ sender: Any?) {
        state.navigateToJournal()
    }

    @IBAction func toggleScoreCard(_ sender: Any?) {
        state.data.showTabStats.toggle()
    }

    @IBAction func newSearch(_ sender: Any?) {
        state.startNewSearch()
    }

    @IBAction func openLocation(_ sender: Any?) {
        state.focusOmnibox()
    }

    @IBAction func showCardSelector(_ sender: Any?) {
        state.destinationCardIsFocused = true
    }

    @IBAction func showRecentCard(_ sender: Any?) {
        let recents = state.recentsManager.recentNotes
        if let item = sender as? NSMenuItem, let index = Int(item.title.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()), index <= recents.count {
            state.navigateToNote(named: recents[index - 1].title)
        }
    }

    @IBAction func dumpBrowsingTree(_ sender: Any?) {
        state.browserTabsManager.currentTab?.dumpBrowsingTree()
    }

    static let savedTabsKey = "savedTabs"

    func saveDefaults() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.savedTabsKey)
    }

    // Drag and drop:
    public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.availableType(from: [.fileURL]) != nil {
            return .copy
        } else {
            return NSDragOperation()
        }
    }

    public func draggingExited(_ sender: NSDraggingInfo?) {
    }

    public func draggingEnded(_ sender: NSDraggingInfo) {
    }

    public func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let files = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil)
        else {
            Logger.shared.logError("unable to get files from drag operation", category: .document)
            return false
        }

        for url in files {
            guard let url = url as? URL,
                  let data = try? Data(contentsOf: url)
            else { continue }
            Logger.shared.logInfo("File dropped: \(url) - \(data) - \(data.MD5)")

            do {
                let decoder = JSONDecoder()
                let note = try decoder.decode(BeamNote.self, from: data)
                note.resetIds() // use a new UUID to be sure not to overwrite an existing note
                let titleBase = note.title
                var i = 0
                while DocumentManager().allDocumentsTitles().contains(note.title.lowercased()) {
                    note.title = titleBase + " #\(i)"
                    i += 1
                }

                Logger.shared.logError("Saving imported note '\(note.title)' from \(url)", category: .document)
                note.autoSave(false)

                let alert = NSAlert()
                alert.addButton(withTitle: "OK")
                alert.informativeText = "Note '\(note.title)' was imported succesfully"
                alert.messageText = "Note Imported"
                alert.runModal()
            } catch let error {
                let alert = NSAlert()
                alert.addButton(withTitle: "OK")
                alert.informativeText = "Unable to import '\(url)'"
                alert.messageText = "Note Not Imported"
                alert.runModal()
                Logger.shared.logError("Unable to decode dropped BeamNode '\(url)': \(error)", category: .document)
            }

        }

        return true
    }

}

extension BeamWindow: NSWindowDelegate {

    func windowDidResize(_ notification: Notification) {
        self.setTrafficLightsLayout()
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        self.toggleTitleBarAccessoryView()
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        self.toggleTitleBarAccessoryView()
    }

}

// MARK: Custom Field Editor
protocol CustomWindowFieldEditorProvider {
    func fieldEditor(_ createFlag: Bool) -> NSText?
}

extension BeamWindow {
    override func fieldEditor(_ createFlag: Bool, for object: Any?) -> NSText? {
        if let obj = object as? CustomWindowFieldEditorProvider {
            let editor = obj.fieldEditor(true)
            editor?.isFieldEditor = true
            return editor
        }
        return super.fieldEditor(createFlag, for: object)
    }
}
