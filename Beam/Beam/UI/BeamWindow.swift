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

class BeamWindow: NSWindow, NSWindowDelegate {
    var state: BeamState!
    var data: BeamData

    // This is a hack to prevent a crash with swiftUI being dumb about the initialFirstResponder
    override var initialFirstResponder: NSView? {
        get {
            nil
        }

        set {
        }
    }

    init(contentRect: NSRect, data: BeamData) {
        self.data = data
        self.state = BeamState(data: data)
        self.state.data.setupJournal()
        super.init(contentRect: contentRect, styleMask: [.titled, .closable, .miniaturizable, .resizable, .unifiedTitleAndToolbar, .fullSizeContentView],
                   backing: .buffered, defer: false)

        self.delegate = self
        self.toolbar?.isVisible = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden

        self.tabbingMode = .disallowed
        setFrameAutosaveName("BeamWindow")

        // Create the SwiftUI view and set the context as the value for the managedObjectContext environment keyPath.
        // Add `@Environment(\.managedObjectContext)` in the views that will need the context.
        let contentView = ContentView().environmentObject(state)
        self.contentView = BeamHostingView(rootView: contentView)
        self.isMovableByWindowBackground = false
    }

    deinit {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }
        delegate.windows.removeAll { window in
            window === self
        }
    }

    // THIS HACK IS HORRIBLE But AppKit leaves us little choice to have a similar look on Catalina and Future OSes
    var trafficLightFrame = NSRect()
    func setupTrafficLights() {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let runningOnBigSur = version.majorVersion >= 11 || (version.majorVersion == 10 && version.minorVersion >= 16)

        if let b = self.standardWindowButton(.closeButton) {
            if var f = b.superview?.superview?.frame {
                let v = CGFloat(runningOnBigSur ? 12 : 14)
                f.size.height += v
                f.origin.x += 13
                f.origin.y -= v
                trafficLightFrame = f
                b.superview?.superview?.frame = trafficLightFrame
            }
        }
    }

    func updateTrafficLights() {
        if let b = self.standardWindowButton(.closeButton) {
            b.superview?.superview?.frame = trafficLightFrame
        }
    }

    public func windowDidResize(_ notification: Notification) {
        setupTrafficLights()
    }

    public func windowDidMove(_ notification: Notification) {
        updateTrafficLights()
    }

    public func windowDidMiniaturize(_ notification: Notification) {
        updateTrafficLights()
    }

    public func windowDidDeminiaturize(_ notification: Notification) {
        updateTrafficLights()
    }

    public func windowDidUpdate(_ notification: Notification) {
//        updateTrafficLights()
    }

    public func windowDidChangeScreen(_ notification: Notification) {
        updateTrafficLights()
    }

    public func windowDidChangeScreenProfile(_ notification: Notification) {
        updateTrafficLights()
    }

    public func windowDidChangeBackingProperties(_ notification: Notification) {
        updateTrafficLights()
    }

    public func windowDidEnterFullScreen(_ notification: Notification) {
        updateTrafficLights()
    }

//    public func windowDidExitFullScreen(_ notification: Notification) {
//        updateTrafficLights()
//    }
//
    public func windowWillExitFullScreen(_ notification: Notification) {
        updateTrafficLights()
    }

    public func windowDidChangeOcclusionState(_ notification: Notification) {
        updateTrafficLights()
    }

    public func windowDidExpose(_ notification: Notification) {
        updateTrafficLights()
    }

    public func windowDidBecomeKey(_ notification: Notification) {
        updateTrafficLights()
    }

    public func windowDidResignKey(_ notification: Notification) {
        updateTrafficLights()
    }

    public func windowDidBecomeMain(_ notification: Notification) {
        updateTrafficLights()
    }

    public func windowDidResignMain(_ notification: Notification) {
        updateTrafficLights()
    }

    @IBAction func newDocument(_ sender: Any?) {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }
        delegate.createWindow()
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

    @IBAction func newSearch(_ sender: Any?) {
        state.startNewSearch()
    }

    override func performClose(_ sender: Any?) {
        if state.closeCurrentTab() {
            return
        }
        super.performClose(sender)
    }
}
