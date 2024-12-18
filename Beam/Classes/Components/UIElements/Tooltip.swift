//
//  Tooltip.swift
//  Beam
//
//  Created by Remi Santos on 20/09/2021.
//

import SwiftUI

struct Tooltip: View {
    var title: LocalizedStringKey?
    var icon: String?
    var subtitle: LocalizedStringKey?

    private var foregroundColor: Color {
        BeamColor.Corduroy.swiftUI
    }
    private var shadowColor: Color {
        Color(NSColor(withLightColor: NSColor.black.withAlphaComponent(0.08),
                      darkColor: NSColor.black.withAlphaComponent(0.24)))
    }

    /// basic height when there's one line of text. To use for positioning
    static let defaultHeight: CGFloat = 23
    static let defaultTransition = AnyTransition.asymmetric(insertion: AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)),
                                                            removal: AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.08)))

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                if let icon = icon {
                    Icon(name: icon, color: foregroundColor)
                        .blendModeLightMultiplyDarkScreen()
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

    var title: LocalizedStringKey
    var alignment: Alignment = .bottom
    private let tooltipMargin = BeamSpacing._100
    private let showDelay = 1300 // 1.3s just like Apple's macOS button tooltips
    private class ViewModel: ObservableObject {
       weak var hoverDispatchWorkItem: DispatchWorkItem?
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

    private func renderTooltip(with containerGeometry: GeometryProxy) -> some View {
        Tooltip(title: title)
            .fixedSize()
            .background(GeometryReader {
                Color.clear.preference(key: TooltipFrameKey.self, value: $0.frame(in: .global))
            })
            .onPreferenceChange(TooltipFrameKey.self) { tooltipFrame in
                let tooltipSize = tooltipFrame?.size ?? .zero
                var offset = CGSize(width: 0, height: 0)
                if alignment.vertical == .top {
                    offset.height = -tooltipSize.height
                } else if alignment.vertical == .bottom {
                    offset.height = tooltipSize.height
                }
                if alignment.horizontal == .leading {
                    offset.width = -tooltipSize.width
                } else if alignment.horizontal == .trailing {
                    offset.width = tooltipSize.width
                }
                let parentFrame = containerGeometry.frame(in: .global)
                let tooltipMaxX = parentFrame.midX + tooltipSize.width / 2 + tooltipMargin
                let tooltipMinX = parentFrame.midX - tooltipSize.width / 2 - tooltipMargin
                if tooltipMaxX > windowFrame.width {
                    offset.width = windowFrame.width - tooltipMaxX
                } else if tooltipMinX < 0 {
                    offset.width = parentFrame.minX
                }
                tooltipOffset = offset
            }
            .transition(
                .opacity.combined(with: .animatableOffset(offset: animationOffset))
                    .animation(BeamAnimation.easeInOut(duration: 0.15)))
            .offset(tooltipOffset)
    }

    private var animationOffset: CGSize {
        if alignment.vertical == .top {
            return CGSize(width: 0, height: 5)
        }
        if alignment.vertical == .bottom {
            return CGSize(width: 0, height: -5)
        }
        if alignment.horizontal == .leading {
            return CGSize(width: 5, height: 0)
        }
        if alignment.horizontal == .trailing {
            return CGSize(width: -5, height: 0)
        }
        return CGSize.zero
    }

    private var overlayProxy: some View {
        GeometryReader { proxy in
            ZStack { }
            .overlay(showTooltip ? renderTooltip(with: proxy) : nil, alignment: alignment)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        }
    }

    func body(content: Content) -> some View {
        content
            .overlay(overlayProxy, alignment: alignment)
            .onHover { isHovering = $0 }
            .onTouchDown { touching in
                guard touching else { return }
                viewModel.hoverDispatchWorkItem?.cancel()
                showTooltip = false
            }
    }

    private struct TooltipFrameKey: FramePreferenceKey { }
}

extension View {
    func tooltipOnHover(_ title: LocalizedStringKey, alignment: Alignment = .bottom) -> some View {
        modifier(TooltipHoverModifier(title: title, alignment: alignment))
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

struct ToolTipFormatter: View {
    var text: String
    var size: CGSize

    var body: some View {
        FormatterViewBackground(boxCornerRadius: 4, shadowOpacity: 0) {
            Tooltip(title: LocalizedStringKey(text))
                .background(Color.clear)
                .frame(width: size.width, height: size.height, alignment: .center)
        }
    }
}
