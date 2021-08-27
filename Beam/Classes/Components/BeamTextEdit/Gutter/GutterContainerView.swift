//
//  GutterContainerView.swift
//  Beam
//
//  Created by Remi Santos on 26/08/2021.
//

import Foundation
import SwiftUI

struct GutterView: View {
    @ObservedObject var model: Model

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                ForEach(model.items) { item in
                    GutterItemView(item: item, containerGeometry: geometry)
                }
            }
            .onHover {
                if $0 {
                    NSCursor.arrow.set()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .frame(width: geometry.size.width, alignment: .topTrailing)
            .zIndex(1000)
        }
    }
}

extension GutterView {
    class Model: ObservableObject {
        @Published var items: [GutterItem]
        init(items: [GutterItem]) {
            self.items = items
        }
    }
}

class GutterContainerView: NSView {
    override var isFlipped: Bool {
        true
    }

    private var hostingView: NSHostingView<GutterView>?
    private var model = GutterView.Model(items: [])

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        self.wantsLayer = true
        self.layer?.masksToBounds = false
        let view = NSHostingView(rootView: GutterView(model: model))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        view.layer?.masksToBounds = false
        addSubviewWithConstraintsOnEachSide(subView: view)
    }

    func addItem(_ item: GutterItem) {
        model.items.append(item)
    }

    func removeItem(_ item: GutterItem) {
        model.items.removeAll(where: { i in
            i == item
        })
    }
}
