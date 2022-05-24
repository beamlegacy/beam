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
        case itemWithToggle
        case itemWithDisclosure
        case separator
    }
    enum IconPlacement {
        case leading
        case trailing
    }

    let id = UUID()
    let title: String
    var subtitle: String?
    var subtitleButton: String?
    var showSubtitleButton: Bool = false
    var icon: String?
    var iconPlacement: IconPlacement = .leading
    var iconSize: CGFloat = 16
    var iconColor: BeamColor = .LightStoneGray
    private(set) var type = ContextMenuItemType.item
    let action: (() -> Void)?
    var iconAction: (() -> Void)?
    var isToggleOn: Bool = false
    var toggleAction: ((Bool) -> Void)?
    var subMenuModel: ContextMenuViewModel?

    static func separator() -> ContextMenuItem {
        ContextMenuItem(title: "", type: ContextMenuItemType.separator, action: nil)
    }
}

struct ContextMenuItemView: View {

    @ObservedObject var viewModel: ContextMenuViewModel
    @Environment(\.isEnabled) private var isEnabled: Bool
    var item: ContextMenuItem
    var highlight = false
    @State var toggleSwitched: Bool = false
    @State var showSubtitleButton: Bool = false

    private var transitionInOutHiddenView: AnyTransition {
        let transitionIn = AnyTransition.move(edge: .top).animation(BeamAnimation.easeIn(duration: 0.20)).combined(with: .opacity.animation(BeamAnimation.easeIn(duration: 0.20)))
        let transitionOut = AnyTransition.move(edge: .top).animation(BeamAnimation.easeIn(duration: 0.20)).combined(with: .opacity.animation(BeamAnimation.easeIn(duration: 0.15)))

        return AnyTransition.asymmetric(insertion: transitionIn, removal: transitionOut)
    }

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
            VStack(alignment: .leading) {
                HStack(spacing: BeamSpacing._60) {
                    if item.iconPlacement == .leading {
                        iconView
                    }
                    if item.type == .itemWithToggle {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(item.title)
                                    .font(BeamFont.regular(size: 13).swiftUI)
                                Spacer()
                                ToggleView(isOn: $toggleSwitched)
                                    .frame(width: 26, height: 16, alignment: .trailing)
                                    .onChange(of: toggleSwitched) { _isOn in
                                        item.toggleAction?(_isOn)
                                        withAnimation {
                                            if item.subtitleButton != nil {
                                                showSubtitleButton = _isOn
                                                viewModel.updateSize = true
                                            }
                                        }
                                    }.frame(alignment: .trailing)
                            }
                        }
                    } else {
                        Text(item.title)
                            .font(BeamFont.regular(size: 13).swiftUI)
                            .foregroundColor(isEnabled ? BeamColor.Generic.text.swiftUI : BeamColor.LightStoneGray.swiftUI)
                    }
                    if let subtitle = item.subtitle, item.type != .itemWithToggle {
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
                if let subtitleButton = item.subtitleButton, showSubtitleButton {
                    MinimalButton(customTextView: (Text(subtitleButton) + Text(Image("editor-url").renderingMode(.template))), hoverUnderline: true,
                                           font: BeamFont.regular(size: 11).swiftUI, foregroundColor: BeamColor.Corduroy.swiftUI, secondaryColor: BeamColor.Niobium.swiftUI) {
                        if let url = URL(string: subtitleButton), let state = AppDelegate.main.windows.first?.state {
                            state.mode = .web
                            _ = state.createTab(withURLRequest: URLRequest(url: url.urlWithScheme), originalQuery: nil)
                        }
                    }.frame(height: 13)
                        .transition(transitionInOutHiddenView)
                }

            }.padding(.vertical, BeamSpacing._40)
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
    @Published var forcedWidth: CGFloat?
    var onSelectMenuItem: (() -> Void)?
    @Published var updateSize: Bool = false
    // SubMenu
    var hideSubMenu: (() -> Void)?
    var subMenuIsShown: Bool = false
}

struct ContextMenuView: View {

    @ObservedObject var viewModel: ContextMenuViewModel
    static let standardItemHeight: CGFloat = 24
    static let subtitleButtonItemHeight: CGFloat = 47
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
            if item.subtitleButton != nil, item.showSubtitleButton {
                return result + ContextMenuView.subtitleButtonItemHeight + spacing
            }
            itemsNeedLargeWidth = itemsNeedLargeWidth || item.subtitle != nil || item.icon != nil && item.type != .itemWithDisclosure
            return result + ContextMenuView.standardItemHeight + spacing
        }
        let width = itemsNeedLargeWidth ? self.largeWidth : self.defaultWidth
        return CGSize(width: width, height: height)
    }

    @State private var hoveringIndex: Int?
    var onHoverSubMenu: ((ContextMenuItem) -> Void)?

    var body: some View {
        var computedSize = Self.idealSizeForItems(viewModel.items)
        if let forcedWidth = viewModel.forcedWidth, !viewModel.sizeToFit {
            computedSize.width = forcedWidth
        }
        return ZStack {
            FormatterViewBackground {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(viewModel.items.enumerated()), id: \.1.id) { index, item in
                        let isSelected = viewModel.selectedIndex == index
                        if item.type == .separator {
                            Separator(horizontal: true)
                        } else {
                            ContextMenuItemView(viewModel: viewModel, item: item, highlight: isSelected, toggleSwitched: item.isToggleOn, showSubtitleButton: item.showSubtitleButton)
                                .if(item.type != .itemWithToggle && item.type != .itemWithDisclosure, transform: { view in
                                    view
                                        .disabled(item.action == nil)
                                        .onTapGesture {
                                            item.action?()
                                            viewModel.onSelectMenuItem?()
                                        }
                                })
                                .onHoverOnceVisible { hovering in
                                    if isSelected && !hovering && hoveringIndex == index {
                                        viewModel.selectedIndex = nil
                                    } else if hovering {
                                        if item.action != nil {
                                            viewModel.selectedIndex = index
                                        }
                                        // SubMenu Handling
                                        if item.type == .itemWithDisclosure,
                                            item.subMenuModel != nil,
                                            !viewModel.subMenuIsShown {
                                            self.onHoverSubMenu?(item)
                                        }
                                        if item.type != .itemWithDisclosure,
                                           viewModel.subMenuIsShown {
                                            viewModel.hideSubMenu?()
                                        }
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
        ContextMenuItem(title: "Remove Link", action: { }),
        ContextMenuItem(title: "Toggle", subtitle: "switch", type: .itemWithToggle, action: nil, isToggleOn: false, toggleAction: { _ in }),
        ContextMenuItem(title: "Disclosure", icon: "editor-arrow_right", iconPlacement: ContextMenuItem.IconPlacement.trailing, iconSize: 16, iconColor: BeamColor.AlphaGray, type: .itemWithDisclosure, action: nil, subMenuModel: subModel)
    ]

    private static var model: ContextMenuViewModel {
        let model = ContextMenuViewModel()
        model.items = Self.items
        model.visible = true
        model.sizeToFit = true
        model.containerSize = CGSize(width: 200, height: 200)
        return model
    }

    private static var subModel: ContextMenuViewModel {
        let model = ContextMenuViewModel()
        model.items = [ContextMenuItem(title: "Open Link", action: { }),
                               ContextMenuItem.separator(),
                               ContextMenuItem(title: "Copy Link", action: { })]
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
