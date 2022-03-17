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
    var contentView: () -> AnyView

    init(id: WindowPageID, title: String? = nil, @ViewBuilder contentView: @escaping () -> AnyView) {
        self.id = id
        self.title = title
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
        return WindowPage(id: .allNotes) {
            AnyView(AllNotesPageContentView())
        }
    }

    static var shortcutsWindowPage: WindowPage {
        return WindowPage(id: .shortcuts) {
            AnyView(DiscoverShortcutsView())
        }
    }
}
