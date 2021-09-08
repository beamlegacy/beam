//
//  PointAndShootCardPicker.swift
//  Beam
//
//  Created by Remi Santos on 07/04/2021.
//
//swiftlint:disable file_length

import Foundation
import BeamCore
import SwiftUI

struct PointAndShootCardPicker: View {
    private static let rowHeight: CGFloat = 24
    var completedGroup: PointAndShoot.ShootGroup?
    @Binding var allowAnimation: Bool

    @EnvironmentObject var state: BeamState
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

    @State private var shouldHighlightTextCompletion = false
    @State private var shootCompleted: Bool = false

    private var isTodaysNote: String? {
        browserTabsManager.currentTab?.noteController.noteOrDefault.isTodaysNote ?? false ? data.todaysName : nil
    }

    private var placeholderText: String {
        currentCardName ?? data.todaysName
    }

    private var textColor: NSColor {
        currentCardName == nil ? BeamColor.Generic.text.nsColor : BeamColor.Beam.nsColor
    }

    private var cursorIsOnCardName: Bool {
        if let selection = cardSearchFieldSelection {
            return selection.upperBound <= cardSearchField.count
        }
        return false
    }

    private var selectedRangeColor: NSColor {
        if cursorIsOnCardName, currentCardName != nil {
            return BeamColor.Generic.transparent.nsColor
        }

        return BeamColor.Generic.textSelection.nsColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Top Half
            HStack(spacing: BeamSpacing._40) {
                // MARK: - Prefix
                PrefixLabel(completed: shootCompleted && completedGroup != nil, confirmation: completedGroup?.confirmation)

                // MARK: - TextField
                ZStack {
                    if !shootCompleted {
                        BeamTextField(
                            text: $cardSearchField,
                            isEditing: $isEditingCardName,
                            placeholder: placeholderText,
                            font: BeamFont.regular(size: 13).nsFont,
                            textColor: textColor,
                            placeholderColor: BeamColor.Generic.placeholder.nsColor,
                            selectedRange: cardSearchFieldSelection,
                            selectedRangeColor: selectedRangeColor
                        ) { (text) in
                            onTextDidChange(text)
                        } onCommit: { _ in
                            enableResizeAnimation()
                            if currentCardName != nil || cardSearchField.isEmpty {
                                onFinishEditing(canceled: false)
                            } else {
                                selectSearchResult()
                            }
                        } onEscape: {
                            onFinishEditing(canceled: true)
                        } onTab: {
                            isEditingNote = true
                            // select note when pressing tab
                            if currentCardName == nil || !cardSearchField.isEmpty {
                                selectSearchResult()
                            }
                        } onCursorMovement: { move -> Bool in
                            autocompleteModel.handleCursorMovement(move)
                        } onStopEditing: {
                            cardSearchFieldSelection = nil
                            enableResizeAnimation()
                        } onSelectionChanged: { range in
                            guard range.lowerBound != cardSearchFieldSelection?.lowerBound ||
                                    range.upperBound != cardSearchFieldSelection?.upperBound else { return }
                            DispatchQueue.main.async {
                                cardSearchFieldSelection = Range(range)
                            }
                        }
                        .frame(minHeight: 16)
                        .padding(BeamSpacing._40)
                        .background(
                            Placeholder(
                                text: cardSearchField,
                                currentCardName: currentCardName,
                                tokenize: cursorIsOnCardName,
                                selectedResult: shouldHighlightTextCompletion ? autocompleteModel.selectedResult?.text : nil,
                                completed: shootCompleted
                            )
                        )
                    } else if let text = currentCardName, completedGroup?.confirmation == .success {
                        Text(text)
                            .foregroundColor(BeamColor.Beam.swiftUI)
                            .font(BeamFont.regular(size: 13).swiftUI)
                            .animation(.easeInOut(duration: 0.1))
                    }
                }

                Spacer()

                // MARK: - Icon
                if isEditingCardName && (currentCardName != nil || cardSearchField.isEmpty) {
                    if !shootCompleted {
                        Icon(name: "editor-format_enter", size: 12, color: BeamColor.Generic.placeholder.swiftUI)
                            .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.15)))
                            .onTapGesture {
                                onFinishEditing(canceled: false)
                            }
                    } else if let group = completedGroup {
                        let confirmationIcon = group.confirmation == .success ? "collect-generic" : "tabs-close"
                        Icon(name: confirmationIcon, size: 16, color: BeamColor.Generic.text.swiftUI)
                            .transition(AnyTransition.opacity.animation(Animation.easeInOut(duration: 0.15).delay(0.05)))
                            .onTapGesture {
                                state.navigateToNote(id: group.noteInfo.id)
                            }
                    }
                }
            }
            .lineLimit(1)
            .padding(.horizontal, BeamSpacing._120)
            .padding(.top, BeamSpacing._80)
            .frame(maxHeight: 42)

            Spacer()

            if !shootCompleted {
                // MARK: - Autocomplete
                if isEditingCardName && currentCardName == nil {
                    DestinationNoteAutocompleteList(model: autocompleteModel)
                        .onSelectAutocompleteResult { selectSearchResult() }
                        .onReceive(autocompleteModel.$selectedIndex) { _ in
                            // selected item changed from hover or arrows. let's not highlight anymore.
                            shouldHighlightTextCompletion = false
                        }
                }
                // MARK: - Bottom Half
                Separator(horizontal: true).padding(.horizontal, BeamSpacing._120)
                HStack(spacing: 4) {
                    // MARK: - TextField
                    BeamTextField(
                        text: $addNoteField,
                        isEditing: $isEditingNote,
                        placeholder: "Add note",
                        font: BeamFont.regular(size: 13).nsFont,
                        textColor: BeamColor.Generic.text.nsColor,
                        placeholderColor: BeamColor.Generic.placeholder.nsColor
                    ) { _ in
                    } onCommit: { _ in
                        onFinishEditing(canceled: false)
                    } onEscape: {
                        onFinishEditing(canceled: true)
                    }
                    .frame(minHeight: 16)

                    // MARK: - Icon
                    if isEditingNote {
                        Icon(name: "editor-format_enter", size: 12, color: BeamColor.Generic.placeholder.swiftUI)
                            .animation(nil)
                            .onTapGesture {
                                onFinishEditing(canceled: false)
                            }
                    }
                }
                .padding(.horizontal, BeamSpacing._120)
                .padding(.vertical, BeamSpacing._100)
            }
        }
        .onAppear {
            if let currentNote = browserTabsManager.currentTab?.noteController.note {
                currentCardName = currentNote.title
                cardSearchField = currentNote.title
            }
            autocompleteModel.data = data
            autocompleteModel.useRecents = false
            if !cardSearchField.isEmpty {
                let range = cardSearchField.count..<cardSearchField.count
                cardSearchFieldSelection = range
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if focusOnAppear {
                    isEditingCardName = true
                }
            }
        }
        .onTapGesture {
            if let group = completedGroup {
                state.navigateToNote(id: group.noteInfo.id)
            }
        }
        .onReceive(autocompleteModel.$results.dropFirst()) { _ in
            enableResizeAnimation()
        }
    }
}

extension PointAndShootCardPicker {
    // MARK: - PrefixLabel Component
    struct PrefixLabel: View {
        var completed: Bool
        var confirmation: PointAndShoot.ShootConfirmation?

        @State private var addToOpacity: Double = 1
        @State private var addedToOpacity: Double = 0

        var confirmationLabel: String {
            confirmation == .success ? "Added to" : "Failed to collect"
        }

        var body: some View {
            ZStack {
                if !completed {
                    Text("Add to")
                        // https://sarunw.com/posts/how-to-fix-zstack-transition-animation-in-swiftui/
                        .zIndex(-1)
                        .frame(alignment: .topLeading)
                        .transition(AnyTransition.asymmetric(insertion: .identity,
                                                             removal: AnyTransition.opacity.animation(.easeInOut(duration: 0.05))))
                } else {
                    Text(confirmationLabel)
                        .zIndex(1)
                        .frame(alignment: .topLeading)
                        .transition(AnyTransition.asymmetric(insertion: AnyTransition.opacity.animation(Animation.easeInOut(duration: 0.05).delay(0.05)),
                                                             removal: .identity))
                }
            }
            .accessibility(identifier: "ShootCardPickerLabel")
            .font(BeamFont.medium(size: 13).swiftUI)
        }
    }
    // MARK: - Placeholder Component
    struct Placeholder: View {
        var text: String
        var currentCardName: String?
        var tokenize: Bool = false
        var selectedResult: String?
        var completed: Bool = false

        @ViewBuilder
        var body: some View {
            Group {
                let color = tokenize ? BeamColor.NotePicker.active.swiftUI : BeamColor.NotePicker.selected.swiftUI
                // MARK: - Current Card Placeholder
                if let name = currentCardName {
                    HStack {
                        Text(name).font(BeamFont.regular(size: 13).swiftUI).hidden()
                            .padding(BeamSpacing._40)
                            .overlay(color.cornerRadius(4.0))
                        Spacer()
                    }
                } else if let result = selectedResult {
                    // MARK: - Autocomplete Placeholder
                    let autocompleteText = result.replacingOccurrences(of: text, with: "", options: [.anchored, .caseInsensitive])
                    // only show auto complete inline if we replaced an Occurence the result
                    if autocompleteText.lowercased() != selectedResult?.lowercased(), autocompleteText.count > 0 {
                        HStack(spacing: 4) {
                            Text(text).font(BeamFont.regular(size: 13).swiftUI)
                                .hidden()
                                .padding(0)
                            Text(autocompleteText)
                                .padding(EdgeInsets(top: BeamSpacing._40, leading: 0, bottom: BeamSpacing._40, trailing: BeamSpacing._40))
                                .font(BeamFont.regular(size: 13).swiftUI)
                                .foregroundColor(BeamColor.Beam.swiftUI)
                                .overlay(
                                    BeamColor.NotePicker.selected.swiftUI
                                        .cornerRadius(4.0)
                                        .animation(.easeInOut(duration: 0.1))
                                )
                                .animation(nil)

                            Spacer()
                        }.animation(nil)
                    }
                }
            }.opacity(!completed ? 1 : 0)
            .animation(.easeInOut(duration: 0.05), value: completed)
        }
    }
}

extension PointAndShootCardPicker {
    // MARK: - onTextDidChange
    private func onTextDidChange(_ text: String) {
        var searchText = text
        if let currentCardName = currentCardName, text.count == currentCardName.count - 1 {
            cardSearchField = ""
            searchText = ""
        }
        let textWasAdded = searchText.count > autocompleteModel.searchText.count
        autocompleteModel.searchText = searchText
        shouldHighlightTextCompletion = textWasAdded
        currentCardName = nil
    }
}

extension PointAndShootCardPicker {
    // MARK: - onFinishEditing
    private func onFinishEditing(canceled: Bool = false) {
        guard !shootCompleted else { return }
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
            shootCompleted = true
            onComplete?(finalCardName, addNoteField)
        }
    }
}

extension PointAndShootCardPicker {
    // MARK: - selectSearchResult
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
}

extension PointAndShootCardPicker {
    // MARK: - createNote
    @discardableResult
    private func createNote(named name: String) -> BeamNote {
        let note = BeamNote.fetchOrCreate(data.documentManager, title: name)
        note.save(documentManager: data.documentManager)
        return note
    }
}

extension PointAndShootCardPicker {
    // MARK: - onComplete
    func onComplete(perform action: @escaping (_ cardName: String?, _ note: String?) -> Void ) -> Self {
        var copy = self
        copy.onComplete = action
        return copy
    }
}

extension PointAndShootCardPicker {
    /// Temporarily allow animation on the parent wrapper
    func enableResizeAnimation() {
        self.allowAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1)) {
            self.allowAnimation = false
        }
    }
}

struct ShootCardPicker_Previews: PreviewProvider {
    // MARK: - ShootCardPicker_Previews
    @State static var allowAnimation: Bool = false
    static let data = BeamData()
    static var previews: some View {
        PointAndShootCardPicker(allowAnimation: $allowAnimation)
            .environmentObject(data)
    }
}
