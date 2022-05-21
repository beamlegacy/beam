//
//  DropDownButton.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 02/05/2022.
//

import SwiftUI

struct DropDownButton: View {
    private static let dropDownMenuIdentifier = "DropDownMenu"
    private var verticalPadding = 2.5
    @State private var forceClickedState: Bool = false

    var parentWindow: NSWindow?
    var items: [ContextMenuItem]
    var customStyle: ButtonLabelStyle?
    var anchorPoint: Edge.Set = [.bottom, .trailing]

    init(parentWindow: NSWindow?, items: [ContextMenuItem], customStyle: ButtonLabelStyle?) {
        self.parentWindow = parentWindow
        self.items = items
        self.customStyle = customStyle
        self.customStyle?.horizontalPadding = 1
    }

    var body: some View {
        Color.clear.overlay(
            GeometryReader { proxy in
                HStack {
                    ButtonLabel(icon: "editor-arrow_down", state: forceClickedState ? .clicked : .normal, customStyle: customStyle ?? ButtonLabelStyle()) {
                        forceClickedState = true
                        showDropDownContextMenu(geometryProxy: proxy, with: items)
                    }
                }.frame(width: proxy.size.width, height: proxy.size.height)
            }
        ).frame(width: 18, height: 22)
    }

    func showDropDownContextMenu(geometryProxy: GeometryProxy, with items: [ContextMenuItem]) {
        guard let window = self.parentWindow else { return }
        let origin = geometryProxy.safeTopLeftGlobalFrame(in: window).origin
        let point = origin.flippedPointToTopLeftOrigin(in: window)
        var finalPoint: CGPoint = window.parent?.convertPoint(fromScreen: window.convertPoint(toScreen: point) ) ?? point

        CustomPopoverPresenter.shared.dismissPopovers(key: Self.dropDownMenuIdentifier)
        let menuView = ContextMenuFormatterView(key: Self.dropDownMenuIdentifier, items: items, direction: .bottom, sizeToFit: false, origin: finalPoint, canBecomeKey: true) {
            CustomPopoverPresenter.shared.dismissPopovers(key: Self.dropDownMenuIdentifier)
        } onClosing: {
            forceClickedState = false
            CustomPopoverPresenter.shared.dismissPopovers(key: Self.dropDownMenuIdentifier)
        }

        if anchorPoint.contains(.top) {
            finalPoint.y += menuView.idealSize.height + verticalPadding
        }

        if anchorPoint.contains(.bottom) {
            finalPoint.y -= geometryProxy.size.height + verticalPadding
        }

        if anchorPoint.contains(.trailing) {
            finalPoint.x -= menuView.idealSize.width - geometryProxy.size.width
        }

        menuView.origin = finalPoint
        CustomPopoverPresenter.shared.presentFormatterView(menuView, atPoint: finalPoint)
    }
}

struct DropDownButton_Previews: PreviewProvider {
    private static var publishedContextItems = [
        ContextMenuItem(title: "Add to profile", type: .itemWithToggle, action: nil, toggleAction: { _ in }),
        ContextMenuItem(title: "Share", icon: "editor-arrow_right", iconPlacement: ContextMenuItem.IconPlacement.trailing, iconSize: 16, iconColor: BeamColor.AlphaGray, type: .itemWithDisclosure, action: nil),
        ContextMenuItem.separator(),
        ContextMenuItem(title: "Unpublish", action: { })
    ]

    static var previews: some View {
        DropDownButton(parentWindow: nil, items: publishedContextItems, customStyle: nil)
    }
}
