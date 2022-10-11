//
//  EditorTabGroupsContainerView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 10/06/2022.
//

import SwiftUI
import BeamCore

struct EditorTabGroupsContainerView: View {

    let tabGroups: [TabGroupBeamObject]
    let note: BeamNote

    @Environment(\.faviconProvider) var faviconProvider

    @State private var hoveredTab: TabGroupBeamObject.PageInfo?
    @State private var hoveredTabGroupFrame: CGPoint?
    @State private var hoveredTabGroupColor: Color?

    var body: some View {
        GeometryReader { proxy in
            LazyVGrid(columns: columns(for: proxy.size.width), alignment: .leading, spacing: 10) {
                ForEach(tabGroups) { group in
                    EditorTabGroupView(tabGroup: group,
                                       note: note,
                                       hoveredTab: $hoveredTab,
                                       hoveredGroupFrame: $hoveredTabGroupFrame,
                                       hoveredGroupColor: $hoveredTabGroupColor)
                }.zIndex(0)
            }
            .accessibilityValue( "Tab Groups container with \(tabGroups.count)")
            .accessibility(identifier: "TabGroupsContainerView")
            .overlay(previewOverlay(for: hoveredTab, localProxy: proxy.frame(in: .global)), alignment: .top)
        }
    }

    private func columns(for width: CGFloat) -> [GridItem] {
        if width > 400 {
            return [
                GridItem(.flexible(minimum: 100, maximum: 200)),
                GridItem(.flexible(minimum: 100, maximum: 200)),
                GridItem(.flexible(minimum: 100, maximum: 200)),
                GridItem(.flexible(minimum: 100, maximum: 200))
            ]
        } else {
            return [GridItem(.adaptive(minimum: 100, maximum: 200))]
        }
    }

    @ViewBuilder private func previewOverlay(for tab: TabGroupBeamObject.PageInfo?, localProxy: CGRect) -> some View {
        if let hoveredTab = hoveredTab,
           let hoveredTabGroupFrame = hoveredTabGroupFrame,
           let groupColor = hoveredTabGroupColor {
            TabPreview(tab: hoveredTab, faviconProvider: faviconProvider, placeholderTintColor: groupColor)
                .position(CGPoint(x: hoveredTabGroupFrame.x - localProxy.origin.x, y: hoveredTabGroupFrame.y - localProxy.origin.y + previewOffset))
        }
    }

    private var previewOffset: CGFloat {
        let previewHeight =  154.0
        let tabGroupViewHeight = EditorTabGroupView.height
        let margin = 4.0
        return (previewHeight / 2 + tabGroupViewHeight / 2) + margin
    }
}

struct EditorTabGroupsContainerView_Previews: PreviewProvider {
    static var previews: some View {
        EditorTabGroupsContainerView(tabGroups: [
            TabGroupBeamObject(title: "Test")
        ], note: try! BeamNote(title: "A note"))
    }
}
