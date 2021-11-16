//
//  Tooltip.swift
//  Beam
//
//  Created by Remi Santos on 20/09/2021.
//

import SwiftUI

struct Tooltip: View {
    var title: String?
    var icon: String?
    var subtitle: String?

    private var foregroundColor: Color {
        BeamColor.Corduroy.swiftUI
    }
    private var shadowColor: Color {
        Color(NSColor(withLightColor: NSColor.black.withAlphaComponent(0.08),
                      darkColor: NSColor.black.withAlphaComponent(0.24)))
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                if let icon = icon {
                    Icon(name: icon, size: 16, color: foregroundColor)
                }
                if let title = title {
                    Text(title)
                        .font(BeamFont.regular(size: 12).swiftUI)
                        .foregroundColor(foregroundColor)
                }
            }
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(BeamFont.regular(size: 12).swiftUI)
                    .foregroundColor(BeamColor.AlphaGray.swiftUI)
            }
        }
        .padding(.vertical, BeamSpacing._40)
        .padding(.horizontal, BeamSpacing._60)
        .background(BeamColor.Nero.swiftUI)
        .cornerRadius(3)
        .compositingGroup()
        .shadow(color: shadowColor, radius: 4, x: 0, y: 0)
    }
}

struct Tooltip_Previews: PreviewProvider {
    static var previews: some View {
        Group {
                VStack(spacing: 8) {
                    Tooltip(title: "Label", subtitle: "⌘⌥⇧⌃⇪⌥⇧⌘⇪⌃")
                    Tooltip(title: "Label")
                    Tooltip(title: "Label", icon: "tool-keep", subtitle: "⌘⌥⇧⌃⇪")
                    Tooltip(title: "Label", icon: "tool-keep")
                }
                .padding(20)
                .background(BeamColor.Generic.background.swiftUI)
        }
        Group {
            VStack(spacing: 8) {
                Tooltip(title: "Label", subtitle: "⌘⌥⇧⌃⇪⌥⇧⌘⇪⌃")
                Tooltip(title: "Label")
                Tooltip(title: "Label", icon: "tool-keep", subtitle: "⌘⌥⇧⌃⇪")
                Tooltip(title: "Label", icon: "tool-keep")
            }
            .padding(20)
            .background(BeamColor.Generic.background.swiftUI)
            .preferredColorScheme(.dark)
        }
    }
}
