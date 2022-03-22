//
//  PointAndShootCardPicker.swift
//  Beam
//
//  Created by Remi Santos on 07/04/2021.
//
//swiftlint:disable file_length

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
    var onComplete: ((_ targetNote: BeamNote?, _ comment: String?, _ completion: @escaping () -> Void) -> Void)?

    @StateObject private var autocompleteModel = DestinationNoteAutocompleteList.Model()

    @State private var isEditingCardName = true

    @State private var currentCardName: String? {
        didSet {
            textColor = currentCardName == nil ? BeamColor.Generic.text.nsColor : BeamColor.Beam.nsColor
        }
    }
    @State private var cardSearchField = ""
    @State private var cardSearchFieldSelection: Range<Int>?

    @State private var textColor = BeamColor.Generic.text.nsColor
    private let font = BeamFont.regular(size: 13).nsFont
    private let placeholderColor = BeamColor.PointShoot.placeholder.nsColor
    private let secondLabelTextColor = BeamColor.Generic.text.nsColor
    @State private var shootCompleted: Bool = false

    var completed: Bool {
        shootCompleted || completedGroup?.fullPageCollect == true
    }

    private var isTodaysNote: String? {
        browserTabsManager.currentTab?.noteController.noteOrDefault.isTodaysNote ?? false ? data.todaysName : nil
    }

    @State private var destinationCardName: String?
    @State var todaysCardName: String = ""
    @State private var lastInputWasBackspace = false
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

    private var placeholderText: String {
        autocompleteModel.selectedResult?.text ?? todaysCardName
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
                        BeamTextField(text: $cardSearchField,
                                      isEditing: $isEditingCardName,
                                      placeholder: placeholderText,
                                      font: font,
                                      textColor: textColor, placeholderColor: placeholderColor,
                                      selectedRange: cardSearchFieldSelection, selectedRangeColor: selectedRangeColor
                        ) { text in
                            onTextDidChange(text)
                        } onCommit: { modifierFlags in
                            enableResizeAnimation()
                            let withOption = modifierFlags?.contains(.option) ?? false
                            onFinishEditing(withOption)
                        } onEscape: {
                            onCancelEditing()
                        } onTab: {
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
                            Token(text: cardSearchField, currentCardName: currentCardName, tokenize: cursorIsOnCardName,
                                  selectedResult: lastInputWasBackspace ? nil : autocompleteModel.selectedResult?.text, completed: completed)
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
                if completed, let group = completedGroup {
                    let confirmationIcon = group.confirmation == .success ? "collect-generic" : "tool-close"
                    Icon(name: confirmationIcon, width: 16, color: BeamColor.Generic.text.swiftUI)
                        .transition(AnyTransition.opacity.animation(Animation.easeInOut(duration: 0.15).delay(0.05)))
                        .onTapGesture {
                            if group.confirmation != .failure {
                                state.navigateToNote(id: group.noteInfo.id)
                            }
                        }
                }
            }
            .lineLimit(1)
            .padding(.horizontal, BeamSpacing._120)
            .frame(height: 42)
            .blendModeLightMultiplyDarkScreen()

            if !completed {
                // MARK: - Autocomplete
                if currentCardName == nil {
                    DestinationNoteAutocompleteList(model: autocompleteModel)
                        .onSelectAutocompleteResult {
                            onFinishEditing()
                        }
                }
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
            autocompleteModel.useRecents = true
            autocompleteModel.recentsAlwaysShowTodayNote = true
            autocompleteModel.maxNumberOfResults = 3
            autocompleteModel.searchText = cardSearchField

            if !cardSearchField.isEmpty {
                let range = cardSearchField.count..<cardSearchField.count
                cardSearchFieldSelection = range
            }
        }
        .onTapGesture {
            guard let group = completedGroup else { return }
            state.navigateToNote(id: group.noteInfo.id)
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
                        .zIndex(-1) // https://sarunw.com/posts/how-to-fix-zstack-transition-animation-in-swiftui/
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
    // MARK: - Token Component
    struct Token: View {
        var text: String
        var currentCardName: String?
        var tokenize: Bool = false
        var selectedResult: String?
        var completed: Bool = false

        var body: some View {
            Group {
                let color = tokenize ? BeamColor.NotePicker.active.swiftUI : BeamColor.NotePicker.selected.swiftUI
                // MARK: - Current Card Token
                if let name = currentCardName {
                    HStack {
                        Text(name).font(BeamFont.regular(size: 13).swiftUI).hidden()
                            .padding(BeamSpacing._40)
                            .overlay(color.cornerRadius(4.0))
                        Spacer()
                    }
                } else if let result = selectedResult {
                    // MARK: - Autocomplete Token
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
        lastInputWasBackspace = text.count == autocompleteModel.searchText.count - 1
        autocompleteModel.searchText = searchText
        currentCardName = nil
    }
}

extension PointAndShootCardPicker {
    private func onCancelEditing() {
        guard !completed else { return }
        onComplete?(nil, nil, {})
    }
    // MARK: - onFinishEditing
    private func onFinishEditing(_ withOption: Bool = false) {
        guard !completed else { return }
        // Select search result
        selectSearchResult(withOption)

        // if cardname is either "Today" or todays date e.g. "21 September 2021" we should create a journal note
        if !withOption,
           let date = autocompleteModel.getDateForCardReplacementJournalNote(cardSearchField) {
            let note = fetchOrCreateJournalNote(date: date)
            onComplete?(note, nil, {
                shootCompleted = true
            })
        } else {
            let cardName = getFinalCardName(withOption)
            let note = fetchOrCreateNote(named: cardName)
            onComplete?(note, nil, {
                shootCompleted = true
            })
        }
    }

    private func getFinalCardName(_ withOption: Bool = false) -> String {
        if withOption {
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
    private func selectSearchResult(_ withOption: Bool = false) {
        guard let result = autocompleteModel.selectedResult else {
            Logger.shared.logError("Failed to return a selected autocompleteModel result", category: .pointAndShoot)
            return
        }

        var finalCardName: String
        // with command pressed, find or create a note with exact card search string
        if withOption {
            finalCardName = cardSearchField
            fetchOrCreateNote(named: finalCardName)
        } else {
            // else get the note name from the autocomplete model
            finalCardName = autocompleteModel.realNameForCardName(result.information ?? result.text)
        }
        // Update search input to real note name
        cardSearchField = finalCardName
        // Update search input to real note name
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
    func onComplete(perform action: @escaping (_ targetNote: BeamNote?, _ comment: String?, _ completion: @escaping () -> Void) -> Void ) -> Self {
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
