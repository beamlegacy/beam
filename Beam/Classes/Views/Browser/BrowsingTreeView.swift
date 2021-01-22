//
//  BrowsingTreeView.swift
//  Beam
//
//  Created by Sebastien Metrot on 14/01/2021.
//

import Foundation
import SwiftUI

struct BrowsingNodeView: View {
    @ObservedObject var browsingNode: BrowsingNode

    var body: some View {
        VStack {
            Text(LinkStore.shared.linkFor(id: browsingNode.link)?.url ?? "???").bold().frame(maxWidth: .infinity, alignment: .leading)

            ForEach(0..<browsingNode.children.count) { index in
                BrowsingNodeView(browsingNode: browsingNode.children[index])
                    .padding(.leading, 20)
            }
        }.foregroundColor(Color.white)
    }

}

struct BrowsingTreeView: View {
    @ObservedObject var browsingTree: BrowsingTree

    @State var position = CGSize()
    @State var initialPosition = CGSize()
    @State var dragging = false
    func actualPosition(_ containerSize: CGSize, _ position: CGSize) -> CGSize {
        let width = max(0, min(containerSize.width - 100, position.width))
        let height = max(0, min(containerSize.height - 100, position.height))
        return CGSize(width: width, height: height)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Text("Browsing Tree").bold().frame(maxWidth: .infinity, alignment: .leading)
                BrowsingNodeView(browsingNode: browsingTree.root).padding()
            }.background(
                RoundedRectangle(cornerRadius: 7)
                    .foregroundColor(Color.gray.opacity(0.85))
            ).foregroundColor(Color.white)
            .frame(alignment: .topLeading)
            .position(x: 100, y: 100)
            .offset(x: actualPosition(geometry.size, position).width, y: actualPosition(geometry.size, position).height)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if !dragging {
                            initialPosition = actualPosition(geometry.size, position)
                            dragging = true
                        }

                        var width = initialPosition.width + gesture.translation.width
                        var height = initialPosition.height + gesture.translation.height

                        width = max(0, min(geometry.size.width - 100, width))
                        height = max(0, min(geometry.size.height - 100, height))

                        self.position = actualPosition(geometry.size, CGSize(width: width, height: height))
                    }

                    .onEnded { _ in
                        dragging = false
                    }
            )
        }
    }

}
