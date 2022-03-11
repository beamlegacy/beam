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

    private let searchFieldFont = BeamFont.regular(size: 13).nsFont
    private let searchFieldTextColor = BeamColor.Niobium.nsColor
    private let resultsTextFont = BeamFont.regular(size: 11).swiftUI
    private let resultsTextColor = BeamColor.AlphaGray.swiftUI

    var body: some View {
        FloatingToolbar(contentWidth: 320) {
            Group {
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
        }
        .accessibilityIdentifier("search-field")
    }

    private var title: String {
        switch viewModel.context {
        case .card:
            return "Find on \(state.currentNote?.title ?? "Note")"
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
        var style = ButtonLabelStyle.floatingToolbarButtonLabelStyle()
        style.iconSize = 16
        style.verticalPadding = 0
        style.horizontalPadding = 0
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
