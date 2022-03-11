import SwiftUI

struct FloatingToolbar<Content: View>: View {

    var body: some View {
        HStack(spacing: spacing) {
            content
        }
        .padding(.leading, contentLeadingPadding)
        .padding(.trailing, contentTrailingPadding)
        .padding(.vertical, 8)
        .frame(width: contentWidth, height: 36)
        .background(backgroundView)
        .cursorOverride(.arrow)
    }

    private let spacing: CGFloat
    private let contentLeadingPadding: CGFloat
    private let contentTrailingPadding: CGFloat
    private let contentWidth: CGFloat?
    private let content: Content

    private let cornerRadius: CGFloat = 10

    private let strokeColor = BeamColor.combining(
        lightColor: .From(color: .black, alpha: 0.1),
        darkColor: .From(color: .white, alpha: 0.3)
    )

    private let backgroundColor = BeamColor.combining(
        lightColor: .Generic.background,
        darkColor: .Mercury
    )

    private let shadowColor = BeamColor.combining(
        lightColor: .From(color: .black, alpha: 0.16),
        darkColor: .From(color: .black, alpha: 0.7)
    )

    private var backgroundView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(strokeColor.swiftUI, lineWidth: 1)

            RoundedRectangle(cornerRadius: cornerRadius)
                .foregroundColor(backgroundColor.swiftUI)
                .shadow(color: shadowColor.swiftUI, radius: 13, x: 0, y: 11)
        }
    }

    init(
        spacing: CGFloat = 10,
        contentLeadingPadding: CGFloat = 12,
        contentTrailingPadding: CGFloat = 10,
        contentWidth: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.contentLeadingPadding = contentLeadingPadding
        self.contentTrailingPadding = contentTrailingPadding
        self.contentWidth = contentWidth
        self.content = content()
    }

}

extension ButtonLabelStyle {

    static func floatingToolbarButtonLabelStyle() -> ButtonLabelStyle {
        var style = ButtonLabelStyle()
        style.foregroundColor = BeamColor.LightStoneGray.swiftUI
        style.activeForegroundColor = BeamColor.Niobium.swiftUI
        style.hoveredBackgroundColor = nil
        style.activeBackgroundColor = BeamColor.Mercury.swiftUI
        return style
    }

}
