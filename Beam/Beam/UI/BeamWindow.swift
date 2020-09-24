//
//  BeamWindow.swift
//  Beam
//
//  Created by Sebastien Metrot on 23/09/2020.
//

import Cocoa
import Combine
import SwiftUI

class BeamWindow: NSWindow {
    var state: BeamState!
    var cloudKitContainer: NSPersistentCloudKitContainer

    init(contentRect: NSRect, cloudKitContainer: NSPersistentCloudKitContainer) {
        let state = BeamState()
        self.state = state
        self.cloudKitContainer = cloudKitContainer
        super.init(contentRect: contentRect, styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        self.tabbingMode = .disallowed
        // Create the SwiftUI view and set the context as the value for the managedObjectContext environment keyPath.
        // Add `@Environment(\.managedObjectContext)` in the views that will need the context.
        let contentView = ContentView().environment(\.managedObjectContext, cloudKitContainer.viewContext).environmentObject(state)
        setFrameAutosaveName("BeamWindow")
        self.contentView = NSHostingView(rootView: contentView)
        
        // Create the titlebar accessory
//        let titlebarAccessoryView = MainToolBar()
//            .environmentObject(BeamState.shared)

        let titlebarAccessoryView = SearchBar().environmentObject(state)

        
        let accessoryHostingView = NSHostingView(rootView:titlebarAccessoryView)
        accessoryHostingView.frame.size = accessoryHostingView.fittingSize
        
        let titlebarAccessory = NSTitlebarAccessoryViewController()
        titlebarAccessory.layoutAttribute = .top
        titlebarAccessory.view = accessoryHostingView
        
        // Add the titlebar accessory
        self.addTitlebarAccessoryViewController(titlebarAccessory)

    }
    
    @IBAction func newDocument(_ sender: Any?) {
        let window = BeamWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 300), cloudKitContainer: cloudKitContainer)
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
