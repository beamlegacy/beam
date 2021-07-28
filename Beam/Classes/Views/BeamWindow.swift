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

    private var trafficLights: [NSButton?]?
    private var titlebarAccessoryViewHeight = 28
    private var trafficLightLeftMargin: CGFloat = 20

    // This is a hack to prevent a crash with swiftUI being dumb about the initialFirstResponder
    override var initialFirstResponder: NSView? {
        get { nil }
        set { _ = newValue }
    }

    // swiftlint:disable:next function_body_length
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
        self.isReleasedWhenClosed = false

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

    override func performClose(_ sender: Any?) {
        if state.mode != .web, state.hasBrowserTabs {
            state.mode = .web
            return
        }
        if state.browserTabsManager.closeCurrentTab() { return }
        super.performClose(sender)
    }

    override func close() {
        // TODO: Add a proper way to clean the entire window state
        // https://linear.app/beamapp/issue/BE-1152/
        AppDelegate.main.windows.removeAll { window in
            window === self
        }
        super.close()
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

    // MARK: - Animations
    /// This methods creates a CALayer and animates it from the mouse current position to the position of the downloadButton of the window
    /// It should be trigerred when a file download starts
    func downloadAnimation() {

        guard let buttonPosition = state.downloadButtonPosition else { return }
        let animationLayer = CALayer()
        animationLayer.frame = CGRect(origin: CGPoint(x: 50, y: 50), size: CGSize(width: 64, height: 64))
        animationLayer.position = self.mouseLocationOutsideOfEventStream
        animationLayer.zPosition = .greatestFiniteMagnitude

        let flyingImage = NSImage(named: "flying-download")
        animationLayer.contents = flyingImage?.cgImage

        self.contentView?.layer?.addSublayer(animationLayer)

        let animationGroup = BeamDownloadManager.flyingAnimationGroup(origin: animationLayer.position, destination: buttonPosition)
        animationGroup.delegate = LayerRemoverAnimationDelegate(with: animationLayer)

        animationLayer.add(animationGroup, forKey: "download")
        animationLayer.opacity = 0.0
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

    deinit {
        contentView = nil
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
