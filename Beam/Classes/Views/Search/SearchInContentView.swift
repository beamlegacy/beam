//
//  SearchInContentView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 17/08/2021.
//

import SwiftUI

struct SearchInContentView: View {

    @ObservedObject var viewModel: SearchViewModel
    @EnvironmentObject var state: BeamState
    @Environment(\.colorScheme) var colorScheme

    private let cornerRadius: CGFloat = 10
    private let strokeColor = BeamColor.combining(lightColor: .From(color: .black, alpha: 0.1), darkColor: .From(color: .white, alpha: 0.3))

    private let backgroundColor = BeamColor.combining(lightColor: .Generic.background, darkColor: .Mercury)
    private let shadowColor = BeamColor.combining(lightColor: .From(color: .black, alpha: 0.16), darkColor: .From(color: .black, alpha: 0.7))
    private let searchFieldFont = BeamFont.regular(size: 13).nsFont
    private let searchFieldTextColor = BeamColor.Niobium.nsColor
    private let resultsTextFont = BeamFont.regular(size: 11).swiftUI
    private let resultsTextColor = BeamColor.AlphaGray.swiftUI

    var body: some View {
        HStack(spacing: 10) {
            BeamTextField(text: $viewModel.searchTerms, isEditing: $viewModel.isEditing, placeholder: title, font: searchFieldFont, textColor: searchFieldTextColor, placeholderColor: BeamColor.AlphaGray.nsColor, onCommit: viewModel.onCommit, onEscape: viewModel.close)
            if !viewModel.searchTerms.isEmpty && !viewModel.typing {
                Text(results)
                    .font(resultsTextFont)
                    .foregroundColor(resultsTextColor)
                    .animation(nil)
                Separator(color: BeamColor.Mercury)
                ButtonLabel(icon: "find-forward", state: viewModel.foundOccurences == 0 ? .disabled : .normal, customStyle: searchButtonLabelStyle) {
                    viewModel.previous()
                }
                ButtonLabel(icon: "find-previous", state: viewModel.foundOccurences == 0 ? .disabled : .normal, customStyle: searchButtonLabelStyle) {
                    viewModel.next()
                }
            }
            ButtonLabel(icon: "tool-close", customStyle: searchButtonLabelStyle) {
                viewModel.close()
            }
        }
        .padding(.trailing, 10)
        .padding(.leading, 12)
        .padding(.vertical, 8)
        .frame(width: 320, height: 36)
        .background(backgroundView)
    }

    private var backgroundView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(strokeColor.swiftUI, lineWidth: 1)
            RoundedRectangle(cornerRadius: cornerRadius)
                .foregroundColor(backgroundColor.swiftUI)
                .shadow(color: shadowColor.swiftUI, radius: 13, x: 0, y: 11)
        }
    }

    private var title: String {
        switch viewModel.context {
        case .card:
            return "Find on \(state.currentNote?.title ?? "Card")"
        case .web:
            return "Find on \(state.browserTabsManager.currentTab?.title ?? "Page")"
        }
    }

    private var results: String {
        if viewModel.foundOccurences > 0 && !viewModel.incompleteSearch {
            return "\(viewModel.currentOccurence)/\(viewModel.foundOccurences)"
        } else if viewModel.incompleteSearch {
            return "More than \(viewModel.foundOccurences)"
        } else {
            return "Not found"
        }
    }

    let searchButtonLabelStyle: ButtonLabelStyle = {
        var style = ButtonLabelStyle()
        style.iconSize = 16
        style.verticalPadding = 0
        style.horizontalPadding = 0
        style.foregroundColor = BeamColor.LightStoneGray.swiftUI
        style.activeForegroundColor = BeamColor.Niobium.swiftUI
        style.hoveredBackgroundColor = nil
        style.activeBackgroundColor = BeamColor.Mercury.swiftUI
        return style
    }()
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SearchInContentView(viewModel: SearchViewModel(context: .card, terms: "", found: 0))
            SearchInContentView(viewModel: SearchViewModel(context: .card, terms: "Anticonstitutionally", found: 0))
            SearchInContentView(viewModel: SearchViewModel(context: .card, terms: "Label", found: 5))
        }
        Group {
            SearchInContentView(viewModel: SearchViewModel(context: .card, terms: "", found: 0))
            SearchInContentView(viewModel: SearchViewModel(context: .card, terms: "Anticonstitutionally", found: 0))
            SearchInContentView(viewModel: SearchViewModel(context: .card, terms: "Label", found: 5))
        }.colorScheme(.dark)
    }
}
