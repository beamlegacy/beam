//
//  CardSwitcher.swift
//  Beam
//
//  Created by Remi Santos on 11/05/2021.
//

import SwiftUI
import BeamCore

struct CardSwitcher: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var windowInfo: BeamWindowInfo
    @Environment(\.undoManager) var undoManager

    var currentNote: BeamNote?
    @ObservedObject var viewModel: NoteSwitcherViewModel
    @State private var overflowButtonPosition = CGPoint.zero

    private let maxNoteTitleLength = 40
    static let elementSpacing = 5.0
    static let usePinnedInsteadOfRecentsNotes = true

    private var separator: some View {
        Separator(rounded: true, color: BeamColor.ToolBar.horizontalSeparator)
            .frame(height: 16)
            .padding(.horizontal, 1.5)
            .blendModeLightMultiplyDarkScreen()
    }

    private var isAllNotesActive: Bool {
        state.mode == .page && state.currentPage?.id == .allNotes
    }

    var body: some View {
        HStack(spacing: Self.elementSpacing) {
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                ToolbarCapsuleButton(iconName: "editor-journal", text: "Journal", isSelected: state.mode == .today) {
                    state.navigateToJournal(note: nil)
                }
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
                .tooltipOnHover(LocalizedStringKey(Shortcut.AvailableShortcut.showJournal.keysDescription))
                .accessibilityIdentifier("card-switcher-journal")

                ToolbarCapsuleButton(iconName: "editor-allnotes", text: "All Notes", isSelected: isAllNotesActive) {
                    state.navigateToPage(.allNotesWindowPage)
                }
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
                .tooltipOnHover(LocalizedStringKey(Shortcut.AvailableShortcut.showAllNotes.keysDescription))
                .accessibilityIdentifier("card-switcher-all-cards")
            }.modifier(NoteSwitcherFixedElementsWidthMeasuring())

            if shouldDisplaySeparator {
                separator
            }

            notes

            let overflowingElements = viewModel.elements.filter({$0.isOverflowing})
            if !overflowingElements.isEmpty {
                ButtonLabel(icon: "editor-pinned_overflow", customStyle: ButtonLabelStyle(activeBackgroundColor: .clear)) {
                    guard let window = windowInfo.window else { return }
                    let menu = NSMenu()
                    for note in overflowingElements {
                        menu.addItem(withTitle: note.displayTitle) { _ in
                            state.navigateToNote(id: note.id)
                        }
                    }
                    menu.popUp(positioning: nil, at: overflowButtonPosition.flippedPointToTopLeftOrigin(in: window), in: window.contentView)
                }
                .background(GeometryReader { proxy -> Color in
                    let rect = proxy.frame(in: .global)
                    let position = CGPoint(x: rect.origin.x, y: rect.origin.y + rect.height + 10)
                    DispatchQueue.main.async {
                        overflowButtonPosition = position
                    }
                    return Color.clear
                })
                .accessibilityIdentifier("note-overflow-button")
                Spacer()
            }
        }
        .animation(.default, value: windowInfo.isCompactWidth)
    }

    @ViewBuilder private var notes: some View {
        if viewModel.elements.count > 0 {
            HStack(spacing: 0) {
                ForEach(viewModel.elements.filter({ !$0.isOverflowing })) { element in
                    let isToday = state.mode == .today
                    let isActive = !isToday && element.id == currentNote?.id
                    ToolbarCapsuleButton(text: element.displayTitle, isSelected: isActive) {
                        state.navigateToNote(id: element.id)
                    }
                    .accessibilityIdentifier("card-switcher")
                    .contextMenu {
                        BeamNote.contextualMenu(for: element.note, state: state, undoManager: undoManager)
                    }
                }
            }
        }
    }

    private var shouldDisplaySeparator: Bool {
        !viewModel.elements.isEmpty
    }
}

struct CardSwitcher_Previews: PreviewProvider {
    static let state = BeamState()
    static var previews: some View {
        let pinnedManager = state.data.pinnedManager
        state.mode = .today
        return CardSwitcher(viewModel: pinnedManager.viewModel)
            .environmentObject(state)
            .frame(width: 700, height: 80)
    }
}

struct NoteSwitcherFixedElementsWidthPreferenceKey: FloatPreferenceKey { }
struct NoteSwitcherFixedElementsWidthMeasuring: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(
            GeometryReader { proxy in
                Color.clear.preference(key: NoteSwitcherFixedElementsWidthPreferenceKey.self, value: proxy.size.width)
            }, alignment: .center)
    }
}
