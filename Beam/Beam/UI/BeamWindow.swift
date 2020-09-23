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
}
