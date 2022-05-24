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

class BeamWindow: NSWindow, NSDraggingDestination {
    var state: BeamState
    var windowInfo: BeamWindowInfo = BeamWindowInfo()
    var data: BeamData

    override var title: String {
        didSet {
            // Changing the title reset the standard window buttons
            // https://linear.app/beamapp/issue/BE-4106/window-controls-change-their-position-when-going-to-the-web
            self.setTrafficLightsLayout()
        }
    }

    // This is a hack to prevent a crash with swiftUI being dumb about the initialFirstResponder
    override var initialFirstResponder: NSView? {
        get { nil }
        set { _ = newValue }
    }

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        guard state.shouldAllowFirstResponderTakeOver(responder) else {
            return false
        }
        return super.makeFirstResponder(responder)
    }

    private var trafficLights: [NSButton?]?
    private var trafficLightLeftMargin: CGFloat = 20

    // swiftlint:disable:next function_body_length
    init(contentRect: NSRect, data: BeamData, title: String? = nil, isIncognito: Bool = false, minimumSize: CGSize? = nil) {
        self.data = data
        state = BeamState(incognito: isIncognito)

        data.setupJournal(firstSetup: true)

        super.init(contentRect: contentRect, styleMask: [.titled, .closable, .miniaturizable, .resizable, .unifiedTitleAndToolbar, .fullSizeContentView],
                   backing: .buffered, defer: false)

        self.delegate = self
        self.toolbar?.isVisible = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isReleasedWhenClosed = false

        self.tabbingMode = .disallowed
        setFrameAutosaveName("BeamWindow")

        self.setupWindowButtons()
        self.setTitleBarAccessoryView()

        let minimumSize = minimumSize ?? contentRect.size
        // Create the SwiftUI view and set the context as the value for the managedObjectContext environment keyPath.
        // Add `@Environment(\.managedObjectContext)` in the views that will need the context.
        let mainView = ContentView()
            .environmentObject(state)
            .environmentObject(data)
            .environmentObject(windowInfo)
            .environmentObject(state.browserTabsManager)
            .frame(minWidth: minimumSize.width, maxWidth: .infinity, minHeight: minimumSize.height, maxHeight: .infinity)

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

        // Adding the window item to the app's windowsMenu with prefilled title if any
        NSApp.addWindowsItem(self, title: title ?? "Beam", filename: false)
    }

    // This is an imperfect way to try making the sidebar more simple to display and dismiss using a two finger swipe
    override func scrollWheel(with event: NSEvent) {
        guard state.useSidebar else {
            super.scrollWheel(with: event)
            return
        }
        if event.deltaX > 3 {
            state.showSidebar = true
        } else if event.deltaX < -3 {
            state.showSidebar = false
        }
    }

    deinit {
        state.cachedJournalScrollView = nil
        state.cachedJournalStackView = nil
    }

    override func performClose(_ sender: Any?) {
        if state.mode != .web && state.hasUnpinnedBrowserTabs {
            state.mode = .web
            return
        }
        if state.mode == .web {
            let currentTab = state.browserTabsManager.currentTab
            _ = state.closeCurrentTab()
            if currentTab == state.browserTabsManager.currentTab { // currentTab might be the last unclosable tab (unpinned tab)
                state.mode = .today
            }
            return
        }
        super.performClose(sender)
    }

    @IBAction func performHardClose(_ sender: Any?) {
        for window in AppDelegate.main.windows where window === self {
            window.close()
        }
    }

    override func close() {
        // TODO: Add a proper way to clean the entire window state
        // https://linear.app/beamapp/issue/BE-1152/
        AppDelegate.main.windows.removeAll { window in
            if window === self {
                window.contentView = nil
                let idToRemove = window.state.browserTabsManager.browserTabManagerId
                window.data.clusteringManager.openBrowsing.allOpenBrowsingTrees = window.data.clusteringManager.openBrowsing.allOpenBrowsingTrees.filter { $0.browserTabManagerId != idToRemove }
            }
            return window === self
        }

        super.close()

        // Closing the window so removing its associated window item
        NSApp.removeWindowsItem(self)
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        self.setTrafficLightsLayout()
    }

    override func orderFront(_ sender: Any?) {
        super.orderFront(sender)
        self.setTrafficLightsLayout()
    }

    private var _isMovable = true
    override var isMovable: Bool {
        get {
            if let currentEvent = NSApp.currentEvent, currentEvent.type == .leftMouseDown, !allowsWindowDragging(with: currentEvent) {
                return false
            }
            return _isMovable
        }
        set {
            _isMovable = newValue
        }
    }

    // MARK: - Animations
    /// This methods creates a CALayer and animates it from the mouse current position to the position of the downloadButton of the window
    /// It should be trigerred when a file download starts
    func downloadAnimation() {

        guard let buttonPosition = state.downloadButtonPosition?.flippedPointToBottomLeftOrigin(in: self) else { return }
        let animationLayer = CALayer()
        animationLayer.frame = CGRect(origin: CGPoint(x: 50, y: 50), size: CGSize(width: 64, height: 64))
        animationLayer.position = self.mouseLocationOutsideOfEventStream
        animationLayer.zPosition = .greatestFiniteMagnitude

        let flyingImage = NSImage(named: "download-file_glyph")
        animationLayer.contents = flyingImage?.cgImage

        self.contentView?.layer?.addSublayer(animationLayer)

        let animationGroup = BeamDownloadManager.flyingAnimationGroup(origin: animationLayer.position, destination: buttonPosition)
        animationGroup.delegate = LayerRemoverAnimationDelegate(with: animationLayer)

        animationLayer.add(animationGroup, forKey: "download")
        animationLayer.opacity = 0.0
    }

    // Drag and drop:
    public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.availableType(from: [.fileURL]) != nil {
            return .copy
        } else {
            return NSDragOperation()
        }
    }

    public func draggingExited(_ sender: NSDraggingInfo?) { }

    public func draggingEnded(_ sender: NSDraggingInfo) { }

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
                let decoder = BeamJSONDecoder()
                let note = try decoder.decode(BeamNote.self, from: data)
                note.resetIds() // use a new UUID to be sure not to overwrite an existing note
                let titleBase = note.title
                var i = 0
                let documentManager = DocumentManager()
                while documentManager.allDocumentsTitles(includeDeletedNotes: false).contains(note.title.lowercased()) {
                    note.title = titleBase + " #\(i)"
                    i += 1
                }

                Logger.shared.logError("Saving imported note '\(note.title)' from \(url)", category: .document)
                note.autoSave()

                UserAlert.showMessage(message: "Note Imported",
                                      informativeText: "Note '\(note.title)' was imported succesfully")
            } catch let error {
                UserAlert.showError(message: "Note Not Imported", informativeText: "Unable to import '\(url)'")
                Logger.shared.logError("Unable to decode dropped BeamNode '\(url)': \(error)", category: .document)
            }

        }
        return true
    }
}

extension BeamWindow: NSWindowDelegate {

    private func highestWindowParent(for window: NSWindow?) -> NSWindow? {
        var parent = window?.parent
        while parent?.parent != nil {
            parent = parent?.parent
        }
        return parent
    }

    func windowDidResignMain(_ notification: Notification) {
        windowInfo.windowIsMain = highestWindowParent(for: NSApp.mainWindow) == self
    }

    func windowDidBecomeMain(_ notification: Notification) {
        guard !state.isShowingOnboarding else {
            data.onboardingManager.presentOnboardingWindow()
            resignFirstResponder()
            resignMain()
            return
        }
        windowInfo.windowIsMain = true
        for window in AppDelegate.main.windows where window != self {
            window.windowInfo.windowIsMain = false
        }
        guard state.mode == .web else { return }
        state.browserTabsManager.currentTab?.tabDidAppear(withState: state)
    }

    func windowDidMove(_ notification: Notification) {
        self.windowInfo.windowFrame = self.frame
    }

    func windowWillStartLiveResize(_ notification: Notification) {
        self.windowInfo.windowIsResizing = true
        self.setTrafficLightsLayout()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        self.windowInfo.windowIsResizing = false
        self.setTrafficLightsLayout()
    }

    func windowDidResize(_ notification: Notification) {
        self.setTrafficLightsLayout()
        self.windowInfo.windowFrame = self.frame
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        self.toggleTitleBarAccessoryView()
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        self.toggleTitleBarAccessoryView()
    }

    func windowWillMiniaturize(_ notification: Notification) {
        state.browserTabsManager.currentTab?.switchToBackground()
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        if isMainWindow { state.browserTabsManager.currentTab?.tabDidAppear(withState: state) }
    }
}

// MARK: - Custom Field Editor
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

// MARK: - Title Bar
class TitleBarViewControllerWithMouseDown: NSTitlebarAccessoryViewController {

    override func mouseDown(with event: NSEvent) {
        if (self.view.window as? BeamWindow)?.allowsWindowDragging(with: event) != false {
            super.mouseDown(with: event)
        }
        // NSTitlebarAccessoryViewController steal mouseDown events
        // But we need them for the view placed below the title bar
        // See touch down state of toolbar buttons
        self.parent?.mouseDown(with: event)
    }
}

extension BeamWindow {
    fileprivate func allowsWindowDragging(with event: NSEvent) -> Bool {
        if state.mode == .web && state.omniboxInfo.isFocused && state.omniboxInfo.wasFocusedFromTab, let searchField = self.firstResponder as? BeamTextFieldViewFieldEditor {
            let omniboxFrame = omniboxFrameFromSearchField(searchField)
            return !omniboxFrame.contains(event.locationInWindow)
        } else if state.mode == .web && !windowInfo.undraggableWindowRects.isEmpty &&
                    windowInfo.undraggableWindowRects.contains(where: {
                        $0.contains(event.locationInWindow.flippedPointToTopLeftOrigin(in: self))
                    }) {
            return false
        }
        return true
    }

    private func omniboxFrameFromSearchField(_ searchField: BeamTextFieldViewFieldEditor) -> CGRect {
        let minHeight = Omnibox.defaultHeight
        var frame = searchField.frame
        frame = frame.insetBy(dx: 0, dy: (frame.height - minHeight) / 2)
        return searchField.convert(frame, to: nil)
    }

    static var windowControlsWidth: CGFloat { 72.0 }

    private func setupWindowButtons() {
        trafficLights = [
            standardWindowButton(.closeButton),
            standardWindowButton(.miniaturizeButton),
            standardWindowButton(.zoomButton)
        ]
    }

    private func setTitleBarAccessoryView() {
        let dummyAccessoryViewController = TitleBarViewControllerWithMouseDown()
        dummyAccessoryViewController.view = NSView()
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
}
