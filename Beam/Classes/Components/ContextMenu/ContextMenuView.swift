//
//  ContextMenuView.swift
//  Beam
//
//  Created by Remi Santos on 05/05/2021.
//

import SwiftUI

struct ContextMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let action: (() -> Void)?
}

struct ContextMenuItemView: View {

    @Environment(\.isEnabled) private var isEnabled: Bool
    var item: ContextMenuItem

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3).fill(BeamColor.ContextMenu.hover.swiftUI.opacity(isHovering ? 1.0 : 0.0))
            Text(item.title)
                .font(BeamFont.medium(size: 13).swiftUI)
                .foregroundColor(isEnabled ? BeamColor.Generic.text.swiftUI : BeamColor.LightStoneGray.swiftUI)
                .padding(.vertical, BeamSpacing._40)
                .padding(.horizontal, BeamSpacing._50)
        }
        .frame(maxWidth: .infinity)
        .onHover { hovering in
            isHovering = isEnabled && hovering
        }
    }

}

struct ContextMenuView: View {

    @ObservedObject var viewModel = FormatterViewViewModel()
    static let itemHeight: CGFloat = 23
    static let defaultWidth: CGFloat = 160

    static func idealSizeForItems(_ items: [[ContextMenuItem]]) -> CGSize {
        let numberOfSections = items.count
        let numberOfItems = items.reduce(0) { (result, section) -> Int in
            return result + section.count
        }
        let spacing: CGFloat = 5.0
        let itemsHeights = CGFloat(numberOfItems) * (ContextMenuView.itemHeight + spacing)
        let height: CGFloat = spacing + itemsHeights + CGFloat(numberOfSections - 1) * (Separator.height + spacing)
        return CGSize(width: self.defaultWidth, height: height)
    }

    @Binding var items: [[ContextMenuItem]]

    var body: some View {
        FormatterViewBackground {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(0..<items.count) { i in
                    ForEach(items[i]) { item in
                        ContextMenuItemView(item: item)
                            .disabled(item.action == nil)
                            .onTapGesture {
                                item.action?()
                            }
                    }
                    if i != items.count - 1 {
                        Separator(horizontal: true)
                    }
                }
            }
            .padding(BeamSpacing._50)
        }
        .zIndex(1000)
        .frame(minWidth: Self.defaultWidth)
        .scaleEffect(viewModel.visible ? 1.0 : 0.98)
        .offset(x: 0, y: viewModel.visible ? 0.0 :
                    (viewModel.animationDirection == .bottom ? -4.0 : 4.0)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.6))
        .opacity(viewModel.visible ? 1.0 : 0.0)
        .animation(viewModel.visible ? .easeInOut(duration: 0.3) : .easeInOut(duration: 0.15))
    }
}

struct ContextMenuView_Previews: PreviewProvider {

    private static var items = [
        [ContextMenuItem(title: "Open Link", action: nil)],
        [
            ContextMenuItem(title: "Copy Link", action: nil),
            ContextMenuItem(title: "Edit Link...", action: nil),
            ContextMenuItem(title: "Remove Link", action: nil)
        ]
    ]
    static var previews: some View {
        return ContextMenuView(items: .constant(Self.items))
            .padding(.all)
    }
}
