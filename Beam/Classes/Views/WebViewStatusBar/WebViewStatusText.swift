import SwiftUI

struct WebViewStatusText: View {

    var body: some View {
        StyledText(verbatim: text)
            .style(.font(emphasizedTextFont), ranges: emphasizedRanges(for:))
            .style(.foregroundColor(emphasizedTextColor), ranges: emphasizedRanges(for:))
            .font(textFont)
            .foregroundColor(textColor)
            .lineLimit(1)
            .blendModeLightMultiplyDarkScreen()
            .animation(nil)
            .accessibilityIdentifier("webview-status-text")
    }

    private let text: String
    private let emphasizedText: String?

    private let textFont = BeamFont.regular(size: 11).swiftUI
    private let textColor = BeamColor.WebViewStatusBar.text.swiftUI
    private let emphasizedTextFont = BeamFont.medium(size: 11).swiftUI
    private let emphasizedTextColor = BeamColor.WebViewStatusBar.emphasizedText.swiftUI

    init(mouseHoveringLocation: MouseHoveringLocation) {
        switch mouseHoveringLocation {
        case .none:
            text = ""
            emphasizedText = nil

        case .link(let url, let opensInNewTab):
            text = Self.linkHoverText(url: url.rootPathRemoved, opensInNewTab: opensInNewTab)
            emphasizedText = url.schemeAndHost
        }
    }

}

extension WebViewStatusText {

    private func emphasizedRanges(for text: String) -> [Range<String.Index>] {
        guard let emphasizedText = emphasizedText else { return [] }
        return text.ranges(of: emphasizedText)
    }

    private static func linkHoverText(url: URL, opensInNewTab: Bool) -> String {
        if opensInNewTab {
            return "Open \"%@\" in a new tab".localizedStringWith(
                comment: "Status bar message when mouse hovering over a link",
                url.absoluteString
            )
        } else {
            return url.absoluteString
        }
    }

}
