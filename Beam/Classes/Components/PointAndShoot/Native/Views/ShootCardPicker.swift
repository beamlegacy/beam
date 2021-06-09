//
//  ShootCardPicker.swift
//  Beam
//
//  Created by Remi Santos on 07/04/2021.
//

import Foundation
import BeamCore
import SwiftUI

struct ShootCardPicker: View {
    static let size = CGSize(width: 300, height: 80)
    private static let rowHeight: CGFloat = 24

    @EnvironmentObject var data: BeamData
    @EnvironmentObject var browserTabsManager: BrowserTabsManager

    var focusOnAppear = true
    var onComplete: ((_ cardName: String?, _ note: String?) -> Void)?

    @State private var autocompleteModel = DestinationNoteAutocompleteList.Model()

    @State private var isEditingCardName = false

    @State private var isEditingNote = false
    @State private var currentCardName: String?
    @State private var cardSearchField = ""
    @State private var cardSearchFieldSelection: Range<Int>?
    @State private var addNoteField = ""

    @State private var isVisible = false

    private let searchColorPalette = AutocompleteItemColorPalette(
            selectedBackgroundColor: BeamColor.NotePicker.selected.nsColor,
            touchdownBackgroundColor: BeamColor.NotePicker.active.nsColor)

    var body: some View {
        FormatterViewBackground {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: BeamSpacing._40) {
                    Text("Add to")
                        .accessibility(identifier: "ShootCardPickerLabel")
                        .font(BeamFont.medium(size: 13).swiftUI)
                    BeamTextField(text: $cardSearchField, isEditing: $isEditingCardName,
                                  placeholder: autocompleteModel.todaysCardReplacementName,
                                  font: BeamFont.regular(size: 13).nsFont,
                                  textColor: currentCardName == nil ? BeamColor.Generic.text.nsColor
                                          : BeamColor.Sonic.nsColor,
                                  placeholderColor: BeamColor.Generic.placeholder.nsColor,
                                  selectedRange: cardSearchFieldSelection) { (text) in
                        onTextDidChange(text)
                    } onCommit: { _ in
                        if currentCardName != nil || cardSearchField.isEmpty {
                            onFinishEditing(canceled: false)
                        } else {
                            selectSearchResult()
                        }
                    } onEscape: {
                        onFinishEditing(canceled: true)
                    } onTab: {
                        isEditingNote = true
                    } onCursorMovement: { move -> Bool in
                        autocompleteModel.handleCursorMovement(move)
                    }
                    .frame(minHeight: 16)
                    .padding(BeamSpacing._40)
                    .background(currentCardName == nil ? nil :
                                    HStack {
                                        Text(currentCardName ?? "").font(BeamFont.regular(size: 13).swiftUI).hidden()
                                            .padding(BeamSpacing._40)
                                            .overlay(BeamColor.Beam.swiftUI.opacity(0.08).cornerRadius(4.0))
                                        Spacer()
                                    }
                    )
                    if isEditingCardName && (currentCardName != nil || cardSearchField.isEmpty) {
                        Icon(name: "editor-format_enter", size: 12, color: BeamColor.Generic.placeholder.swiftUI)
                            .onTapGesture {
                                onFinishEditing(canceled: false)
                            }
                    }
                }
                .padding(.horizontal, BeamSpacing._120)
                .padding(.vertical, BeamSpacing._80)

                if isEditingCardName && currentCardName == nil {
                    DestinationNoteAutocompleteList(model: autocompleteModel)
                        .onSelectAutocompleteResult {
                            selectSearchResult()
                        }
                }
                Separator(horizontal: true)
                    .padding(.horizontal, BeamSpacing._120)
                HStack(spacing: 4) {
                    BeamTextField(text: $addNoteField, isEditing: $isEditingNote, placeholder: "Add note",
                                  font: BeamFont.regular(size: 13).nsFont, textColor: BeamColor.Generic.text.nsColor,
                                  placeholderColor: BeamColor.Generic.placeholder.nsColor) { _ in
                    } onCommit: { _ in
                        onFinishEditing(canceled: false)
                    } onEscape: {
                        onFinishEditing(canceled: true)
                    }
                    .frame(minHeight: 16)
                    if isEditingNote {
                        Icon(name: "editor-format_enter", size: 12, color: BeamColor.Generic.placeholder.swiftUI)
                            .onTapGesture {
                                onFinishEditing(canceled: false)
                            }
                    }
                }
                .padding(.horizontal, BeamSpacing._120)
                .padding(.vertical, BeamSpacing._100)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
        .zIndex(20)
        .animation(.easeInOut(duration: 0.3))
        .scaleEffect(isVisible ? 1.0 : 0.98)
        .offset(x: 0, y: isVisible ? 0.0 : -4.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6))
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.3))
        .onAppear {
            if let currentNote = browserTabsManager.currentTab?.note, !currentNote.isTodaysNote {
                currentCardName = currentNote.title
                cardSearchField = currentNote.title
            }
            autocompleteModel.data = data
            autocompleteModel.useRecents = false
            isVisible = true

            if !cardSearchField.isEmpty {
                let range = cardSearchField.count..<cardSearchField.count
                cardSearchFieldSelection = range
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if focusOnAppear {
                    isEditingCardName = true
                }
                cardSearchFieldSelection = nil
            }
        }
    }

    private func onTextDidChange(_ text: String) {
        var searchText = text
        if let currentCardName = currentCardName, text.count == currentCardName.count - 1 {
            cardSearchField = ""
            searchText = ""
        }
        autocompleteModel.searchText = searchText
        currentCardName = nil
    }

    private func onFinishEditing(canceled: Bool = false) {
        guard !canceled else {
            onComplete?(nil, nil)
            return
        }
        var finalCardName = cardSearchField
        if !finalCardName.isEmpty {
            selectSearchResult()
            finalCardName = autocompleteModel.realNameForCardName(cardSearchField)
        } else if let currentCardName = currentCardName {
            finalCardName = currentCardName
        } else {
            finalCardName = data.todaysName
        }

        if !finalCardName.isEmpty {
            onComplete?(finalCardName, addNoteField)
        }
    }

    private func selectSearchResult(withCommand: Bool = false) {
        guard !cardSearchField.isEmpty else { return }
        var finalCardName: String
        if withCommand {
            finalCardName = cardSearchField
            createNote(named: finalCardName)
        } else {
            guard let result = autocompleteModel.selectedResult else {
                return
            }
            if result.source == .createCard {
                createNote(named: result.text)
            }
            finalCardName = result.text
        }
        cardSearchField = finalCardName
        currentCardName = finalCardName
    }

    @discardableResult
    private func createNote(named name: String) -> BeamNote {
        let note = BeamNote.fetchOrCreate(data.documentManager, title: name)
        note.save(documentManager: data.documentManager)
        return note
    }
}

extension ShootCardPicker {
    func onComplete(perform action: @escaping (_ cardName: String?, _ note: String?) -> Void ) -> Self {
         var copy = self
         copy.onComplete = action
         return copy
    }
}

struct ShootCardPicker_Previews: PreviewProvider {
    static let data = BeamData()
    static var previews: some View {
        ShootCardPicker()
            .environmentObject(data)
    }
}
