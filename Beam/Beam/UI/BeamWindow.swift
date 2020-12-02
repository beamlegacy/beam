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
    private var trafficLightLeftMargin: CGFloat = 20
    private var _titleBarHeight: CGFloat = 38 // magic number from debugger view

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

        self.setupUI()
        // self.setTrafficLightsLayout()
    }

    deinit {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }
        delegate.windows.removeAll { window in
            window === self
        }
    }

    override func performClose(_ sender: Any?) {
        if state.closeCurrentTab() {
            return
        }
        super.performClose(sender)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
      super.setFrame(frameRect, display: flag)
      // self.setTrafficLightsLayout()
    }

    override func restoreState(with coder: NSCoder) {
      super.restoreState(with: coder)
      // self.setTrafficLightsLayout()
    }

    override func orderFront(_ sender: Any?) {
      super.orderFront(sender)
      // self.setTrafficLightsLayout()
    }

    // MARK: - Setup UI

    private func setupUI() {
        let contentView = self.contentView!

        trafficLights = [
            standardWindowButton(.closeButton),
            standardWindowButton(.miniaturizeButton),
            standardWindowButton(.zoomButton)
        ]

        trafficLights!.forEach { (trafficLight) in
            trafficLight!.superview?.willRemoveSubview(trafficLight!)
            trafficLight!.removeFromSuperview()

            trafficLight!.viewWillMove(toSuperview: contentView)
            contentView.addSubview(trafficLight!)
            trafficLight!.viewDidMoveToSuperview()
        }

        contentView.superview!.viewDidEndLiveResize()
    }

    private func defaultTitleBarHeight() -> CGFloat {
      let contentRect = NSWindow.contentRect(forFrameRect: frame, styleMask: .titled)
        return frame.height - contentRect.height
    }

    private func setTrafficLightsLayout() {
        guard let trafficLights = trafficLights else { return }

        for (index, trafficLight) in trafficLights.enumerated() {
            var frame = trafficLight!.frame
            frame.origin.y = trafficLight!.superview!.frame.height / 2 - trafficLight!.frame.height / 2
            frame.origin.x = trafficLightLeftMargin + CGFloat(index) * (frame.width + 6)

            trafficLight?.frame = frame
        }
    }

    // MARK: - IBAction

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
}

extension BeamWindow: NSWindowDelegate {

    func windowDidResize(_ notification: Notification) {
        // self.setTrafficLightsLayout()
    }

}
