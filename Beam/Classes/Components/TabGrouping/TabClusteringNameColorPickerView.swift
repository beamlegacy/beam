//
//  TabClusteringNameColorPickerView.swift
//  Beam
//
//  Created by Remi Santos on 17/05/2022.
//

import SwiftUI

struct TabClusteringNameColorPickerView: View {
    @State var groupName: String = ""
    var initialColor: TabGroupingColor

    @State private var selectedDesignColor: TabGroupingColor.DesignColor? {
        didSet {
            onChange?((groupName, selectedTabGroupingColor))
        }
    }
    var onChange: (((name: String, color: TabGroupingColor?)) -> Void)?
    var onFinish: (() -> Void)?

    @State private var isEditing = false
    @State private var isPickingColor = false

    private let colors = TabGroupingColor.DesignColor.allCases
    private var selectedTabGroupingColor: TabGroupingColor? {
        TabGroupingColor(designColor: selectedDesignColor)
    }

    private var textFieldTintColor: NSColor {
        selectedDesignColor?.color.nsColor ?? initialColor.mainColor?.nsColor ?? TabGroupingColor.DesignColor.red.color.nsColor
    }

    private struct ColorPickerItem: View {
        var color: Color
        var selected = false

        private let size: CGFloat = 16
        private let padding: CGFloat = 1
        private let strokeWidth: CGFloat = 1.5
        var body: some View {
            ZStack {
                Circle()
                    .strokeBorder(color, lineWidth: strokeWidth)
                    .opacity(selected ? 1 : 0)
                    .padding(padding)
                Circle()
                    .fill(color)
                    .padding(selected ? 4 : padding)
            }
            .frame(width: size, height: size)
        }
    }

    private var colorPicker: some View {
        HStack(spacing: 0) {
            ForEach(colors) { color in
                let selected = color == selectedDesignColor
                if isPickingColor || selected {
                    ZStack {
                        ColorPickerItem(color: color.color.swiftUI, selected: selected && isPickingColor)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDesignColor = color
                        isPickingColor.toggle()
                    }
                }
            }
            if !isPickingColor && selectedDesignColor == nil, let initialColor = initialColor.mainColor?.swiftUI {
                ZStack {
                    ColorPickerItem(color: initialColor, selected: false)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    isPickingColor.toggle()
                }
            }
        }
        .animation(BeamAnimation.easingBounce(duration: 0.2), value: isPickingColor)
        .onAppear {
            if let initialDesignColor = initialColor.designColor {
                selectedDesignColor = initialDesignColor
            }
        }
    }

    var body: some View {
        HStack {
            if !isPickingColor {
                let tintColor = textFieldTintColor
                BeamTextField(text: $groupName, isEditing: $isEditing,
                              placeholder: "Name this group",
                              font: BeamFont.regular(size: 13).nsFont,
                              textColor: BeamColor.Generic.text.nsColor,
                              placeholderColor: BeamColor.Generic.placeholder.nsColor,
                              selectedRangeColor: tintColor.withAlphaComponent(0.14),
                              caretColor: tintColor,
                              caretWidth: 2.0,
                              onCommit: { _ in
                    onChange?((groupName, selectedTabGroupingColor))
                    onFinish?()
                }, onEscape: {
                    onFinish?()
                })
                .accessibility(identifier: "TabGroupNameTextField")
                .transition(.opacity.animation(BeamAnimation.easingBounce(duration: 0.2)))
                .blendModeLightMultiplyDarkScreen()
            }
            if isEditing && !groupName.isEmpty {
                Icon(name: "shortcut-return", width: 12, color: BeamColor.LightStoneGray.swiftUI)
            } else {
                colorPicker
                    .accessibility(identifier: "TabGroupColorPicker")
                    .frame(maxWidth: isPickingColor ? .infinity : 16)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

struct TabClusteringNameColorPickerView_Previews: PreviewProvider {
    static var previews: some View {
        TabClusteringNameColorPickerView(initialColor: TabGroupingColor(designColor: .cyan))
            .frame(width: 230, height: 24)
            .background(BeamColor.Generic.background.swiftUI)
            .padding()
    }
}
