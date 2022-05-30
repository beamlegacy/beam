//
//  SidebarListPageButton.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 17/05/2022.
//

import SwiftUI

struct SidebarListPageButton: View {
    var iconName: String
    var text: String
    var isSelected = false
    var action: (() -> Void)?

    @State var isHovering: Bool = false
    @State var isPressed: Bool = false

    var body: some View {
        HStack(spacing: 6.0) {
            Icon(name: iconName, width: 12, color: foregroundColor)
            Text(text)
                .lineLimit(1)
            Spacer()
        }
        .foregroundColor(foregroundColor)
        .font(textFont)
        .padding(.horizontal, 8)
        .frame(width: 220, height: 30)
        .background(SidebarListBackground(isSelected: isSelected, isHovering: isHovering, isPressed: isPressed))
        .onTouchDown { isPressed = $0 }
        .onHover {
            isHovering = $0
            if !$0 {
                isPressed = false
            }
        }
        .if(action != nil) {
            $0.simultaneousGesture(TapGesture().onEnded {
                action?()
            })
        }
    }

    private var textFont: Font {
        isSelected ? BeamFont.medium(size: 12).swiftUI : BeamFont.regular(size: 12).swiftUI
    }

    private var foregroundColor: Color {
        BeamColor.Niobium.swiftUI
    }
}

struct SidebarListButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                SidebarListPageButton(iconName: "editor-journal", text: "Journal", isSelected: false, action: nil)
                SidebarListPageButton(iconName: "editor-journal", text: "Journal", isSelected: false, action: nil, isPressed: true)
                SidebarListPageButton(iconName: "editor-journal", text: "Journal", isSelected: false, action: nil, isHovering: true)
                SidebarListPageButton(iconName: "editor-journal", text: "Journal", isSelected: true, action: nil)
                SidebarListPageButton(iconName: "editor-journal", text: "Journal", isSelected: true, action: nil, isPressed: true)
                SidebarListPageButton(iconName: "editor-journal", text: "Journal", isSelected: true, action: nil, isHovering: true)
            }
            VStack {
                SidebarListPageButton(iconName: "editor-journal", text: "Journal", isSelected: false, action: nil)
                SidebarListPageButton(iconName: "editor-journal", text: "Journal", isSelected: false, action: nil, isPressed: true)
                SidebarListPageButton(iconName: "editor-journal", text: "Journal", isSelected: false, action: nil, isHovering: true)
                SidebarListPageButton(iconName: "editor-journal", text: "Journal", isSelected: true, action: nil)
                SidebarListPageButton(iconName: "editor-journal", text: "Journal", isSelected: true, action: nil, isPressed: true)
                SidebarListPageButton(iconName: "editor-journal", text: "Journal", isSelected: true, action: nil, isHovering: true)
            }.preferredColorScheme(.dark)
        }
    }
}
