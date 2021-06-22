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
    var subtitle: String?
    var icon: String?
    private(set) var type = ContextMenuItemType.item
    let action: (() -> Void)?

    static func separator() -> ContextMenuItem {
        ContextMenuItem(title: "", type: ContextMenuItemType.separator, action: nil)
    }
}

struct ContextMenuItemView: View {

    @Environment(\.isEnabled) private var isEnabled: Bool
    var item: ContextMenuItem
    var highlight = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(BeamColor.ContextMenu.hover.swiftUI.opacity(highlight ? 1.0 : 0.0))
                .animation(nil)
            HStack(spacing: BeamSpacing._60) {
                if let icon = item.icon {
                    Icon(name: icon, size: 16, color: BeamColor.LightStoneGray.swiftUI)
                }
                Text(item.title)
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(isEnabled ? BeamColor.Generic.text.swiftUI : BeamColor.LightStoneGray.swiftUI)
                if let subtitle = item.subtitle {
                    Spacer()
                    Text(subtitle)
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.AlphaGray.swiftUI)
                }
            }
            .padding(.vertical, BeamSpacing._40)
            .padding(.horizontal, BeamSpacing._50)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibility(addTraits: highlight ? [.isSelected, .isStaticText] : .isStaticText)
        .accessibility(identifier: "ContextMenuItem-\(item.title.lowercased())")
    }

}

class ContextMenuViewModel: BaseFormatterViewViewModel, ObservableObject {
    @Published var items: [ContextMenuItem] = [] {
        didSet {
            selectedIndex = 0
        }
    }
    @Published var selectedIndex: Int?
    var onSelectMenuItem: (() -> Void)?
}

struct ContextMenuView: View {

    @ObservedObject var viewModel = ContextMenuViewModel()
    static let itemHeight: CGFloat = 24
    static let defaultWidth: CGFloat = 160
    static let largeWidth: CGFloat = 240

    static func idealSizeForItems(_ items: [ContextMenuItem]) -> CGSize {
        guard items.count > 0 else { return .zero }
        let spacing: CGFloat = BeamSpacing._50
        var itemsNeedLargeWidth = false
        let height = items.reduce(spacing) { (result, item) -> CGFloat in
            if item.type == .separator {
                return result + Separator.height + spacing
            }
            itemsNeedLargeWidth = itemsNeedLargeWidth || item.subtitle != nil || item.icon != nil
            return result + ContextMenuView.itemHeight + spacing
        }
        let width = itemsNeedLargeWidth ? self.largeWidth : self.defaultWidth
        return CGSize(width: width, height: height)
    }

    @State private var hoveringIndex: Int?

    var body: some View {
        FormatterViewBackground {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(viewModel.items.enumerated()), id: \.1.id) { index, item in
                    let isSelected = viewModel.selectedIndex == index
                    if item.type == .separator {
                        Separator(horizontal: true)
                    } else {
                        ContextMenuItemView(item: item, highlight: isSelected)
                            .frame(height: ContextMenuView.itemHeight)
                            .disabled(item.action == nil)
                            .onTapGesture {
                                item.action?()
                                viewModel.onSelectMenuItem?()
                            }
                            .onHoverOnceVisible { hovering in
                                if isSelected && !hovering && hoveringIndex == index {
                                    viewModel.selectedIndex = nil
                                } else if hovering && item.action != nil {
                                    viewModel.selectedIndex = index
                                }
                                hoveringIndex = hovering ? index : nil
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(viewModel.items.count > 0 ? BeamSpacing._50 : 0)
        }
        .zIndex(1000)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.15))
        .scaleEffect(viewModel.visible ? 1.0 : 0.98)
        .offset(x: 0, y: viewModel.visible ? 0.0 :
                    (viewModel.animationDirection == .bottom ? -4.0 : 4.0)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.6))
        .opacity(viewModel.visible ? 1.0 : 0.0)
        .animation(viewModel.visible ? .easeInOut(duration: 0.3) : .easeInOut(duration: 0.15))
        .accessibilityElement(children: .contain)
        .accessibility(identifier: "ContextMenu")
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
    private static var model: ContextMenuViewModel {
        let model = ContextMenuViewModel()
        model.items = Self.items
        return model
    }
    static var previews: some View {
        return ContextMenuView(viewModel: model)
            .padding(.all)
    }
}
