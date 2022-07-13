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

    @State var hoveredTab: TabGroupBeamObject.PageInfo?
    @State var hoveredTabGroupFrame: CGPoint?

    let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 200)),
        GridItem(.adaptive(minimum: 100, maximum: 200)),
        GridItem(.adaptive(minimum: 100, maximum: 200)),
        GridItem(.adaptive(minimum: 100, maximum: 200))
    ]

    var body: some View {
        GeometryReader { proxy in
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(tabGroups) { group in
                    EditorTabGroupView(tabGroup: group, note: note, hoveredTab: $hoveredTab, hoveredGroupFrame: $hoveredTabGroupFrame)
                }.zIndex(0)
            }
            .overlay(previewOverlay(for: hoveredTab, localProxy: proxy.frame(in: .global)), alignment: .top)
        }
    }

    @ViewBuilder private func previewOverlay(for tab: TabGroupBeamObject.PageInfo?, localProxy: CGRect) -> some View {
        if let hoveredTab = hoveredTab, let hoveredTabGroupFrame = hoveredTabGroupFrame {
            TabPreview(tab: hoveredTab)
                .position(CGPoint(x: hoveredTabGroupFrame.x - localProxy.origin.x , y: hoveredTabGroupFrame.y - localProxy.origin.y + offset(for: hoveredTab)))
        }
    }

    private func offset(for pageInfo: TabGroupBeamObject.PageInfo) -> CGFloat {
        let previewHeight = pageInfo.snapshot == nil ? 36.0 : 154.0
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
