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

class BeamWindow: NSWindow, NSDraggingDestination, Codable, WindowInfoCapable {
    enum Error: Swift.Error {
        case missingAccount(UUID)
    }

    let account: BeamAccount
    let state: BeamState

    var data: BeamData {
        account.data
    }

    var windowInfo: BeamWindowInfo = BeamWindowInfo()

    static let composedWindowMargin: CGFloat = 3.0
    static let middleSeparatorWidth: CGFloat = 3.0

    private var isComposed: Bool {
        state.sideNote != nil
    }

    private var hostingView: NSView?
    private var hostingViewConstraints: [NSLayoutConstraint] = []

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
    private(set) var touchBarController: TouchBarController?

    init(contentRect: NSRect, account: BeamAccount, state: BeamState? = nil, title: String? = nil, isIncognito: Bool = false, minimumSize: CGSize? = nil) {
        self.account = account
        self.state = state ?? BeamState(incognito: isIncognito)

        super.init(contentRect: contentRect, styleMask: [.titled, .closable, .miniaturizable, .resizable, .unifiedTitleAndToolbar, .fullSizeContentView],
                   backing: .buffered, defer: false)

        try? data.setupJournal(firstSetup: true)

        windowInfo.window = self

        self.delegate = self
        self.toolbar?.isVisible = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isReleasedWhenClosed = false

        self.tabbingMode = .disallowed

        setFrameAutosaveName("BeamWindow")

        // If we are restoring, we need to fix the frame again after setting the autosave name.
        if state != nil {
            setFrame(frameRect(forContentRect: contentRect), display: false)
        }

        self.setupWindowButtons()
        self.setTitleBarAccessoryView()

        let minimumSize = minimumSize ?? contentRect.size
        // Create the SwiftUI view and set the context as the value for the managedObjectContext environment keyPath.
        // Add `@Environment(\.managedObjectContext)` in the views that will need the context.
        let mainView = ContentView()
            .environmentObject(self.state)
            .environmentObject(data)
            .environmentObject(windowInfo)
            .environmentObject(self.state.browserTabsManager)
            .environment(\.showHelpAction, HelpAction({ [weak self] in self?.showHelpAndFeedbackMenuView() }))
            .frame(minWidth: minimumSize.width, maxWidth: .infinity, minHeight: minimumSize.height, maxHeight: .infinity)

        let hostingView = BeamHostingView(rootView: mainView)
        hostingView.frame = contentRect
        hostingView.layer?.cornerRadius = 8
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true

        hostingView.translatesAutoresizingMaskIntoConstraints = false

        self.hostingView = hostingView

        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .hudWindow
        contentView = visualEffect

        let mercuryView = BeamWindowBackgroundView()

        self.contentView?.addSubviewWithConstraintsOnEachSide(subView: mercuryView)
        self.contentView?.addSubview(hostingView)

        self.isMovableByWindowBackground = false

        setHostingViewConstraints()

        registerForDraggedTypes([.fileURL])

        // Adding the window item to the app's windowsMenu with prefilled title if any
        NSApp.addWindowsItem(self, title: title ?? "Beam", filename: false)
    }

    func setHostingViewConstraints() {
        guard let contentView = contentView, let hostingView = hostingView else { return }

        let neededMargin = isComposed ? Self.composedWindowMargin : 0

        if hostingViewConstraints.isEmpty {
            hostingViewConstraints = [hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: neededMargin),
                                      hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -neededMargin),
                                      hostingView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: neededMargin),
                                      hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -neededMargin)
            ]
            NSLayoutConstraint.activate(hostingViewConstraints)
        } else {
            for c in hostingViewConstraints {
                let isBottomOrTrailing = c.secondAnchor == contentView.bottomAnchor || c.secondAnchor == contentView.trailingAnchor
                c.constant = isBottomOrTrailing ? -neededMargin : neededMargin
            }

            NSAnimationContext.runAnimationGroup({context in
                context.duration = 0.3
                context.allowsImplicitAnimation = true
                contentView.layoutSubtreeIfNeeded()
            }, completionHandler:nil)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case contentRect
        case state
        case account
    }

    convenience required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let contentRect = try container.decode(NSRect.self, forKey: .contentRect)
        let state = try container.decode(BeamState.self, forKey: .state)
        let accountID = try container.decodeIfPresent(UUID.self, forKey: .account)

        let account = accountID.flatMap({ AppData.shared.account(for: $0) }) ?? AppData.shared.currentAccount

        guard let account = account else {
            throw Error.missingAccount(accountID ?? UUID.null)
        }

        self.init(contentRect: contentRect,
                  account: account,
                  state: state,
                  minimumSize: AppDelegate.defaultWindowMinimumSize)
    }

    func encode(to encoder: Encoder) throws {
        let contentRect = contentRect(forFrameRect: frame)

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contentRect, forKey: .contentRect)
        try container.encode(state, forKey: .state)
        try container.encode(account.id, forKey: .account)
    }

    func showHelpAndFeedbackMenuView() {
        let window = CustomPopoverPresenter.shared.presentPopoverChildWindow(useBeamShadow: true)

        let view = HelpAndFeedbackMenuView(window: window)
            .environmentObject(state)

        var origin = NSPoint(x: BeamSpacing._100, y: frame.size.height - (WindowBottomToolBar.height-6))

        if let parentWindow = window?.parent {
            origin = origin.flippedPointToBottomLeftOrigin(in: parentWindow)
        }

        window?.setView(with: view, at: origin)
        window?.isMovable = false
        window?.makeKey()
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

    private func cleanUpWindowContentBeforeClosing() {
        self.hostingView = nil
        self.contentView = nil
        self.initialFirstResponder = nil

        if !AppDelegate.main.terminating {
            // preparation for saving session
            for tab in state.browserTabsManager.tabs {
                tab.tabWillClose()
            }
        }

        let idToRemove = state.browserTabsManager.browserTabManagerId
        let updatedOpenTrees = data.clusteringManager.openBrowsing.allOpenBrowsingTrees.filter { $0.browserTabManagerId != idToRemove }
        data.clusteringManager.openBrowsing.allOpenBrowsingTrees = updatedOpenTrees

        // Closing the window so removing its associated window item
        NSApp.removeWindowsItem(self)
    }

    override func close() {
        cleanUpWindowContentBeforeClosing()

        // Store session if the user is closing the last window.
        if !AppDelegate.main.terminating, AppDelegate.main.windows.count == 1 {
            AppDelegate.main.storeAllWindowsFromCurrentSession()
        }

        // closing all tabs for good, session saving info should have been saved thanks to cleanup
        state.closeAllTabs()

        AppDelegate.main.windows.removeAll { $0 === self }

        AppDelegate.main.panels.forEach { (_, panel) in
            if panel.state === state {
                panel.close()
            }
        }

        // For some obscure reason, SwiftUI will cause a temporary leak of our BeamWindow if
        // we don't do this.
        state.cachedJournalStackView = nil
        state.cachedJournalScrollView = nil

        super.close()
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

    override func makeTouchBar() -> NSTouchBar? {
        if touchBarController == nil { touchBarController = .init(window: self) }
        return touchBarController?.makeTouchBar()
    }

    // MARK: - Animations
    /// This methods creates a CALayer and animates it from the mouse current position to the position of the downloadButton of the window
    /// It should be trigerred when a file download starts
    func downloadAnimation() {
        guard let buttonPosition = state.downloadButtonPosition?.flippedPointToBottomLeftOrigin(in: self) else { return }
        let size = CGSize(width: 64, height: 64)
        let animationLayer = CALayer()
        animationLayer.frame = CGRect(origin: CGPoint(x: 50, y: 50), size: size)
        animationLayer.position = self.mouseLocationOutsideOfEventStream
        animationLayer.zPosition = .greatestFiniteMagnitude

        let flyingImage = NSImage(named: "download-file_glyph")
        animationLayer.contents = flyingImage?.cgImage(forProposedRect: CGRect(origin: .zero, size: size))

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
        guard let collection = BeamData.shared.currentDocumentCollection else { return false }
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
                while (try? collection.fetchTitles(filters: []))?.contains(note.title.lowercased()) == true {
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

    /// Return the minimum possible width for the window, taking into account the split view
    /// - Returns: The minimum possible width
    func minimumWidth() -> CGFloat {
        let sideNoteOffset = state.sideNote == nil ? 0 : state.sideNoteWidth
        return AppDelegate.minimumSize(for: self).width + sideNoteOffset
    }

    /// Returns the computed/estimated width for the contentView
    /// If a sideNote is displayed, the UI looks like this
    /// [composedWindowMargin(3)][contentView][middleSeparator(3)][sideNote][composedWindowMargin(3)]
    var estimatedContentViewWidth: CGFloat {
        if state.sideNote != nil {
            let margin = 2 * Self.composedWindowMargin - Self.middleSeparatorWidth
            return windowInfo.windowFrame.width - state.sideNoteWidth - margin
        }
        return windowInfo.windowFrame.size.width
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

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        if frameSize.width < minimumWidth() {
            return CGSize(width: minimumWidth(), height: frameSize.height)
        } else {
            return frameSize
        }
    }

    func windowDidResize(_ notification: Notification) {
        self.setTrafficLightsLayout()
        self.windowInfo.windowFrame = self.frame

        if let childWindows = childWindows, windowInfo.windowIsResizing {
            for panel in childWindows where panel is MiniEditorPanel {
                let position = MiniEditorPanel.dockedPanelOrigin(from: self.frame)
                let width = MiniEditorPanel.panelWidth(for: self)
                let rect = CGRect(origin: position, size: CGSize(width: width, height: self.frame.height))
                panel.setFrame(rect, display: false, animate: false)
            }
        }
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

class BeamWindowBackgroundView: NSView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureAppearance()
    }

    init() {
        super.init(frame: .zero)
        configureAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureAppearance() {
        self.wantsLayer = true
        self.layer?.opacity = 0.8
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            self.layer?.backgroundColor = BeamColor.Mercury.cgColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            self.layer?.backgroundColor = BeamColor.Mercury.cgColor
        }
    }
}
