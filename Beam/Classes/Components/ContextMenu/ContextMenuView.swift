//
//  ContextMenuView.swift
//  Beam
//
//  Created by Remi Santos on 05/05/2021.
//

import SwiftUI

struct ContextMenuItem: Identifiable {
    enum ContextMenuItemType {
        case item
        case separator
    }

    let id = UUID()
    let title: String
    private(set) var type = ContextMenuItemType.item
    let action: (() -> Void)?

    static func separator() -> ContextMenuItem {
        ContextMenuItem(title: "", type: ContextMenuItemType.separator, action: nil)
    }
}

struct ContextMenuItemView: View {

    @Environment(\.isEnabled) private var isEnabled: Bool
    var item: ContextMenuItem
    var isSelected = false
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3).fill(BeamColor.ContextMenu.hover.swiftUI.opacity(isHovering || isSelected ? 1.0 : 0.0))
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

class ContextMenuViewModel: BaseFormatterViewViewModel, ObservableObject {
    @Published var selectedIndex: Int?
    var onSelectMenuItem: (() -> Void)?
}

struct ContextMenuView: View {

    @ObservedObject var viewModel = ContextMenuViewModel()
    static let itemHeight: CGFloat = 23
    static let defaultWidth: CGFloat = 160

    static func idealSizeForItems(_ items: [ContextMenuItem]) -> CGSize {
        let spacing: CGFloat = 5.0
        let height = items.reduce(0) { (result, item) -> CGFloat in
            if item.type == .separator {
                return result + Separator.height + spacing
            }
            return result + ContextMenuView.itemHeight + spacing
        }
        return CGSize(width: self.defaultWidth, height: height)
    }

    @Binding var items: [ContextMenuItem]

    var body: some View {
        FormatterViewBackground {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(items.enumerated()), id: \.0) { index, item in
                    let isSelected = viewModel.selectedIndex == index
                    if item.type == .separator {
                        Separator(horizontal: true)
                    } else {
                        ContextMenuItemView(item: item, isSelected: isSelected)
                            .disabled(item.action == nil)
                            .onTapGesture {
                                item.action?()
                                viewModel.onSelectMenuItem?()
                            }
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
        ContextMenuItem(title: "Open Link", action: nil),
        ContextMenuItem.separator(),
        ContextMenuItem(title: "Copy Link", action: nil),
        ContextMenuItem(title: "Edit Link...", action: nil),
        ContextMenuItem(title: "Remove Link", action: nil)
    ]
    static var previews: some View {
        return ContextMenuView(items: .constant(Self.items))
            .padding(.all)
    }
}
