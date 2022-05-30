//
//  TabClusteringNameColorPickerView.swift
//  Beam
//
//  Created by Remi Santos on 17/05/2022.
//

import SwiftUI

struct TabClusteringNameColorPickerView: View {
    @State var groupName: String = ""
    @State var selectedColorIndex: Int = 0 {
        didSet {
            onChange?((groupName, selectedTabGroupingColor))
        }
    }
    var onChange: (((name: String, color: TabGroupingColor?)) -> Void)?

    @State private var isEditing = false
    @State private var isPickingColor = false

    private let colors = TabGroupingColor.userColors
    private var selectedTabGroupingColor: TabGroupingColor? {
        TabGroupingColor(userColorIndex: selectedColorIndex)
    }
    private var selectedColor: BeamColor? {
        guard selectedColorIndex < colors.count else { return nil }
        return colors[selectedColorIndex]
    }

    private struct ColorPickerItem: View {
        var color: Color
        var selected = false

        private let size: CGFloat = 16
        private let strokeWidth: CGFloat = 1.5
        var body: some View {
            ZStack {
                Circle()
                    .stroke(color, lineWidth: strokeWidth)
                    .frame(width: size - strokeWidth/2, height: size - strokeWidth/2)
                    .opacity(selected ? 1 : 0)
                Circle()
                    .fill(color)
                    .padding(selected ? 3 : 0)
            }
            .frame(width: size, height: size)
        }
    }

    private var colorPicker: some View {
        HStack(spacing: 0) {
            ForEach(Array(colors.enumerated()), id: \.0) { (index, color) in
                if isPickingColor || index == selectedColorIndex {
                    ZStack {
                        ColorPickerItem(color: color.swiftUI, selected: index == selectedColorIndex && isPickingColor)
                    }
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        selectedColorIndex = index
                        isPickingColor.toggle()
                    }
                }
            }
        }
        .animation(BeamAnimation.easingBounce(duration: 0.2), value: isPickingColor)
    }

    var body: some View {
        HStack {
            if !isPickingColor {
                let selectedColor = selectedColor?.nsColor
                BeamTextField(text: $groupName, isEditing: $isEditing,
                              placeholder: "Name this group",
                              font: BeamFont.regular(size: 13).nsFont,
                              textColor: BeamColor.Generic.text.nsColor,
                              placeholderColor: BeamColor.Generic.placeholder.nsColor,
                              selectedRangeColor: selectedColor,
                              caretColor: selectedColor,
                              onCommit: { _ in
                    onChange?((groupName, selectedTabGroupingColor))
                    isEditing = false
                }, onEscape: {
                    isEditing = false
                })
                .transition(.opacity.animation(BeamAnimation.easingBounce(duration: 0.2)))
            }
            if isEditing && !groupName.isEmpty {
                Icon(name: "shortcut-return", width: 12, color: BeamColor.LightStoneGray.swiftUI)
            } else {
                colorPicker
                    .frame(maxWidth: isPickingColor ? .infinity : 16)
            }
        }
        .padding(.horizontal, BeamSpacing._50)
        .frame(maxHeight: .infinity)
    }
}

struct TabClusteringNameColorPickerView_Previews: PreviewProvider {
    static var previews: some View {
        TabClusteringNameColorPickerView()
            .frame(width: 230, height: 24)
            .background(BeamColor.Generic.background.swiftUI)
            .padding()
    }
}
