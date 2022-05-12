//
//  WindowPage.swift
//  Beam
//
//  Created by Remi Santos on 30/03/2021.
//

import Foundation
import SwiftUI

protocol WindowPageContentView: View {

    associatedtype Content: View

}

class WindowPage {

    let id: WindowPageID
    let title: String?
    let displayTitle: String?
    var contentView: () -> AnyView

    init(id: WindowPageID, title: String? = nil, displayTitle: String? = nil, @ViewBuilder contentView: @escaping () -> AnyView) {
        self.id = id
        self.title = title
        self.displayTitle = displayTitle
        self.contentView = contentView
    }

    static func pageForId(_ id: WindowPageID) -> WindowPage? {
        switch id {
        case .allNotes:
            return allNotesWindowPage
        case .shortcuts:
            return shortcutsWindowPage
        }
    }
}

enum WindowPageID: String {
    case allNotes
    case shortcuts
}

extension WindowPage {
    static var allNotesWindowPage: WindowPage {
        return WindowPage(id: .allNotes, title: "All Notes") {
            AnyView(AllNotesPageContentView())
        }
    }

    static var shortcutsWindowPage: WindowPage {
        return WindowPage(id: .shortcuts, title: "Shortcuts") {
            AnyView(DiscoverShortcutsView())
        }
    }
}
