//
//  PreferencePaneBuilder.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 12/07/2021.
//

import Foundation
import SwiftUI
import Preferences

class PreferencesPaneBuilder {
    static func build<Content: View>(identifier: Preferences.PaneIdentifier, title: String, imageName: String, contentView: () -> Content) -> PreferencePane {
        let paneView = Preferences.Pane(
            identifier: identifier,
            title: title,
            toolbarIcon: NSImage(named: imageName)!.fill(color: NSColor.white)) { contentView() }
        return Preferences.PaneHostingController(pane: paneView)
    }
}
