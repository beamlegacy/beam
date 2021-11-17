//
//  AutocompleteItem.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import SwiftUI

struct AutocompleteItem: View {

    @State var item: AutocompleteResult
    let selected: Bool
    var disabled: Bool = false
    var displayIcon: Bool = true
    var alwaysHighlightCompletingText: Bool = false
    var allowCmdEnter: Bool = true

    var colorPalette: AutocompleteItemColorPalette = Self.defaultColorPalette
    var additionalLeadingPadding: CGFloat = 0

    @State private var isTouchDown = false

    @State private var favicon: NSImage?
    var backgroundColor: Color {
        guard !isTouchDown else {
            return colorPalette.touchdownBackgroundColor.swiftUI
        }
        return colorPalette.selectedBackgroundColor.swiftUI.opacity(selected ? 1.0 : 0.0)
    }

    func iconNameSource(_ source: AutocompleteResult.Source) -> String {
        switch item.source {
        case .history:
            return "field-history"
        case .autocomplete, .url, .topDomain:
            return "field-search"
        case .createCard:
            return "field-card_new"
        case .note:
            return "field-card"
        }
    }

    private var isUrlWithTitle: Bool {
        item.source == .url && item.information != nil
    }

    private var textColor: Color {
        disabled ? BeamColor.LightStoneGray.swiftUI : colorPalette.textColor.swiftUI
    }
    private let secondaryTextColor = BeamColor.Autocomplete.subtitleText.swiftUI
    private let subtitleLinkColor = BeamColor.Autocomplete.link.swiftUI
    private var mainTextColor: Color {
        if item.source == .topDomain ||
            (item.source == .url && !isUrlWithTitle) {
            return subtitleLinkColor
        }
        return textColor
    }
    private var informationColor: Color {
        switch item.source {
        case .history, .url:
            return subtitleLinkColor
        default:
            return colorPalette.informationTextColor.swiftUI
        }
    }

    private func highlightedTextRanges(in text: String) -> [Range<String.Index>] {
        guard let completingText = item.completingText else {
            return []
        }
        if alwaysHighlightCompletingText || [.autocomplete, .history, .url, .topDomain].contains(item.source) {
            return text.ranges(of: completingText, options: .caseInsensitive)
        }
        if let firstRange = text.range(of: completingText, options: .caseInsensitive), firstRange.lowerBound == text.startIndex {
            return [firstRange.upperBound..<text.endIndex]
        }
        return []
    }

    var mainText: String {
        if isUrlWithTitle, let information = item.information {
            return information
        }
        return item.text
    }

    var secondaryText: String? {
        isUrlWithTitle ? item.text : item.information
    }

    var body: some View {
        HStack(spacing: 8) {
            if displayIcon {
                if let icon = favicon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 16, maxHeight: 16)
                } else {
                    Icon(name: item.source.iconName, size: 16, color: secondaryTextColor)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                ZStack {
                    StyledText(verbatim: mainText)
                        .style(.font(BeamFont.semibold(size: 13).swiftUI), ranges: highlightedTextRanges)
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(mainTextColor)
                }
                .layoutPriority(10)
                if let info = secondaryText {
                    HStack {
                        StyledText(verbatim: " – \(info)")
                            .style(.font(BeamFont.semibold(size: 13).swiftUI), ranges: highlightedTextRanges)
                            .font(BeamFont.regular(size: 13).swiftUI)
                            .foregroundColor(informationColor)
                    }
                    .layoutPriority(0)
                }

                if PreferencesManager.showOmnibarScoreSection, let score = item.score {
                    Spacer()
                    StyledText(verbatim: " Score: \(score)")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.CharmedGreen.swiftUI)
                }
            }
            Spacer(minLength: 0)
            if item.source == .createCard && allowCmdEnter {
                Icon(name: "shortcut-cmd+return", size: 12, color: secondaryTextColor, alignment: .trailing)
            } else {
                Icon(name: "shortcut-return", size: 12, color: selected ? secondaryTextColor : .clear, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, BeamSpacing._80)
        .padding(.horizontal, BeamSpacing._120)
        .padding(.leading, additionalLeadingPadding)
        .background(backgroundColor)
        .onTouchDown { t in
            isTouchDown = t && !disabled
        }
        .onAppear {
            if let url = item.url {
                FaviconProvider.shared.favicon(fromURL: url, cacheOnly: item.source != .topDomain) { (image) in
                    self.favicon = image
                }
            }
        }
        .accessibilityElement()
        .accessibility(identifier: "autocompleteResult\(selected ? "-selected":"")-\(item.text)-\(item.source)")
    }
}

struct AutocompleteItemColorPalette {
    var textColor = BeamColor.Generic.text
    var informationTextColor = BeamColor.Autocomplete.subtitleText
    var selectedBackgroundColor = BeamColor.Autocomplete.selectedBackground
    var touchdownBackgroundColor = BeamColor.Autocomplete.clickedBackground
}

extension AutocompleteItem {
    static let defaultColorPalette = AutocompleteItemColorPalette()
}

struct AutocompleteItem_Previews: PreviewProvider {
    static let items = [
        AutocompleteResult(text: "James Dean", source: .createCard, information: "Create Card"),
        AutocompleteResult(text: "James Dean", source: .note, completingText: "Ja"),
        AutocompleteResult(text: "James Dean", source: .autocomplete, information: "Google Search"),
        AutocompleteResult(text: "jamesdean.com", source: .url),
        AutocompleteResult(text: "James Dean", source: .history, information: "https://wikipedia.com/James+Dean")
    ]
    static let selectedIndex = 3
    static var previews: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.0) { index, item in
                AutocompleteItem(item: item, selected: index == selectedIndex)
                    .frame(width: 300, height: 32)
            }
        }.padding(.vertical)
    }
}
