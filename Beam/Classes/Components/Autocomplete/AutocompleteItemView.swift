//
//  AutocompleteItemView.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import SwiftUI
import BeamCore

struct AutocompleteItemView: View {

    static let defaultHeight: CGFloat = 38

    @State var item: AutocompleteResult
    let selected: Bool
    var disabled: Bool = false
    var displayIcon: Bool = true
    var displaySubtitle: Bool = true
    var alwaysHighlightCompletingText: Bool = false
    var allowsShortcut: Bool = true

    var colorPalette: AutocompleteItemColorPalette = Self.defaultColorPalette
    var height: CGFloat = Self.defaultHeight
    var fontSize: CGFloat = 14
    var additionalLeadingPadding: CGFloat = 0
    var cornerRadius: Double = 6

    @State private var isTouchDown = false

    @State private var favicon: NSImage?
    var backgroundColor: Color {
        isTouchDown ? colorPalette.touchdownBackgroundColor.swiftUI : colorPalette.selectedBackgroundColor.swiftUI.opacity(selected ? 1.0 : 0.0)
    }

    private var isUrlWithTitle: Bool {
        item.source == .url && item.information?.isEmpty == false
    }

    private var defaultTextColor: Color {
        disabled ? BeamColor.LightStoneGray.swiftUI : colorPalette.textColor.swiftUI
    }
    private let secondaryTextColor = BeamColor.Autocomplete.subtitleText.swiftUI
    private let subtitleLinkColor = BeamColor.Autocomplete.link.swiftUI
    private let cardColor = BeamColor.Beam.swiftUI
    private var mainTextColor: Color {
        switch item.source {
        case .topDomain, .mnemonic:
            return subtitleLinkColor
        case .url where !isUrlWithTitle:
            return subtitleLinkColor
        case .note:
            return cardColor
        case .createNote where item.information != nil:
            return cardColor
        default:
            return defaultTextColor
        }
    }
    private var informationColor: Color {
        switch item.source {
        case .history, .url:
            return subtitleLinkColor
        default:
            return colorPalette.informationTextColor.swiftUI
        }
    }
    private var shortcutColor: Color {
        switch item.source {
        case .note, .createNote:
            return cardColor
        default:
            return subtitleLinkColor
        }
    }

    private func highlightedTextRanges(secondaryText: Bool = false) -> ((String) -> [Range<String.Index>]) {
        { text in
            guard let completingText = item.completingText,
                  item.source != .createNote,
                  (item.source != .searchEngine || !secondaryText)
            else {
                return []
            }
            if alwaysHighlightCompletingText || [.searchEngine, .history, .url, .topDomain, .mnemonic, .action].contains(item.source) {
                return text.ranges(of: completingText, options: .caseInsensitive)
            }
            if let firstRange = text.range(of: completingText, options: .caseInsensitive), firstRange.lowerBound == text.startIndex {
                return [firstRange.upperBound..<text.endIndex]
            }
            return []
        }
    }

    var mainText: String {
        item.displayText
    }

    var secondaryText: String? {
        guard displaySubtitle else { return nil }
        switch item.source {
        case .createNote:
            if let info = item.information {
                return " " + info
            }
            return nil
        default:
            if let info = item.displayInformation {
                return " - " + info
            }
            return nil
        }
    }

    private var shortcut: Shortcut? {
        guard allowsShortcut else { return nil }
        if let shortcut = item.shortcut {
            return shortcut
        } else {
            return Shortcut(modifiers: [], keys: [.enter])
        }
    }

    private var shortcutShouldBeVisible: Bool {
        if item.shortcut != nil {
            return true
        }
        return selected
    }

    private var axIdentifier: String {
        var importantText = mainText
        if item.source == .createNote, let info = item.information {
            importantText = info
        }
        return "autocompleteResult\(selected ? "-selected":"")-\(importantText)-\(item.source)"
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
                    Icon(name: item.icon, color: secondaryTextColor)
                        .blendModeLightMultiplyDarkScreen()
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                ZStack {
                    StyledText(verbatim: mainText)
                        .style(.font(BeamFont.semibold(size: fontSize).swiftUI), ranges: highlightedTextRanges())
                        .font(BeamFont.regular(size: fontSize).swiftUI)
                        .foregroundColor(mainTextColor)
                }
                .layoutPriority(10)
                if let info = secondaryText {
                    HStack {
                        StyledText(verbatim: info)
                            .style(.font(BeamFont.semibold(size: fontSize).swiftUI), ranges: highlightedTextRanges(secondaryText: true))
                            .font(BeamFont.regular(size: fontSize).swiftUI)
                            .foregroundColor(informationColor)
                    }
                    .layoutPriority(0)
                }

                if PreferencesManager.showOmniboxScoreSection {
                    Spacer()
                    Text(debugString(score: item.weightedScore))
                        .font(BeamFont.regular(size: fontSize).swiftUI)
                        .foregroundColor(BeamColor.CharmedGreen.swiftUI)
                        .layoutPriority(10)
                }
            }
            .blendModeLightMultiplyDarkScreen()
            Spacer(minLength: 0)
            if let shortcut = shortcut {
                ShortcutView(shortcut: shortcut, spacing: 1, withBackground: !selected)
                    .frame(height: 18)
                    .opacity(shortcutShouldBeVisible ? 1 : 0)
                    .blendModeLightMultiplyDarkScreen()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, BeamSpacing._100)
        .padding(.horizontal, BeamSpacing._120)
        .padding(.leading, additionalLeadingPadding)
        .frame(height: height)
        .background(backgroundColor.blendModeLightMultiplyDarkScreen())
        .cornerRadius(cornerRadius)
        .onTouchDown { t in
            isTouchDown = t && !disabled
        }
        .onAppear {
            if let url = item.url {
                FaviconProvider.shared.favicon(fromURL: url, cacheOnly: item.source != .topDomain) { favicon in
                    self.favicon = favicon?.image
                    if favicon == nil, let aliasDestinationURL = item.aliasForDestinationURL {
                        FaviconProvider.shared.favicon(fromURL: aliasDestinationURL, cacheOnly: true) { favicon in
                            self.favicon = favicon?.image
                        }
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(item.displayText)
        .accessibility(identifier: axIdentifier)
    }

    private func debugString(score: Float?) -> String {
        var debugString = "\(item.source.shortDescription)"
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
}

extension AutocompleteItemView {
    static let defaultColorPalette = AutocompleteItemColorPalette()
    static let noteColorPalette = AutocompleteItemColorPalette(
        selectedBackgroundColor: BeamColor.Autocomplete.selectedCardBackground,
        touchdownBackgroundColor: BeamColor.Autocomplete.clickedCardBackground
    )
    static let createNoteColorPalette = AutocompleteItemColorPalette(
        informationTextColor: BeamColor.Generic.text,
        selectedBackgroundColor: BeamColor.Autocomplete.selectedCardBackground,
        touchdownBackgroundColor: BeamColor.Autocomplete.clickedCardBackground
    )
    static let actionColorPalette = AutocompleteItemColorPalette(
        selectedBackgroundColor: BeamColor.Autocomplete.selectedActionBackground,
        touchdownBackgroundColor: BeamColor.Autocomplete.clickedActionBackground
    )
}

struct AutocompleteItem_Previews: PreviewProvider {
    static let items = [
        AutocompleteResult(text: "New Note:", source: .createNote, information: "James Dean"),
        AutocompleteResult(text: "James Dean", source: .note, completingText: "Ja"),
        AutocompleteResult(text: "James Dean", source: .searchEngine, information: "Google Search"),
        AutocompleteResult(text: "jamesdean.com", source: .url, urlFields: .text),
        AutocompleteResult(text: "James Dean", source: .history, information: "https://wikipedia.com/James+Dean")
    ]
    static let selectedIndex = 3
    static var previews: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.0) { index, item in
                AutocompleteItemView(item: item, selected: index == selectedIndex)
                    .frame(width: 300, height: 36)
            }
        }.padding(.vertical)
    }
}
