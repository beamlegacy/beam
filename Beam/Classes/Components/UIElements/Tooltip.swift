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
                    Icon(name: icon, color: foregroundColor)
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

struct TooltipHoverModifier: ViewModifier {
    @Environment(\.windowFrame) private var windowFrame

    var title: String
    private let tooltipMargin = BeamSpacing._100
    private let showDelay = 1500
    private class ViewModel: ObservableObject {
        var hoverDispatchWorkItem: DispatchWorkItem?
    }
    @State private var viewModel = ViewModel()
    @State private var showTooltip = false
    @State private var tooltipOffset: CGSize = .zero
    @State private var isHovering = false {
        didSet {
            viewModel.hoverDispatchWorkItem?.cancel()
            if isHovering {
                let workItem = DispatchWorkItem {
                    if self.isHovering == true {
                        showTooltip = true
                    }
                }
                viewModel.hoverDispatchWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(showDelay), execute: workItem)
            } else {
                showTooltip = isHovering
            }
        }
    }
    private var overlayProxy: some View {
        GeometryReader { proxy in
            ZStack {
                if showTooltip {
                    Tooltip(title: title)
                        .fixedSize()
                        .background(GeometryReader {
                            Color.clear.preference(key: TooltipSizeKey.self, value: $0.size)
                        })
                        .onPreferenceChange(TooltipSizeKey.self) { tooltipSize in
                            var offset = CGSize(width: 0, height: tooltipSize?.height ?? 0)
                            let parentFrame = proxy.frame(in: .global)
                            let tooltipMaxX = parentFrame.midX + (tooltipSize?.width ?? 0) / 2 + tooltipMargin
                            let tooltipMinX = parentFrame.midX - (tooltipSize?.width ?? 0) / 2 - tooltipMargin
                            if tooltipMaxX > windowFrame.width {
                                offset.width = windowFrame.width - tooltipMaxX
                            } else if tooltipMinX < 0 {
                                offset.width = parentFrame.minX
                            }
                            tooltipOffset = offset
                        }
                        .transition(
                            .opacity.combined(with: .animatableOffset(offset: CGSize(width: 0, height: -5)))
                                .animation(BeamAnimation.easeInOut(duration: 0.15)))
                        .offset(tooltipOffset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    func body(content: Content) -> some View {
        content
            .overlay(overlayProxy)
            .onHover { isHovering = $0 }
            .onTouchDown { touching in
                guard touching else { return }
                viewModel.hoverDispatchWorkItem?.cancel()
                showTooltip = false
            }
    }

    private struct TooltipSizeKey: PreferenceKey {
        static let defaultValue: CGSize? = nil
        static func reduce(value: inout CGSize?, nextValue: () -> CGSize?) {
            value = nextValue() ?? value
        }
    }
}

extension View {
    func tooltipOnHover(_ title: String) -> some View {
        modifier(TooltipHoverModifier(title: title))
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
