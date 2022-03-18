//
//  Omnibox.swift
//  Beam
//
//  Created by Remi Santos on 22/11/2021.
//

import SwiftUI
import BeamCore

struct Omnibox: View {

    static let defaultHeight: CGFloat = 57

    @EnvironmentObject var state: BeamState
    @EnvironmentObject var autocompleteManager: AutocompleteManager
    @EnvironmentObject var browserTabsManager: BrowserTabsManager
    @EnvironmentObject var windowInfo: BeamWindowInfo

    var isInsideNote = false
    @State private var modifierFlagsPressed: NSEvent.ModifierFlags?

    private var enableAnimations: Bool {
        !windowInfo.windowIsResizing
    }
    private var isEditing: Bool {
        state.focusOmniBox
    }
    private var isEditingBinding: Binding<Bool> {
        Binding<Bool>(get: {
            isEditing
        }, set: {
            setIsEditing($0)
        })
    }

    private var shouldShowAutocompleteResults: Bool {
        !autocompleteManager.autocompleteResults.isEmpty
    }

    private var boxIsLow: Bool {
        isInsideNote &&
        autocompleteManager.autocompleteResults.isEmpty &&
        autocompleteManager.searchQuery.isEmpty
    }

    private var showPressedState: Bool {
        autocompleteManager.animateInputingCharacter
    }

    var body: some View {
        Omnibox.Background(isLow: boxIsLow, isPressingCharacter: showPressedState) {
            VStack(spacing: 0) {
                HStack(spacing: BeamSpacing._180) {
                    OmniboxSearchField(isEditing: isEditingBinding,
                                       modifierFlagsPressed: $modifierFlagsPressed,
                                       enableAnimations: false)
                        .frame(height: Self.defaultHeight)
                        .frame(maxWidth: .infinity)
                    if !autocompleteManager.searchQuery.isEmpty {
                        OmniboxClearButton()
                            .simultaneousGesture(TapGesture().onEnded {
                                autocompleteManager.setQuery("", updateAutocompleteResults: true)
                            })
                    }
                }
                .padding(.horizontal, BeamSpacing._180)
                .overlay(!shouldShowAutocompleteResults ? nil :
                            Separator(horizontal: true, color: BeamColor.Autocomplete.separatorColor)
                            .blendModeLightMultiplyDarkScreen(),
                         alignment: .bottom)
                .frame(height: Self.defaultHeight, alignment: .top)
                if shouldShowAutocompleteResults {
                    AutocompleteListView(selectedIndex: $autocompleteManager.autocompleteSelectedIndex, elements: $autocompleteManager.autocompleteResults, modifierFlagsPressed: modifierFlagsPressed)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .animation(BeamAnimation.easeInOut(duration: 0.3), value: autocompleteManager.autocompleteResults)
    }

    private func setIsEditing(_ editing: Bool) {
        if editing {
            state.startFocusOmnibox(fromTab: state.focusOmniBoxFromTab, updateResults: false)
        } else {
            state.stopFocusOmnibox()
        }
    }
}

/// Places the Omnibox in the window relative to the context.
/// And sets up transitions.
struct OmniboxContainer: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var autocompleteManager: AutocompleteManager
    @EnvironmentObject var browserTabsManager: BrowserTabsManager
    var containerGeometry: GeometryProxy

    private let boxWidth: CGFloat = 760
    private let boxMinX: CGFloat = 11
    private let boxMinXInToolBar: CGFloat = 87
    private let boxMaxX: CGFloat = 11
    private let boxMinY: CGFloat = 11

    static func topOffsetForJournal(height: CGFloat) -> CGFloat {
        return height * 0.3
    }
    static let minDistanceFromOmniboxToFirstNote = CGFloat(30)
    static func firstNoteTopOffsetForJournal(height: CGFloat) -> CGFloat {
        let boxOffset = topOffsetForJournal(height: height)
        return boxOffset + max(minDistanceFromOmniboxToFirstNote, height * 0.15)
    }

    private var opacity: CGFloat {
        guard boxIsInsideNote, autocompleteManager.searchQuery.isEmpty
        else {
            return 1.0
        }
        guard state.showOmnibox else { return 0.0 }
        let omniboxStartFadeOffset = ModeView.omniboxStartFadeOffsetFor(height: containerGeometry.size.height)
        let omniboxEndFadeOffset = ModeView.omniboxEndFadeOffsetFor(height: containerGeometry.size.height)
        let scrollOffset = state.journalScrollOffset + 52
        if scrollOffset < omniboxStartFadeOffset {
            return 1.0
        } else if scrollOffset > omniboxEndFadeOffset && state.focusOmniBox {
            return 1.0
        }
        let v = scrollOffset.clamp(omniboxStartFadeOffset, omniboxEndFadeOffset)
        let value = 1.0 - v / omniboxEndFadeOffset
        return value
    }
    private var boxOffset: CGSize {
        var offset: CGSize = CGSize(width: 0, height: 190)

        if boxIsInsideNote || state.omniboxWasShownFromJournalTop {
            offset.height = Self.topOffsetForJournal(height: containerGeometry.size.height)
        } else if state.mode == .web && state.focusOmniBoxFromTab && browserTabsManager.currentTab?.url != nil,
                    let currentTabUIFrame = browserTabsManager.currentTabUIFrame {
            let x = max(boxMinXInToolBar, currentTabUIFrame.midX - boxWidth / 2)
            offset = CGSize(width: x, height: boxMinY)
        }
        return offset
    }
    private var showPressedState: Bool {
        autocompleteManager.animateInputingCharacter
    }

    private var boxIsInsideNote: Bool {
        let height = containerGeometry.size.height
        let endOffset = ModeView.omniboxEndFadeOffsetFor(height: height)
        let result = state.mode == .today &&
        ((state.journalScrollOffset <= endOffset) || !state.focusOmniBox)
        return result
    }

    private var boxInstance: some View {
        VStack(spacing: 0) {
            let offset = boxOffset
            Spacer(minLength: boxMinY)
                .frame(maxHeight: offset.height)
            HStack(spacing: 0) {
                Spacer(minLength: boxMinX)
                    .if(offset.width != 0) {
                        $0.frame(maxWidth: offset.width != 0 ? offset.width : .infinity)
                    }
                Omnibox(isInsideNote: boxIsInsideNote)
                    .frame(idealWidth: boxWidth, maxWidth: boxWidth)
                Spacer(minLength: boxMaxX)
            }
            Spacer(minLength: boxMinY)
        }
    }
    var body: some View {
        Group {
            if state.showOmnibox {
                boxInstance
                .transition(.asymmetric(insertion: .opacity.animation(.easeInOut(duration: 0.1)),
                                        removal: .identity))
                .onDisappear {
                    if state.keepDestinationNote {
                        state.keepDestinationNote = false
                    }
                }
            } else if state.focusOmniBox {
                boxInstance
                .transition(customTranstion)
                .animatableOffsetEffect(offset: CGSize(width: 0, height: showPressedState ? 10 : 0))
                .onDisappear {
                    if state.keepDestinationNote {
                        state.keepDestinationNote = false
                    }
                }
            }
        }.opacity(opacity)
    }

    private var customTranstion: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(BeamAnimation.defaultiOSEasing(duration: 0.06))
                .combined(with:
                                .scale(scale: 0.96).animation(BeamAnimation.easeInOut(duration: 0.1))),
            removal: .opacity.animation(BeamAnimation.easeInOut(duration: 0.1))
                .combined(with:
                                .scale(scale: 0.9).animation(BeamAnimation.defaultiOSEasing(duration: 0.25)))
        )
    }
}

struct Omnibox_Previews: PreviewProvider {
    static let state = BeamState()
    static let autocompleteManager = AutocompleteManager(searchEngine: GoogleSearch(), beamState: nil)

    static var autocompleteManagerWithResults: AutocompleteManager {
        let mngr = AutocompleteManager(searchEngine: MockSearchEngine(), beamState: nil)
        mngr.setQuery("Res", updateAutocompleteResults: false)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(100)) {
            mngr.autocompleteResults = [
                .init(text: "Result A", source: .searchEngine),
                .init(text: "Result B", source: .searchEngine),
                .init(text: "Result C", source: .searchEngine),
                .init(text: "Result D", source: .searchEngine)
            ]
        }
        return mngr
    }
    static var previews: some View {
        Group {
            Omnibox()
                .environmentObject(state)
                .environmentObject(state.autocompleteManager)
                .environmentObject(state.browserTabsManager)
        }
        .padding()
        .frame(width: 600, height: 150, alignment: .top)
        Group {
            Omnibox()
                .environmentObject(state)
                .environmentObject(autocompleteManagerWithResults)
                .environmentObject(state.browserTabsManager)
        }
        .padding()
        .frame(width: 600, height: 300, alignment: .top)
    }
}
