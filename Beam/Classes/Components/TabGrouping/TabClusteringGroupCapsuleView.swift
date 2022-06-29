//
//  TabClusteringGroupCapsuleView.swift
//  Beam
//
//  Created by Remi Santos on 10/05/2022.
//

import SwiftUI

struct TabClusteringGroupCapsuleView: View {
    @Environment(\.colorScheme) var colorScheme

    var title: String
    var color: TabGroupingColor
    var collapsed = false
    var itemsCount: Int = 0
    var onTap: ((Bool, NSEvent?) -> Void)?

    @State private var isHovering = false
    @State private var isTouchDown = false

    private var mainColor: Color {
        color.mainColor?.swiftUI ?? .clear
    }

    private var borderColor: Color {
        var opacity: Double = 0
        if colorScheme == .dark {
            opacity = isTouchDown ? 0.5 : (isHovering ? 0.36 : 0.24)
        } else {
            opacity = isTouchDown ? 0.44 : (isHovering ? 0.3 : 0.2)
        }
        return mainColor.opacity(opacity)
    }
    private var textColor: Color {
        color.textColor?.swiftUI ?? .white
    }

    private var displayedText: String {
        if title.isEmpty && collapsed && itemsCount > 0 {
            return "\(itemsCount)"
        }
        return title
    }

    @ViewBuilder
    private var interactionOverlay: some View {
        if isTouchDown || isHovering {
            let baseColor = colorScheme == .dark ? Color.white : Color.black
            let hoverOpacity = colorScheme == .dark ? 0.25 : 0.1
            let touchOpacity = colorScheme == .dark ? 0.32 : 0.15
            baseColor.opacity(isTouchDown ? touchOpacity : hoverOpacity)
        }
    }

    @ViewBuilder
    private var renderTitle: some View {
        Group {
            let displayedText = displayedText
            if title.isEmpty && collapsed && itemsCount >= 1000 {
                Image("nav-pivot-infinite")
                    .resizable()
                    .scaledToFill()
                    .foregroundColor(textColor)
                    .frame(width: 12, height: 6)
            } else {
                Text(displayedText)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, displayedText.isEmpty ? 0 : BeamSpacing._50)
        .frame(minWidth: 16, maxWidth: .infinity)
        .font(BeamFont.medium(size: 11).swiftUI)
    }

    var body: some View {
        renderTitle
            .foregroundColor(textColor)
            .background(
                mainColor
                    .overlay(interactionOverlay)
                    .cornerRadius(3)
                    .blendMode(forLightScheme: .normal, forDarkScheme: .screen)
            )
            .padding(3)
            .background(GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 6)
                    .fill(borderColor)
                    .frame(width: proxy.size.width + 1, height: proxy.size.height + 1)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .mask(
                        Rectangle()
                            .frame(width: proxy.size.width + 1, height: proxy.size.height + 1)
                            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .padding(3)
                                    .blendMode(.destinationOut) // reverse mask
                            )
                    )

                    .blendMode(forLightScheme: .normal, forDarkScheme: .screen)
            })
            .onHover { isHovering = $0 }
            .onTouchDown { isTouchDown = $0 }
            .simultaneousGesture(TapGesture().onEnded({ _ in
                // We can't use the ClickCatchingView for the left click because of the parent drag gesture.
                // But we still need it for right click and control-click, which could end up here.
                guard NSApp.currentEvent?.isRightClick != true else { return }
                onTap?(false, nil)
            }))
            .background(ClickCatchingView(onRightTap: { event in
                onTap?(true, event)
            }))
    }
}

struct TabViewGroupUnderline: View {
    @Environment(\.colorScheme) var colorScheme
    var color: TabGroupingColor
    var isBeginning: Bool = true
    var isEnd: Bool = true
    private let height: CGFloat = 1.5
    var body: some View {
        let mainColor = color.mainColor?.swiftUI ?? .clear
        HStack(spacing: 0) {
            if isBeginning {
                Circle().fill(mainColor)
                    .frame(width: height)
            }
            mainColor
                .padding(.leading, isBeginning ? -height/2 : 0)
                .padding(.trailing, isEnd ? -height/2 : 0)
            if isEnd {
                Circle().fill(mainColor)
                    .frame(width: height)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .offset(x: 0, y: 4)
    }
}

struct TabClusteringGroupCapsuleView_Previews: PreviewProvider {

    static func renderGroup(_ title: String, color: TabGroupingColor, collapsed: Bool = false, count: Int = 0) -> some View {
        TabClusteringGroupCapsuleView(title: title, color: color,
                                      collapsed: collapsed, itemsCount: count)
            .fixedSize()
            .overlay(
                TabViewGroupUnderline(color: color),
                alignment: .bottom
            )
    }
    static var previews: some View {
        HStack {
            renderGroup("Group", color: TabGroupingColor(designColor: .yellow))
            renderGroup("", color: TabGroupingColor(designColor: .green), collapsed: false, count: 9)
            renderGroup("", color: TabGroupingColor(designColor: .green), collapsed: true, count: 9)
            renderGroup("", color: TabGroupingColor(designColor: .blue), collapsed: true, count: 909)
            renderGroup("", color: TabGroupingColor(designColor: .birgit), collapsed: true, count: 1009)
        }.padding()
    }
}
