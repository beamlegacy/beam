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

    init(contentRect: NSRect, cloudKitContainer: NSPersistentCloudKitContainer) {
        let state = BeamState()
        self.state = state
        
        super.init(contentRect: contentRect, styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
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
    
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            if event.modifierFlags.contains(.shift) {
                if event.characters == "[" {
                    // Activate previous tab
                    if let i = state.tabs.firstIndex(of: state.currentTab) {
                        let i = i - 1 < 0 ? state.tabs.count - 1 : i - 1
                        state.currentTab = state.tabs[i]
                    }
                } else if event.characters == "]" {
                    // Activate next tab
                    if let i = state.tabs.firstIndex(of: state.currentTab) {
                        let i = (i + 1) % state.tabs.count
                        state.currentTab = state.tabs[i]
                    }
                }
            }
            
        }
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.charactersIgnoringModifiers == "w" && event.modifierFlags.contains(.command) {
            // Close current tab
            state.tabs.removeAll { tab -> Bool in
                state.currentTab.id == tab.id
            }
            return true
        }
        
        if event.charactersIgnoringModifiers == "t" && event.modifierFlags.contains(.command) {
            state.mode = .note
            state.searchQuery = ""
            return true
        }
        
        return super.performKeyEquivalent(with: event)
    }
}
