//
//  BeamWindow.swift
//  Beam
//
//  Created by Sebastien Metrot on 23/09/2020.
//

import Cocoa
import Combine
import SwiftUI

extension NSToolbarItem.Identifier {
    static let searchBar = NSToolbarItem.Identifier(rawValue: "SearchBar")
}

class BeamToolBar: NSToolbar {
    init(_ window: BeamWindow) {
        super.init(identifier: "BeamToolBar")
        self.delegate = window
        displayMode = .iconAndLabel
    }
}

class BeamHostingView<Content> : NSHostingView<Content> where Content : View {
    required public init(rootView: Content) {
        super.init(rootView: rootView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        assert(false)
    }
    
    public override var allowsVibrancy: Bool { false }
}
    


class BeamWindow: NSWindow, NSToolbarDelegate {
    var state: BeamState!
    var cloudKitContainer: NSPersistentCloudKitContainer
    var data: BeamData

    init(contentRect: NSRect, cloudKitContainer: NSPersistentCloudKitContainer, data: BeamData) {
        self.data = data
        let state = BeamState(data: data)
        self.state = state
        self.cloudKitContainer = cloudKitContainer
        
        super.init(contentRect: contentRect, styleMask: [.titled, .closable, .miniaturizable, .texturedBackground, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: false)

        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden

        let version = ProcessInfo.processInfo.operatingSystemVersion
        let RunningOnBigSur = version.majorVersion >= 11 || (version.majorVersion == 10 && version.minorVersion >= 16)
        
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        
        self.tabbingMode = .disallowed
        setFrameAutosaveName("BeamWindow")

        // Create the SwiftUI view and set the context as the value for the managedObjectContext environment keyPath.
        // Add `@Environment(\.managedObjectContext)` in the views that will need the context.
        let contentView = ContentView().environment(\.managedObjectContext, cloudKitContainer.viewContext).environmentObject(state)
        self.contentView = BeamHostingView(rootView: contentView)

        // THIS HACK IS HORRIBLE But AppKit leaves us little choice to have a similar look on Catalina and Future OSes
        if let b = self.standardWindowButton(.closeButton) {
            if var f = b.superview?.superview?.frame {
                let v = CGFloat(RunningOnBigSur ? 7: 13)
                f.size.height += v
                f.origin.y -= v
                b.superview?.superview?.frame = f
            }
        }

        self.contentView = BeamHostingView(rootView: contentView)
        self.isMovableByWindowBackground = false
    }

    @IBAction func newDocument(_ sender: Any?) {
        let window = BeamWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 300), cloudKitContainer: cloudKitContainer, data: data)
        window.center()
        window.makeKeyAndOrderFront(nil)
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
