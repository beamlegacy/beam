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
    enum IconPlacement {
        case leading
        case trailing
    }

    let id = UUID()
    let title: String
    var subtitle: String?
    var icon: String?
    var iconPlacement: IconPlacement = .leading
    var iconSize: CGFloat = 16
    var iconColor: BeamColor = .LightStoneGray
    private(set) var type = ContextMenuItemType.item
    let action: (() -> Void)?
    var iconAction: (() -> Void)?

    static func separator() -> ContextMenuItem {
        ContextMenuItem(title: "", type: ContextMenuItemType.separator, action: nil)
    }
}

struct ContextMenuItemView: View {

    @Environment(\.isEnabled) private var isEnabled: Bool
    var item: ContextMenuItem
    var highlight = false

    var iconView: some View {
        Group {
            if let icon = item.icon {
                if let iconAction = item.iconAction {
                    ButtonLabel(icon: icon, customStyle: .tinyIconStyle, action: iconAction)
                } else {
                    Icon(name: icon, width: item.iconSize, color: item.iconColor.swiftUI)
                }
            }
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(BeamColor.ContextMenu.hover.swiftUI.opacity(highlight ? 1.0 : 0.0))
                .animation(nil)
            HStack(spacing: BeamSpacing._60) {
                if item.iconPlacement == .leading {
                    iconView
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
                if item.iconPlacement == .trailing {
                    Spacer()
                    iconView
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
    @Published var items: [ContextMenuItem] = []
    @Published var selectedIndex: Int?
    @Published var sizeToFit: Bool = false
    @Published var containerSize: CGSize = .zero
    var onSelectMenuItem: (() -> Void)?
}

struct ContextMenuView: View {

    @ObservedObject var viewModel: ContextMenuViewModel
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
        let computedSize = Self.idealSizeForItems(viewModel.items)
        return ZStack {
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
            .if(viewModel.sizeToFit) { $0.frame(maxWidth: computedSize.width, alignment: .leading) }
            .if(!viewModel.sizeToFit) { $0.frame(width: computedSize.width, alignment: .leading) }
            .fixedSize(horizontal: viewModel.sizeToFit, vertical: true)
            .frame(height: viewModel.containerSize.height, alignment: .topLeading)
            .animation(BeamAnimation.easeInOut(duration: 0.15), value: computedSize.height)
            .formatterViewBackgroundAnimation(with: viewModel)
            .accessibilityElement(children: .contain)
            .accessibility(identifier: "ContextMenu")
        }
        .frame(width: viewModel.containerSize.width, height: viewModel.containerSize.height, alignment: .topLeading)
    }
}

struct ContextMenuView_Previews: PreviewProvider {

    private static var items = [
        ContextMenuItem(title: "Open Link", action: { }),
        ContextMenuItem.separator(),
        ContextMenuItem(title: "Copy Link", action: { }),
        ContextMenuItem(title: "Edit Link...", action: nil),
        ContextMenuItem(title: "Remove Link", action: { })
    ]
    private static var model: ContextMenuViewModel {
        let model = ContextMenuViewModel()
        model.items = Self.items
        model.visible = true
        model.sizeToFit = true
        model.containerSize = CGSize(width: 200, height: 200)
        return model
    }
    static var previews: some View {
        ZStack {
            ContextMenuView(viewModel: model)
        }
        .frame(width: model.containerSize.width, height: model.containerSize.height)
        .padding(.all)
    }
}
