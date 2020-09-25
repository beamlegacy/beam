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


class BeamWindow: NSWindow, NSToolbarDelegate {
    var state: BeamState!
    var cloudKitContainer: NSPersistentCloudKitContainer

    init(contentRect: NSRect, cloudKitContainer: NSPersistentCloudKitContainer) {

        let state = BeamState()
        self.state = state
        self.cloudKitContainer = cloudKitContainer
        super.init(contentRect: contentRect, styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.toolbar = BeamToolBar(self)
        self.toolbar?.isVisible = true
 
        self.tabbingMode = .disallowed
        // Create the SwiftUI view and set the context as the value for the managedObjectContext environment keyPath.
        // Add `@Environment(\.managedObjectContext)` in the views that will need the context.
        let contentView = ContentView().environment(\.managedObjectContext, cloudKitContainer.viewContext).environmentObject(state)
        setFrameAutosaveName("BeamWindow")
        self.contentView = NSHostingView(rootView: contentView)
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
    
    // Toolbar delegate and support:
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.searchBar]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.searchBar]
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case NSToolbarItem.Identifier.searchBar:
            let titlebarAccessoryView = SearchBar()
                .environmentObject(state)
            let accessoryHostingView = NSHostingView(rootView:titlebarAccessoryView)
            accessoryHostingView.frame.size = accessoryHostingView.fittingSize
            return customToolbarItem(itemIdentifier: .searchBar, label: "Omni Bar", paletteLabel: "Omni Bar", toolTip: "Search and navigate", itemContent: accessoryHostingView)
        default:
            return nil
        }
    }
    
    /**
     Mostly base on Apple sample code: https://developer.apple.com/documentation/appkit/touch_bar/integrating_a_toolbar_and_touch_bar_into_your_app
     */
    func customToolbarItem(
        itemIdentifier: NSToolbarItem.Identifier,
        label: String,
        paletteLabel: String,
        toolTip: String,
        itemContent: NSView) -> NSToolbarItem? {
        
        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        
        toolbarItem.label = label
        toolbarItem.paletteLabel = paletteLabel
        toolbarItem.toolTip = toolTip
        /**
         You don't need to set a `target` if you know what you are doing.
         
         In this example, AppDelegate is also the toolbar delegate.
         
         Since AppDelegate is not a responder, implementing an IBAction in the AppDelegate class has no effect. Try using a subclass of NSWindow or NSWindowController to implement your action methods and use them as the toolbar delegate instead.
         
         Ref: https://developer.apple.com/documentation/appkit/nstoolbaritem/1525982-target
         
         From doc:
         
         If target is nil, the toolbar will call action and attempt to invoke the action on the first responder and, failing that, pass the action up the responder chain.
         */
//        toolbarItem.target = self
//        toolbarItem.action = #selector(methodName)
        
        toolbarItem.view = itemContent
        
        // We actually need an NSMenuItem here, so we construct one.
        let menuItem: NSMenuItem = NSMenuItem()
        menuItem.submenu = nil
        menuItem.title = label
        toolbarItem.menuFormRepresentation = menuItem
        toolbarItem.minSize = CGSize(width: 150, height: itemContent.frame.size.height)
        toolbarItem.maxSize = CGSize(width: 1000000, height: itemContent.frame.size.height)
        toolbarItem.visibilityPriority = .user
//        toolbarItem.allowsDuplicatesInToolbar = false
        toolbarItem.autovalidates = true
        
        return toolbarItem
    }

}
