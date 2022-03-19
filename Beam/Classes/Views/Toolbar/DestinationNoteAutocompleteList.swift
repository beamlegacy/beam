//
//  DestinationNoteAutocompleteList.swift
//  Beam
//
//  Created by Remi Santos on 09/03/2021.
//

import SwiftUI
import BeamCore
import Combine

struct DestinationNoteAutocompleteList: View {

    enum DesignVariation {
        case TextEditor(leadingPadding: CGFloat)
        case SearchField
    }

    @ObservedObject var model = Model()
    var variation: DesignVariation = .SearchField
    var allowScroll: Bool = false
    internal var onSelectAutocompleteResult: (() -> Void)?

    private let itemHeight: CGFloat = 30
    private let customColorPalette = AutocompleteItemColorPalette(
        textColor: BeamColor.Beam,
        informationTextColor: BeamColor.Generic.text,
        selectedBackgroundColor: BeamColor.NotePicker.selected,
        touchdownBackgroundColor: BeamColor.NotePicker.active)

    private var colorPalette: AutocompleteItemColorPalette {
        guard !model.searchCardContent else { return AutocompleteItemView.defaultColorPalette }
        return customColorPalette
    }

    private var additionLeadingPadding: CGFloat {
        guard case .TextEditor(let leadingPadding) = variation else { return 0 }
        return leadingPadding
    }

    private var alwaysHighlightCompletingText: Bool {
        if case .TextEditor = variation { return false }
        return true
    }

    var body: some View {
        Group {
            if allowScroll {
                ScrollView {
                    ScrollViewReader { proxy in
                        list.onAppear {
                            model.scrollViewProxy = proxy
                        }
                    }
                }
            } else {
                list
            }
        }
    }

    var list: some View {
        VStack(spacing: 0) {
            ForEach(model.results, id: \.id) { item in
                if item.source == .createNote && model.results.count > 1 {
                    Separator(horizontal: true, color: BeamColor.Autocomplete.separatorColor)
                        .blendModeLightMultiplyDarkScreen()
                        .padding(.vertical, BeamSpacing._80)
                }
                AutocompleteItemView(item: item, selected: model.isSelected(item), disabled: item.disabled, displayIcon: false,
                                     alwaysHighlightCompletingText: alwaysHighlightCompletingText,
                                     allowsShortcut: item.source != .createNote || model.allowNewCardShortcut, colorPalette: colorPalette,
                                     height: itemHeight, fontSize: 13, additionalLeadingPadding: additionLeadingPadding)
                    .padding(.horizontal, BeamSpacing._80)
                    .if(model.searchCardContent) {
                        $0.frame(minHeight: itemHeight).fixedSize(horizontal: false, vertical: true)
                    }
                    .id(item.id)
                    .transition(.identity)
                    .animation(nil)
                    .simultaneousGesture(
                        TapGesture(count: 1).onEnded {
                            model.select(result: item)
                            onSelectAutocompleteResult?()
                        }
                    )
                    .onHover { hovering in
                        if hovering && !model.disableHoverSelection {
                            model.select(result: item)
                        }
                    }
            }
        }
        .padding(.bottom, BeamSpacing._80)
        .onHover { hovering in
            if !hovering && !model.disableHoverSelection {
                model.selectedIndex = 0
            }
        }
        .frame(maxWidth: .infinity)
    }

}

extension DestinationNoteAutocompleteList {
    func onSelectAutocompleteResult(perform action: @escaping () -> Void ) -> Self {
         var copy = self
         copy.onSelectAutocompleteResult = action
         return copy
     }
}

struct DestinationNoteAutocompleteList_Previews: PreviewProvider {
    static var elements = [
        AutocompleteResult(text: "Result", source: .note),
        AutocompleteResult(text: "Result 2", source: .note),
        AutocompleteResult(text: "Result third", source: .note)]
    static let model = DestinationNoteAutocompleteList.Model()
    static var previews: some View {
        model.data = BeamData()
        model.searchText = "Resul"
        model.results = elements
        return DestinationNoteAutocompleteList(model: model)
    }
}
