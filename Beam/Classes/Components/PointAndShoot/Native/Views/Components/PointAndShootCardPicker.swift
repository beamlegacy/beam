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
    var onComplete: ((_ targetNote: BeamNote?, _ note: String?) -> Void)?

    @State private var autocompleteModel = DestinationNoteAutocompleteList.Model()

    @State private var isEditingCardName = false

    @State private var isEditingNote = false
    @State private var currentCardName: String? {
        didSet {
            textColor = currentCardName == nil ? BeamColor.Generic.text.nsColor : BeamColor.Beam.nsColor
        }
    }
    @State private var cardSearchField = ""
    @State private var cardSearchFieldSelection: Range<Int>?
    @State private var addNoteField = ""

    @State private var textColor = BeamColor.Generic.text.nsColor
    private let font = BeamFont.regular(size: 13).nsFont
    private let placeholderColor = BeamColor.Generic.placeholder.nsColor
    private let secondLabelTextColor = BeamColor.Generic.text.nsColor
    @State private var shootCompleted: Bool = false

    var completed: Bool {
        return shootCompleted || completedGroup?.directShoot == true
    }

    private var isTodaysNote: String? {
        browserTabsManager.currentTab?.noteController.noteOrDefault.isTodaysNote ?? false ? data.todaysName : nil
    }

    @State private var destinationCardName: String?
    @State var todaysCardName: String = ""

    private var cursorIsOnCardName: Bool {
        if let selection = cardSearchFieldSelection {
            return selection.upperBound <= cardSearchField.count
        }
        return false
    }

    private let transparentColor = BeamColor.Generic.transparent.nsColor
    private let textSelectionColor = BeamColor.Generic.transparent.nsColor
    private var selectedRangeColor: NSColor {
        if cursorIsOnCardName, currentCardName != nil {
            return transparentColor
        }
        return textSelectionColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Top Half
            HStack(spacing: BeamSpacing._40) {
                // MARK: - Prefix
                PrefixLabel(completed: completed && completedGroup != nil, confirmation: completedGroup?.confirmation)

                // MARK: - TextField
                ZStack {
                    if !completed {
                        BeamTextField(
                            text: $cardSearchField,
                            isEditing: $isEditingCardName,
                            placeholder: destinationCardName ?? todaysCardName,
                            font: font,
                            textColor: textColor,
                            placeholderColor: placeholderColor,
                            selectedRange: cardSearchFieldSelection,
                            selectedRangeColor: selectedRangeColor
                        ) { (text) in
                            onTextDidChange(text)
                        } onCommit: { modifierFlags in
                            enableResizeAnimation()

                            let withCommand = modifierFlags?.contains(.command) ?? false
                            if currentCardName != nil || cardSearchField.isEmpty || withCommand {
                                // Submit and close CardPicker
                                onFinishEditing(withCommand)
                            } else {
                                // Select search result
                                selectSearchResult()
                            }
                        } onEscape: {
                            onCancelEditing()
                        } onTab: {
                            isEditingNote = true
                            // select note when pressing tab
                            if currentCardName == nil || !cardSearchField.isEmpty {
                                selectSearchResult()
                            }
                            return true
                        } onCursorMovement: { move -> Bool in
                            autocompleteModel.handleCursorMovement(move)
                        } onStopEditing: {
                            DispatchQueue.main.async {
                                cardSearchFieldSelection = nil
                            }
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
                                selectedResult: nil,
                                completed: completed
                            )
                        )
                    } else if completedGroup?.confirmation == .success {
                        Text(destinationCardName ?? getFinalCardName())
                            .foregroundColor(BeamColor.Beam.swiftUI)
                            .font(BeamFont.regular(size: 13).swiftUI)
                            .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.1)))
                    }
                }

                Spacer()

                // MARK: - Icon
                if isEditingCardName && (currentCardName != nil || cardSearchField.isEmpty) {
                    if !completed {
                        Icon(name: "shortcut-return", size: 12, color: BeamColor.Generic.placeholder.swiftUI)
                            .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.15)))
                            .onTapGesture {
                                onFinishEditing()
                            }
                    } else if let group = completedGroup {
                        let confirmationIcon = group.confirmation == .success ? "collect-generic" : "tool-close"
                        Icon(name: confirmationIcon, size: 16, color: BeamColor.Generic.text.swiftUI)
                            .transition(AnyTransition.opacity.animation(Animation.easeInOut(duration: 0.15).delay(0.05)))
                            .onTapGesture {
                                if group.confirmation != .failure {
                                    state.navigateToNote(id: group.noteInfo.id)
                                }
                            }
                    }
                }
            }
            .lineLimit(1)
            .padding(.horizontal, BeamSpacing._120)
            .padding(.top, BeamSpacing._80)
            .frame(maxHeight: 42)

            Spacer()

            if !completed {
                // MARK: - Autocomplete
                if isEditingCardName && currentCardName == nil {
                    DestinationNoteAutocompleteList(model: autocompleteModel)
                        .onSelectAutocompleteResult { selectSearchResult() }
                }
                // MARK: - Bottom Half
                Separator(horizontal: true).padding(.horizontal, BeamSpacing._120)
                HStack(spacing: 4) {
                    // MARK: - TextField
                    BeamTextField(
                        text: $addNoteField,
                        isEditing: $isEditingNote,
                        placeholder: "Add note",
                        font: font,
                        textColor: secondLabelTextColor,
                        placeholderColor: placeholderColor
                    ) { _ in
                    } onCommit: { _ in
                        onFinishEditing()
                    } onEscape: {
                        onCancelEditing()
                    }
                    .frame(minHeight: 16)

                    // MARK: - Icon
                    if isEditingNote {
                        Icon(name: "shortcut-return", size: 12, color: BeamColor.Generic.placeholder.swiftUI)
                            .animation(nil)
                            .onTapGesture {
                                onFinishEditing()
                            }
                    }
                }
                .padding(.horizontal, BeamSpacing._120)
                .padding(.vertical, BeamSpacing._100)
            }
        }
        .onAppear {
            todaysCardName = data.todaysName
            if let currentNote = browserTabsManager.currentTab?.noteController.note {
                currentCardName = currentNote.title
                cardSearchField = currentNote.title
                destinationCardName = currentNote.title
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
        .accessibility(identifier: "ShootCardPicker")
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
        if let currentCardName = currentCardName,
            text.count == currentCardName.count - 1 {
            cardSearchField = ""
            searchText = ""
        }
        autocompleteModel.searchText = searchText
        currentCardName = nil
    }
}

extension PointAndShootCardPicker {
    private func onCancelEditing() {
        guard !completed else { return }
        onComplete?(nil, nil)
    }
    // MARK: - onFinishEditing
    private func onFinishEditing(_ withCommand: Bool = false) {
        guard !completed else { return }
        shootCompleted = true
        // Select search result
        if withCommand {
            selectSearchResult(withCommand)
        }
        // if cardname is either "Today" or todays date e.g. "21 September 2021" we should create a journal note
        if !withCommand,
           let date = autocompleteModel.getDateForCardReplacementJournalNote(cardSearchField) {
            let note = fetchOrCreateJournalNote(date: date)
            onComplete?(note, addNoteField)
        } else {
            let cardName = getFinalCardName(withCommand)
            let note = fetchOrCreateNote(named: cardName)
            onComplete?(note, addNoteField)
        }
    }

    private func getFinalCardName(_ withCommand: Bool = false) -> String {
        if withCommand {
            return cardSearchField
        } else if !cardSearchField.isEmpty {
            return autocompleteModel.realNameForCardName(cardSearchField)
        } else if let currentCardName = currentCardName {
            return currentCardName
        } else if let lastCardName = destinationCardName {
            return lastCardName
        } else {
            return data.todaysName
        }
    }
}

extension PointAndShootCardPicker {
    // MARK: - selectSearchResult
    private func selectSearchResult(_ withCommand: Bool = false) {
        guard !cardSearchField.isEmpty else { return }
        guard let result = autocompleteModel.selectedResult else {
            Logger.shared.logError("Failed to return a selected autocompleteModel result", category: .pointAndShoot)
            return
        }

        var finalCardName: String
        // with command pressed, find or create a note with exact card search string
        if withCommand {
            finalCardName = cardSearchField
            fetchOrCreateNote(named: finalCardName)
        } else {
            // else get the card name from the autocomplete model
            finalCardName = autocompleteModel.realNameForCardName(result.text)
        }
        // Update search input to real card name
        cardSearchField = finalCardName
        // Update search input to real card name
        currentCardName = finalCardName
        // Update placeholder
        destinationCardName = finalCardName
    }
}

extension PointAndShootCardPicker {
    // MARK: - fetchOrCreateNote
    @discardableResult
    private func fetchOrCreateNote(named name: String) -> BeamNote {
        let note = BeamNote.fetchOrCreate(title: name)
        note.save()
        return note
    }

    // MARK: - fetchOrCreateJournalNote
    @discardableResult
    private func fetchOrCreateJournalNote(date: Date) -> BeamNote {
        let note = BeamNote.fetchOrCreateJournalNote(date: date)
        note.save()
        return note
    }
}

extension PointAndShootCardPicker {
    // MARK: - onComplete
    func onComplete(perform action: @escaping (_ targetNote: BeamNote?, _ note: String?) -> Void ) -> Self {
        var copy = self
        copy.onComplete = action
        return copy
    }
}

extension PointAndShootCardPicker {
    /// Temporarily allow animation on the parent wrapper
    func enableResizeAnimation() {
        DispatchQueue.main.async {
            self.allowAnimation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1)) {
                self.allowAnimation = false
            }
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
