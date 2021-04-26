//
//  BeamWindow.swift
//  Beam
//
//  Created by Sebastien Metrot on 23/09/2020.
//

import Cocoa
import Combine
import SwiftUI

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

class BeamWindow: NSWindow {
    var state: BeamState!
    var data: BeamData

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
    }

    deinit {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }
        delegate.windows.removeAll { window in
            window === self
        }
    }

    override func performClose(_ sender: Any?) {
        if state.mode != .web, !state.tabs.isEmpty {
            state.mode = .web
            return
        }
        if state.closeCurrentTab() { return }
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
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }
        delegate.createWindow(reloadState: false)
    }

    @IBAction func showPreviousTab(_ sender: Any?) {
        state.showPreviousTab()
    }

    @IBAction func showNextTab(_ sender: Any?) {
        state.showNextTab()
    }

    @IBAction func showJournal(_ sender: Any?) {
        state.startNewSearch()
    }

    @IBAction func toggleScoreCard(_ sender: Any?) {
        state.data.showTabStats.toggle()
    }

    @IBAction func newSearch(_ sender: Any?) {
        state.startNewSearch()
    }

    @IBAction func openLocation(_ sender: Any?) {
        state.focusOmniBox = true
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
        state.currentTab?.dumpBrowsingTree()
    }

    static let savedTabsKey = "savedTabs"

    func saveDefaults() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.savedTabsKey)
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
