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
    private var mainColor: Color {
        color.mainColor(isDarkMode: colorScheme == .dark)
    }
    private var borderColor: Color {
        mainColor.opacity(colorScheme == .dark ? 0.24 : 0.2)
    }
    private var textColor: Color {
        color.textColor(isDarkMode: colorScheme == .dark)
    }

    private var renderTitle: some View {
        Text(title)
            .frame(height: 22)
            .frame(minWidth: 6, maxWidth: .infinity)
            .padding(.horizontal, title.isEmpty ? 0 : BeamSpacing._50)
            .font(BeamFont.medium(size: 11).swiftUI)
    }

    var body: some View {
        renderTitle
            .foregroundColor(textColor)
            .blendModeLightMultiplyDarkScreen(invert: true)
            .background(
                mainColor.cornerRadius(3)
                    .blendModeLightMultiplyDarkScreen()
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

                    .blendModeLightMultiplyDarkScreen()
            })
    }
}

struct TabViewGroupUnderline: View {
    @Environment(\.colorScheme) var colorScheme
    var color: TabGroupingColor
    var isBeginning: Bool = true
    var isEnd: Bool = true
    private let height: CGFloat = 1.5
    var body: some View {
        let mainColor = color.mainColor(isDarkMode: colorScheme == .dark)
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
    static var previews: some View {
        HStack {
            TabClusteringGroupCapsuleView(title: "Group", color: TabGroupingColor(userColorIndex: 1))
                .fixedSize()
                .overlay(
                    TabViewGroupUnderline(color: TabGroupingColor(userColorIndex: 1)),
                    alignment: .bottom
                )
            TabClusteringGroupCapsuleView(title: "", color: TabGroupingColor(userColorIndex: 2))
                .fixedSize()
                .overlay(
                    TabViewGroupUnderline(color: TabGroupingColor(userColorIndex: 2)),
                    alignment: .bottom
                )
        }
            .padding()
    }
}
