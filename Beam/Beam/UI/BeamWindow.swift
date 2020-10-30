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

    public func windowDidResize(_ notification: Notification) {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let runningOnBigSur = version.majorVersion >= 11 || (version.majorVersion == 10 && version.minorVersion >= 16)

        // THIS HACK IS HORRIBLE But AppKit leaves us little choice to have a similar look on Catalina and Future OSes
        if let b = self.standardWindowButton(.closeButton) {
            if var f = b.superview?.superview?.frame {
                let v = CGFloat(runningOnBigSur ? 12 : 14)
                f.size.height += v
                f.origin.x += 13
                f.origin.y -= v
                b.superview?.superview?.frame = f
            }
        }
    }

    @IBAction func newDocument(_ sender: Any?) {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }
        delegate.createWindow()
    }

    @IBAction func showPreviousTab(_ sender: Any?) {
        if let i = state.tabs.firstIndex(of: state.currentTab) {
            let i = i - 1 < 0 ? state.tabs.count - 1 : i - 1
            state.currentTab = state.tabs[i]
        }
    }

    @IBAction func showNextTab(_ sender: Any?) {
        // Activate next tab
        if let i = state.tabs.firstIndex(of: state.currentTab) {
            let i = (i + 1) % state.tabs.count
            state.currentTab = state.tabs[i]
        }
    }

    @IBAction func newSearch(_ sender: Any?) {
        state.mode = .note
        state.searchQuery = ""
    }

    override func performClose(_ sender: Any?) {
        if state.mode == .web {
            if let i = state.tabs.firstIndex(of: state.currentTab) {
                state.tabs.remove(at: i)
                let nextTabIndex = min(i, state.tabs.count - 1)
                if nextTabIndex >= 0 {
                    state.currentTab = state.tabs[nextTabIndex]
                }
                return
            }
        }

        super.performClose(sender)
    }
}
