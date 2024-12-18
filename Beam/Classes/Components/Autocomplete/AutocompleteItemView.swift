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

    @Environment(\.faviconProvider) var faviconProvider
    @State var item: AutocompleteResult
    let selected: Bool
    var disabled: Bool = false
    var loading = false
    var displayIcon: Bool = true
    var displaySubtitle: Bool = true
    var allowsShortcut: Bool = true

    var colorPalette: AutocompleteItemColorPalette = Self.defaultColorPalette
    var height: CGFloat = Self.defaultHeight
    var fontSize: CGFloat = 14
    var additionalLeadingPadding: CGFloat = 0
    var cornerRadius: Double = 6
    var modifierFlagsPressed: NSEvent.ModifierFlags?

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
            return colorPalette.informationLinkColor.swiftUI
        default:
            return colorPalette.informationTextColor.swiftUI
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
            return text.ranges(of: completingText, options: .caseInsensitive)
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

    private func shortcutMatchesPressedModifierFlags(_ shortcut: Shortcut) -> Bool {
        guard let modifierFlagsPressed = modifierFlagsPressed else { return true }
        if modifierFlagsPressed.contains(.command) && !shortcut.modifiers.contains(.command) {
            return false
        } else if modifierFlagsPressed.contains(.control) && !shortcut.modifiers.contains(.control) {
            return false
        } else if modifierFlagsPressed.contains(.option) && !shortcut.modifiers.contains(.option) {
            return false
        }
        return true
    }

    private var shortcut: Shortcut? {
        guard allowsShortcut else { return nil }
        if let shortcut = item.shortcut {
            if !shortcutMatchesPressedModifierFlags(shortcut) {
                return selected ? Shortcut(modifiers: [], keys: [.enter]) : nil
            }
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

    private var axLabel: String {
        switch item.source {
        case .createNote:
            return item.displayText
        case .searchEngine, .note:
            return item.displayInformation ?? item.source.shortDescription
        default: return item.source.shortDescription
        }
    }

    private var axValue: String {
        switch item.source {
        case .createNote: return item.displayInformation ?? ""
        default: return item.displayText
        }
    }

    private var iconColor: Color {
        if let iconColor = item.iconColor {
            return Color(iconColor)
        }
        return secondaryTextColor
    }

    @ViewBuilder
    var iconView: some View {
        if loading {
            ProgressView()
                .scaleEffect(0.5, anchor: .center)
                .frame(width: 16, height: 16)
                .progressViewStyle(CircularProgressViewStyle(tint: secondaryTextColor))
                .blendModeLightMultiplyDarkScreen()
        } else if let icon = favicon {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 16, maxHeight: 16)
        } else {
            Icon(name: item.icon, color: iconColor)
                .blendModeLightMultiplyDarkScreen()
        }
    }

    @ViewBuilder
    var trailingView: some View {
        if case let .tabGroup(group) = item.source, let group = group {
            HStack(spacing: BeamSpacing._100) {
                HStack(spacing: BeamSpacing._20) {
                    ForEach(group.pageIds.prefix(11), id: \.self) { _ in
                        Capsule()
                            .fill(group.color?.mainColor?.swiftUI ?? Color.clear)
                            .opacity(0.4)
                            .frame(height: 4)
                    }
                }
                .frame(width: 64)
                ShortcutView(shortcut: Shortcut(modifiers: [], keys: [.right]), spacing: 1, withBackground: !selected)
                    .frame(height: 18)
                    .blendModeLightMultiplyDarkScreen()
            }
            .blendModeLightMultiplyDarkScreen()
        } else if let shortcut = shortcut {
            ShortcutView(shortcut: shortcut, spacing: 1, withBackground: !selected)
                .frame(height: 18)
                .opacity(shortcutShouldBeVisible ? 1 : 0)
                .blendModeLightMultiplyDarkScreen()
        } else {
            EmptyView()
        }
    }

    var textContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ZStack {
                StyledText(verbatim: mainText)
                    .style(.font(BeamFont.semibold(size: fontSize).swiftUI), ranges: highlightedTextRanges())
                    .font(BeamFont.regular(size: fontSize).swiftUI)
                    .foregroundColor(mainTextColor)
            }
            .layoutPriority(10)
            if let info = secondaryText, !info.isEmpty {
                HStack {
                    StyledText(verbatim: info)
                        .style(.font(BeamFont.semibold(size: fontSize).swiftUI), ranges: highlightedTextRanges(secondaryText: true))
                        .font(BeamFont.regular(size: fontSize).swiftUI)
                        .foregroundColor(informationColor)
                }
                .frame(minWidth: info.count > 10 ? 100 : 0)
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
    }

    var body: some View {
        HStack(spacing: BeamSpacing._120) {
            if displayIcon {
                iconView
            }
            textContent
            Spacer(minLength: 0)
            trailingView
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
                faviconProvider.favicon(fromURL: url, cachePolicy: item.source != .topDomain ? .cacheOnly : .default) { favicon in
                    self.favicon = favicon?.image
                    if favicon == nil, let aliasDestinationURL = item.aliasForDestinationURL {
                        faviconProvider.favicon(fromURL: aliasDestinationURL, cachePolicy: .cacheOnly) { favicon in
                            self.favicon = favicon?.image
                        }
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(axLabel)
        .accessibilityValue(Text(axValue))
        .accessibilityAddTraits(.isLink)
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
    var informationLinkColor = BeamColor.Autocomplete.link
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

    static func tabGroupColorPalette(for group: TabGroup) -> AutocompleteItemColorPalette {
        guard let mainColor = group.color?.mainColor else { return defaultColorPalette }
        return AutocompleteItemColorPalette(
            informationTextColor: mainColor,
            informationLinkColor: mainColor,
            selectedBackgroundColor: BeamColor.combining(lightColor: mainColor, lightAlpha: 0.14,
                                                         darkColor: mainColor, darkAlpha: 0.16),
            touchdownBackgroundColor: BeamColor.combining(lightColor: mainColor, lightAlpha: 0.2,
                                                          darkColor: mainColor, darkAlpha: 0.34)
        )
    }
}

struct AutocompleteItem_Previews: PreviewProvider {
    static var tabGroup: TabGroup {
        let group = TabGroup(pageIds: [UUID(), UUID(), UUID()])
        group.changeColor(.init())
        return group
    }
    static let items = [
        AutocompleteResult(text: "New Note:", source: .createNote, information: "James Dean"),
        AutocompleteResult(text: "James Dean", source: .note, completingText: "Ja"),
        AutocompleteResult(text: "James Dean", source: .searchEngine, information: "Google Search"),
        AutocompleteResult(text: "jamesdean.com", source: .url, urlFields: .text),
        AutocompleteResult(text: "James Dean", source: .history, information: "https://wikipedia.com/James+Dean"),
        AutocompleteResult(text: "James Dean", source: .tabGroup(group: tabGroup),
                           information: "Tab Group (3 tabs)")
    ]
    static let selectedIndex = 5
    static var previews: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.0) { index, item in
                AutocompleteItemView(item: item, selected: index == selectedIndex, colorPalette: AutocompleteListView.colorPalette(for: item))
                    .frame(width: 400, height: 36)
            }
        }.padding(.vertical)
    }
}
