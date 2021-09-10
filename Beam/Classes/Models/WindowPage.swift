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
        case .AllCards:
            return allCardsWindowPage
        }
    }
}

enum WindowPageID: String {
    case AllCards
}

extension WindowPage {
    static var allCardsWindowPage: WindowPage {
        return WindowPage(id: .AllCards) {
            AnyView(AllCardsPageContentView())
        }
    }
}
