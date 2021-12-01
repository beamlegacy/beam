//
//  GutterItemView.swift
//  Beam
//
//  Created by Remi Santos on 27/08/2021.
//

import SwiftUI

class GutterItem: Identifiable, Equatable, ObservableObject {
    static func == (lhs: GutterItem, rhs: GutterItem) -> Bool {
        lhs.id == rhs.id
    }

    var id: UUID
    @Published var title: String
    @Published var icon: String?
    @Published var y: CGFloat = 0
    @Published var height: CGFloat = 0
    @Published var visible: Bool = false
    var action: (() -> Void)?

    init(id: UUID, title: String, icon: String?, action: (() -> Void)?) {
        self.id = id
        self.title = title
        self.icon = icon
        self.action = action
    }

    func updateFrameFromNode(_ node: ElementNode) {
        y = node.frameInDocument.minY
        height = node.idealSize.height
        visible = node.hover
    }
}

struct GutterItemView: View {
    @ObservedObject var item: GutterItem
    var containerGeometry: GeometryProxy

    @State private var isHoveringText: Bool = false
    @State private var isHoveringContent: Bool = false

    private var isVisible: Bool {
        item.visible || isHoveringContent
    }
    private var foregroundColor: Color {
        isHoveringText ? BeamColor.Bluetiful.swiftUI : BeamColor.AlphaGray.swiftUI
    }

    private let insidePadding: CGFloat = 4
    private var isSmallLayout: Bool {
        containerGeometry.size.width < 190
    }
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(BeamColor.Mercury.swiftUI)
                .frame(width: 1, height: item.height)
                .padding(.top, insidePadding)
            HStack(alignment: .top, spacing: 0) {
                Spacer(minLength: 20)
                HStack(alignment: .top, spacing: 2) {
                    if let icon = item.icon {
                        Icon(name: icon, width: 12, color: foregroundColor)
                    }
                    if !isSmallLayout || isHoveringContent {
                        Text(item.title)
                            .multilineTextAlignment(.trailing)
                            .font(BeamFont.regular(size: 10).swiftUI)
                            .foregroundColor(.white)
                            .colorMultiply(foregroundColor)
                    }
                }
                .onTapGesture {
                    item.action?()
                }
                .onHover {
                    isHoveringText = $0
                }

            }
            .padding(.vertical, insidePadding)
            .frame(maxHeight: .infinity, alignment: .top)
            .onHover {
                isHoveringContent = $0
            }
            .animation(.easeInOut(duration: 0.15), value: isHoveringContent)
        }
        .padding(.leading, insidePadding)
        .background(
            VisualEffectView(
                material: .headerView,
                blendingMode: .withinWindow,
                emphasized: false
            )
            .cornerRadius(3)
            .opacity(isHoveringContent ? 1 : 0)
        )
        .padding(.leading, 56)
        .padding(.trailing, BeamSpacing._200)
        .frame(height: item.height + insidePadding * 2)
        .frame(minWidth: isHoveringContent ? containerGeometry.size.width : 0, maxWidth: max(containerGeometry.size.width, 228 + 56))
        .fixedSize(horizontal: isHoveringContent, vertical: false)
        .offset(x: 0, y: item.y - 4)
        .opacity(isVisible ? 1.0 : 0)
        .animation(.easeInOut(duration: 0.15), value: isVisible)
        .animation(.easeInOut(duration: 0.15), value: isHoveringContent)
    }
}
