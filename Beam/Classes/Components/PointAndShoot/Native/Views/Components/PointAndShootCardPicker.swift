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
    var onShare: ((_ service: ShareService?) -> Void)?
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
    @State private var userInputtedText: Bool = false

    var completed: Bool {
        shootCompleted || completedGroup?.fullPageCollect == true
    }

    private var isTodaysNote: String? {
        browserTabsManager.currentTab?.noteController.noteOrDefault.isTodaysNote ?? false ? data.todaysName : nil
    }

    @State private var destinationCardName: String?
    @State var todaysCardName: String = ""
    @State private var lastInputWasBackspace = false
    @State private var justCopied = false
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

    private var textFieldView: some View {
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
        } onModifierFlagPressed: { event in
            if shouldShowCopyShareView &&
                event.modifierFlags.contains(.command) && event.keyCode == KeyCode.c.rawValue {
                copyShoot()
                return true
            }
            return false
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
        .accessibility(identifier: "ShootCardPickerTextField")
        .background(
            Token(text: cardSearchField, currentCardName: currentCardName, tokenize: cursorIsOnCardName,
                  selectedResult: lastInputWasBackspace ? nil : autocompleteModel.selectedResult, completed: completed)
        )
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
                        textFieldView
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

            if !completed && currentCardName == nil {
                // MARK: - Autocomplete
                DestinationNoteAutocompleteList(model: autocompleteModel)
                    .onSelectAutocompleteResult {
                        onFinishEditing()
                    }
            }

            if shouldShowCopyShareView {
                copyShareView
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
        .accessibilityElement(children: .contain)
        .accessibility(identifier: "ShootCardPicker")
    }
}

extension PointAndShootCardPicker {
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
        var selectedResult: AutocompleteResult?
        var completed: Bool = false

        private var autocompleteText: String? {
            guard let result = selectedResult else { return nil }
            guard case .note = selectedResult?.source else { return nil }
            let autocompleteText = result.text.replacingOccurrences(of: text, with: "", options: [.anchored, .caseInsensitive])
            guard autocompleteText.lowercased() != result.text.lowercased() && !autocompleteText.isEmpty else { return nil }
            return autocompleteText
        }
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
                } else if let autocompleteText = autocompleteText {
                    // MARK: - Autocomplete Token
                    // only show auto complete inline if we replaced an Occurence the result
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
            }.opacity(!completed ? 1 : 0)
            .animation(.easeInOut(duration: 0.05), value: completed)
        }
    }
}

extension PointAndShootCardPicker {
    /// Temporarily allow animation on the parent wrapper
    private func enableResizeAnimation() {
        DispatchQueue.main.async {
            self.allowAnimation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1)) {
                self.allowAnimation = false
            }
        }
    }
}

extension PointAndShootCardPicker {
    private func onTextDidChange(_ text: String) {
        var searchText = text
        if let currentCardName = currentCardName,
            text.count == currentCardName.count - 1 {
            cardSearchField = ""
            searchText = ""
        }
        userInputtedText = true
        lastInputWasBackspace = text.count == autocompleteModel.searchText.count - 1
        autocompleteModel.searchText = searchText
        currentCardName = nil
    }

    private func onCancelEditing() {
        guard !completed else { return }
        onComplete?(nil, nil, {})
    }

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
    @discardableResult
    private func fetchOrCreateNote(named name: String) -> BeamNote {
        let note = BeamNote.fetchOrCreate(title: name)
        note.save()
        return note
    }

    @discardableResult
    private func fetchOrCreateJournalNote(date: Date) -> BeamNote {
        let note = BeamNote.fetchOrCreateJournalNote(date: date)
        note.save()
        return note
    }
}

// MARK: - Copy & Share
extension PointAndShootCardPicker {
    @objc private class ShareTarget: NSObject {
        var onSelect: ((NSMenuItem) -> Void)?

        @objc func shareShoot(_ sender: Any?) {
            guard let sender = sender as? NSMenuItem else {
                return
            }
            onSelect?(sender)
        }
    }

    private func copyShoot() {
        guard !justCopied else { return }
        onShare?(.copy)
        SoundEffectPlayer.shared.playSound(.beginRecord)
        justCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            justCopied = false
        }
    }

    private func showShareMenu(at point: CGPoint) {
        guard let window = state.associatedWindow else { return }
        let menu = NSMenu()
        menu.font = BeamFont.regular(size: 13).nsFont

        let target = ShareTarget()
        target.onSelect = { item in
            guard let service = item.representedObject as? ShareService else { return }
            onShare?(service)
        }
        ShareService.allCases(except: [.copy]).forEach { service in
            let item = NSMenuItem(
                title: service.title,
                action: nil,
                keyEquivalent: ""
            )
            item.target = target
            item.action = #selector(ShareTarget.shareShoot(_:))
            item.image = NSImage(named: service.icon)
            item.representedObject = service
            menu.addItem(item)
        }

        let position = CGRect(origin: point, size: .zero).flippedRectToBottomLeftOrigin(in: window).origin
        menu.popUp(positioning: nil, at: position, in: window.contentView)
    }

    private var shouldShowCopyShareView: Bool {
        !completed && (cardSearchField.isEmpty || !userInputtedText)
    }

    private var copyShareView: some View {
        VStack(spacing: 0) {
            Separator(horizontal: true)
                .blendModeLightMultiplyDarkScreen()
            HStack {
                ButtonLabel(justCopied ? loc("Copied") : loc("Copy"),
                            icon: justCopied ? "collect-generic" : "editor-url_copy_16") {
                    copyShoot()
                }
                Spacer()
                HStack(spacing: 0) {
                    Spacer()
                    ButtonLabel(loc("Share"), icon: "social-share")
                        .opacity(0)
                        .accessibility(hidden: true)
                        .overlay(GeometryReader { proxy in
                            ButtonLabel(loc("Share"), icon: "social-share") {
                                let frame = proxy.frame(in: .global)
                                let point = CGPoint(x: frame.minX, y: frame.maxY + 8)
                                showShareMenu(at: point)
                            }
                            .accessibilityIdentifier("share")
                        })
                }
            }
            .padding(BeamSpacing._80)
            .blendModeLightMultiplyDarkScreen()
        }
    }
}

struct ShootCardPicker_Previews: PreviewProvider {
    @State static var allowAnimation: Bool = false
    static let data = BeamData()
    static var previews: some View {
        PointAndShootCardPicker(allowAnimation: $allowAnimation)
            .environmentObject(data)
    }
}
