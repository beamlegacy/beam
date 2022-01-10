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
    var allowNewCardShortcut: Bool = true

    var colorPalette: AutocompleteItemColorPalette = Self.defaultColorPalette
    var additionalLeadingPadding: CGFloat = 0

    @State private var isTouchDown = false

    @State private var favicon: NSImage?
    var backgroundColor: Color {
        switch item.source {
        case .createCard, .note:
            return isTouchDown ? colorPalette.touchdownCardBackgroundColor.swiftUI : colorPalette.selectedCardBackgroundColor.swiftUI.opacity(selected ? 1.0 : 0.0)
        default:
            return isTouchDown ? colorPalette.touchdownBackgroundColor.swiftUI : colorPalette.selectedBackgroundColor.swiftUI.opacity(selected ? 1.0 : 0.0)
        }
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

    private var defaultTextColor: Color {
        disabled ? BeamColor.LightStoneGray.swiftUI : colorPalette.textColor.swiftUI
    }
    private let secondaryTextColor = BeamColor.Autocomplete.subtitleText.swiftUI
    private let subtitleLinkColor = BeamColor.Autocomplete.link.swiftUI
    private let cardColor = BeamColor.Beam.swiftUI
    private var mainTextColor: Color {
        switch item.source {
        case .topDomain:
            return subtitleLinkColor
        case .url where !isUrlWithTitle:
            return subtitleLinkColor
        case .note, .createCard:
            return cardColor
        default:
            return defaultTextColor
        }
    }
    private var informationColor: Color {
        switch item.source {
        case .history, .url:
            return subtitleLinkColor
        case .createCard:
            return defaultTextColor
        default:
            return colorPalette.informationTextColor.swiftUI
        }
    }
    private var shortcutColor: Color {
        switch item.source {
        case .note, .createCard:
            return cardColor
        default:
            return subtitleLinkColor
        }
    }

    private func highlightedTextRanges(in text: String) -> [Range<String.Index>] {
        guard let completingText = item.completingText, item.source != .createCard else {
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
        if item.source == .createCard {
            return "New Note:"
        }
        if isUrlWithTitle, let information = item.information {
            return information
        }
        return item.text
    }

    var secondaryText: String? {
        if item.source == .createCard {
            return " " + item.text
        } else if isUrlWithTitle {
            return " – \(item.text)"
        } else if let info = item.information {
            return " – \(info)"
        }
        return nil
    }

    var body: some View {
        HStack(spacing: BeamSpacing._120) {
            if displayIcon {
                if let icon = favicon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 16, maxHeight: 16)
                } else {
                    Icon(name: item.source.iconName, color: secondaryTextColor)
                        .blendModeLightMultiplyDarkScreen()
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
                        StyledText(verbatim: info)
                            .style(.font(BeamFont.semibold(size: 13).swiftUI), ranges: highlightedTextRanges)
                            .font(BeamFont.regular(size: 13).swiftUI)
                            .foregroundColor(informationColor)
                    }
                    .layoutPriority(0)
                }

                if PreferencesManager.showOmniboxScoreSection {
                    Spacer()
                    Text(debugString(score: item.score))
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.CharmedGreen.swiftUI)
                        .layoutPriority(10)
                }
            }
            .blendModeLightMultiplyDarkScreen()
            Spacer(minLength: 0)
            if item.source == .createCard && allowNewCardShortcut {
                HStack(spacing: BeamSpacing._20) {
                    Icon(name: "shortcut-option", width: 12, color: cardColor, alignment: .trailing)
                    Icon(name: "shortcut-return", width: 12, color: cardColor, alignment: .trailing)
                }
                .opacity(0.5)
                .blendModeLightMultiplyDarkScreen()
            } else {
                Icon(name: "shortcut-return", width: 12, color: selected ? shortcutColor : .clear, alignment: .trailing)
                    .opacity(0.7)
                    .blendModeLightMultiplyDarkScreen()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, BeamSpacing._100)
        .padding(.horizontal, BeamSpacing._80)
        .padding(.leading, additionalLeadingPadding)
        .background(backgroundColor)
        .cornerRadius(6)
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

    private func debugString(score: Float?) -> String {
        var debugString = "\(item.source)"
        if let score = score {
            debugString += " - Score: \(score)"
        }
        return debugString
    }
}

struct AutocompleteItemColorPalette {
    var textColor = BeamColor.Generic.text
    var informationTextColor = BeamColor.Autocomplete.subtitleText
    var selectedBackgroundColor = BeamColor.Autocomplete.selectedBackground
    var touchdownBackgroundColor = BeamColor.Autocomplete.clickedBackground
    var selectedCardBackgroundColor = BeamColor.Autocomplete.selectedCardBackground
    var touchdownCardBackgroundColor = BeamColor.Autocomplete.clickedCardBackground
}

extension AutocompleteItem {
    static let defaultColorPalette = AutocompleteItemColorPalette()
}

struct AutocompleteItem_Previews: PreviewProvider {
    static let items = [
        AutocompleteResult(text: "James Dean", source: .createCard, information: "New Note"),
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
                    .frame(width: 300, height: 36)
            }
        }.padding(.vertical)
    }
}
