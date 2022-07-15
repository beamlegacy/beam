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

    @State private var hoveredTab: TabGroupBeamObject.PageInfo?
    @State private var hoveredTabGroupFrame: CGPoint?
    @State private var hoveredTabGroupColor: Color?

    let columns = [
        GridItem(.flexible(minimum: 100, maximum: 200)),
        GridItem(.flexible(minimum: 100, maximum: 200)),
        GridItem(.flexible(minimum: 100, maximum: 200)),
        GridItem(.flexible(minimum: 100, maximum: 200))
    ]

    var body: some View {
        GeometryReader { proxy in
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(tabGroups) { group in
                    EditorTabGroupView(tabGroup: group,
                                       note: note,
                                       hoveredTab: $hoveredTab,
                                       hoveredGroupFrame: $hoveredTabGroupFrame,
                                       hoveredGroupColor: $hoveredTabGroupColor)
                }.zIndex(0)
            }
            .overlay(previewOverlay(for: hoveredTab, localProxy: proxy.frame(in: .global)), alignment: .top)
        }
    }

    @ViewBuilder private func previewOverlay(for tab: TabGroupBeamObject.PageInfo?, localProxy: CGRect) -> some View {
        if let hoveredTab = hoveredTab,
           let hoveredTabGroupFrame = hoveredTabGroupFrame,
           let groupColor = hoveredTabGroupColor {
            TabPreview(tab: hoveredTab, placeholderTintColor: groupColor)
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
