//
//  AutocompleteItem.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/09/2020.
//

import SwiftUI

struct AutocompleteItem: View {
    @State var item: AutocompleteResult
    var selected: Bool
    var displayIcon: Bool = true
    
    @State var isHovering = false
    var backgroundColor: Color {
        return selected || isHovering ? Color(.autocompleteSelectedBackgroundColor) : Color(.transparent)
    }

    func iconNameSource(_ source: AutocompleteResult.Source) -> String {
        switch item.source {
        case .history:
            return "field-history"
        case .autocomplete:
            return "field-search"
        case .createCard:
            return "field-card_new"
        case .url:
            return "field-web"
        case .note:
            return "field-card"
        }
    }

    private let textColor = Color(.autocompleteTextColor)
    private let subtitleTextColor = Color(.autocompleteSubtitleTextColor)
    private let subtitleLinkColor = Color(.linkColor)

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
                Icon(name: iconNameSource(item.source), size: 16, color: textColor)
            }
            HStack(spacing: 2) {
                ZStack {
                    StyledText(verbatim: item.text)
                        .style(.bold(), ranges: boldTextRanges)
                        .font(.system(size: 13))
                        .foregroundColor(item.source == .url ? subtitleLinkColor : textColor)
                }
                if let info = item.information {
                    HStack {
                        StyledText(verbatim: "– \(info)")
                            .style(.bold(), ranges: boldTextRanges)
                            .font(.system(size: 10))
                            .foregroundColor(item.source == .history ? subtitleLinkColor : subtitleTextColor)
                    }
                }
            }
            if selected {
                Spacer()
                Icon(name: "editor-format_enter", size: 12, color: subtitleTextColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(backgroundColor)
        .onHover { v in
            isHovering = v
        }
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
