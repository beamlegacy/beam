//
//  AutocompleteItem.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import SwiftUI

struct AutocompleteItemColorPalette {
    let selectedBackgroundColor: NSColor
    let touchdownBackgroundColor: NSColor
}

private let defaultColorPalette = AutocompleteItemColorPalette(selectedBackgroundColor: BeamColor.Autocomplete.selectedBackground.nsColor, touchdownBackgroundColor: BeamColor.Autocomplete.clickedBackground.nsColor)

struct AutocompleteItem: View {
    @State var item: AutocompleteResult
    let selected: Bool
    var displayIcon: Bool = true
    var colorPalette: AutocompleteItemColorPalette = defaultColorPalette
    @State private var isTouchDown = false

    @State private var favicon: NSImage?
    var backgroundColor: Color {
        guard !isTouchDown else {
            return Color(colorPalette.touchdownBackgroundColor)
        }
        return Color(colorPalette.selectedBackgroundColor).opacity(selected ? 1.0 : 0.0)
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

    private let textColor = BeamColor.Generic.text.swiftUI
    private let secondaryTextColor = BeamColor.Autocomplete.subtitleText.swiftUI
    private let subtitleLinkColor = BeamColor.Autocomplete.link.swiftUI
    private var informationColor: Color {
        switch item.source {
        case .history:
            return subtitleLinkColor
        case .createCard:
            return BeamColor.Autocomplete.newCardSubtitle.swiftUI
        default:
            return secondaryTextColor
        }
    }

    private func boldTextRanges(in text: String) -> [Range<String.Index>] {
        guard let completingText = item.completingText else {
            return []
        }
        if [.autocomplete, .history, .url].contains(item.source) {
            return text.ranges(of: completingText, options: .caseInsensitive)
        }
        if let firstRange = text.range(of: completingText, options: .caseInsensitive), firstRange.lowerBound == text.startIndex {
            return [firstRange.upperBound..<text.endIndex]
        }
        return []
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
                    StyledText(verbatim: item.text)
                        .style(.semibold(), ranges: boldTextRanges)
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(item.source == .url ? subtitleLinkColor : textColor)
                }
                .layoutPriority(10)
                if let info = item.information {
                    HStack {
                        StyledText(verbatim: " – \(info)")
                            .style(.semibold(), ranges: boldTextRanges)
                            .font(BeamFont.regular(size: 13).swiftUI)
                            .foregroundColor(informationColor)
                    }
                    .layoutPriority(0)
                }
            }
            if item.source == .createCard {
                Spacer()
                Icon(name: "shortcut-cmd+return", size: 12, color: secondaryTextColor)
            } else if selected {
                Spacer()
                Icon(name: "editor-format_enter", size: 12, color: secondaryTextColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, BeamSpacing._80)
        .padding(.horizontal, BeamSpacing._120)
        .background(backgroundColor)
        .onTouchDown { t in
            isTouchDown = t
        }
        .onAppear {
            if let url = item.url, item.source == .history {
                FaviconProvider.shared.imageForUrl(url, cacheOnly: true) { (image) in
                    self.favicon = image
                }
            }
        }
        .accessibilityElement()
        .accessibility(identifier: "autocompleteResult\(selected ? "-selected":"")-\(item.text)-\(item.source)")
    }
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
