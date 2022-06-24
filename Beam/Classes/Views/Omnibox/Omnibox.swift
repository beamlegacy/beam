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
    static let incognitoDefaultHeight: CGFloat = 207

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
        state.omniboxInfo.isFocused
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
        autocompleteManager.searchQuery.isEmpty &&
        (autocompleteManager.mode == .general && !autocompleteManager.isPreparingForAnimatingToMode && autocompleteManager.animatingToMode == nil)
    }

    private var showPressedState: Bool {
        autocompleteManager.animateInputingCharacter
    }

    var body: some View {
        Omnibox.Background(isLow: boxIsLow, isPressingCharacter: showPressedState) {
            VStack(spacing: 0) {
                HStack(spacing: BeamSpacing._180) {
                    OmniboxSearchField(isEditing: isEditingBinding,
                                       modifierFlagsPressed: $modifierFlagsPressed)
                        .animation(nil)
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
                    AutocompleteListView(selectedIndex: $autocompleteManager.autocompleteSelectedIndex,
                                         elements: autocompleteManager.autocompleteResults,
                                         modifierFlagsPressed: modifierFlagsPressed)
                } else if state.isIncognito && isInsideNote {
                    OmniboxIncognitoExplanation()
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .simultaneousGesture(TapGesture().onEnded {
            guard !state.omniboxInfo.isFocused else { return }
            state.startFocusOmnibox(updateResults: false)
        })
    }

    private func setIsEditing(_ editing: Bool) {
        if editing {
            state.startFocusOmnibox(fromTab: state.omniboxInfo.wasFocusedFromTab, updateResults: false)
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

    private let boxMinWidth: CGFloat = 600
    private let boxDefaultWidth: CGFloat = 680
    private let boxMinX: CGFloat = 20
    private var boxMinXInToolBar: CGFloat {
        state.useSidebar ? 117 : 87
    }
    private let boxMaxX: CGFloat = 20
    private let boxMaxXInToolBar: CGFloat = 11
    private let boxMinY: CGFloat = 11
    private let editorLeadingPercentage = PreferencesManager.editorLeadingPercentage
    private var boxIdealWidth: CGFloat {
        if boxIsInsideNote {
            let container = containerGeometry.size
            let editorWidth = BeamTextEdit.textNodeWidth(for: container)
            let editorLeading = (container.width - editorWidth) * (editorLeadingPercentage / 100)
            return (container.width - (editorLeading * 2)).clamp(boxMinWidth, 800)
        }
        return boxDefaultWidth
        // uncomment this when the sidebar is not an overlay
        // state.showSidebar ? boxMinWidth : boxDefaultWidth
    }

    static func topOffsetForJournal(height: CGFloat) -> CGFloat {
        return height * 0.3
    }
    static let minDistanceFromOmniboxToFirstNote = CGFloat(30)
    static func firstNoteTopOffsetForJournal(height: CGFloat) -> CGFloat {
        let boxOffset = topOffsetForJournal(height: height)
        return boxOffset + max(minDistanceFromOmniboxToFirstNote, height * 0.15)
    }

    private var opacity: CGFloat {
        guard boxIsInsideNote else { return 1.0 }
        guard state.omniboxInfo.isShownInJournal || !state.omniboxInfo.wasFocusedFromJournalTop else { return 0.0 }
        let omniboxStartFadeOffset = ModeView.omniboxStartFadeOffsetFor(height: containerGeometry.size.height)
        let omniboxEndFadeOffset = ModeView.omniboxEndFadeOffsetFor(height: containerGeometry.size.height)
        let scrollOffset = state.journalScrollOffset + 52
        if scrollOffset < omniboxStartFadeOffset {
            return 1.0
        } else if scrollOffset > omniboxEndFadeOffset && state.omniboxInfo.isFocused {
            return 1.0
        }
        let v = scrollOffset.clamp(omniboxStartFadeOffset, omniboxEndFadeOffset)
        let value = 1.0 - v / omniboxEndFadeOffset
        return value
    }

    private var boxOffset: CGSize {
        var offset: CGSize = CGSize(width: 0, height: 190)

        if boxIsInsideNote || state.omniboxInfo.wasFocusedFromJournalTop {
            offset.height = Self.topOffsetForJournal(height: containerGeometry.size.height)
        } else if boxIsInsideToolbar, let currentTabUIFrame = browserTabsManager.currentTabUIFrame {
            var x = max(boxMinXInToolBar, currentTabUIFrame.midX - boxIdealWidth / 2)
            if (x + boxIdealWidth + boxMaxXInToolBar) > containerGeometry.size.width {
                x = max(boxMinXInToolBar, containerGeometry.size.width - boxIdealWidth - boxMaxXInToolBar)
            }
            offset = CGSize(width: x, height: boxMinY)
        }
        return offset
    }
    private var showPressedState: Bool {
        autocompleteManager.animateInputingCharacter || autocompleteManager.isPreparingForAnimatingToMode
    }

    private var boxIsInsideToolbar: Bool {
        state.mode == .web && state.omniboxInfo.wasFocusedFromTab && browserTabsManager.currentTab?.url != nil
    }

    private var boxIsInsideNote: Bool {
        let height = containerGeometry.size.height
        guard !state.omniboxInfo.isFocused || state.omniboxInfo.wasFocusedFromJournalTop else { return false }
        let endOffset = ModeView.omniboxEndFadeOffsetFor(height: height)
        let result = state.mode == .today &&
        ((state.journalScrollOffset <= endOffset) || !state.omniboxInfo.isFocused)
        return result
    }

    private var boxInstance: some View {
        VStack(spacing: 0) {
            let offset = boxOffset
            let boxIsInsideToolbar = boxIsInsideToolbar
            let boxWidth = boxIdealWidth
            Spacer(minLength: boxMinY)
                .frame(maxHeight: offset.height)
            HStack(spacing: 0) {
                Spacer(minLength: boxIsInsideToolbar ? boxMinXInToolBar : boxMinX)
                    .if(offset.width != 0) {
                        $0.frame(maxWidth: offset.width)
                    }
                Omnibox(isInsideNote: boxIsInsideNote)
                    .frame(minWidth: boxMinWidth, idealWidth: boxWidth, maxWidth: boxWidth)
                    .layoutPriority(boxIsInsideToolbar ? 1 : 0)
                Spacer(minLength: boxIsInsideToolbar ? boxMaxXInToolBar : boxMaxX)
            }
            Spacer(minLength: boxMinY)
        }
        .animatableOffsetEffect(offset: CGSize(width: 0, height: showPressedState ? 10 : 0))
        .onDisappear {
            DispatchQueue.main.async {
                state.autocompleteManager.resetQuery()
            }

            if state.keepDestinationNote {
                state.keepDestinationNote = false
            }
        }
    }
    var body: some View {
        Group {
            if state.omniboxInfo.isShownInJournal && (!state.omniboxInfo.isFocused || state.omniboxInfo.wasFocusedFromJournalTop) {
                boxInstance
                    .transition(inJournalTranstion)
            } else if state.omniboxInfo.isFocused {
                boxInstance
                    .transition(defaultTranstion)
            }
        }.opacity(opacity)
    }

    private var inJournalTranstion: AnyTransition {
        .asymmetric(insertion: .opacity.animation(.easeInOut(duration: 0.1)),
                    removal: .identity)
    }

    private var defaultTranstion: AnyTransition {
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
    static let incognitoState = BeamState(incognito: true)

    static let autocompleteManager = AutocompleteManager(searchEngine: GoogleSearch(), beamState: nil)

    static var autocompleteManagerWithResults: AutocompleteManager {
        let mngr = AutocompleteManager(searchEngine: MockSearchEngine(), beamState: nil)
        mngr.setQuery("Res", updateAutocompleteResults: false)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(100)) {
            mngr.setAutocompleteResults([
                .init(text: "Result A", source: .searchEngine),
                .init(text: "Result B", source: .searchEngine),
                .init(text: "Result C", source: .searchEngine),
                .init(text: "Result D", source: .searchEngine)
            ])
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
        Group {
            Omnibox()
                .environmentObject(incognitoState)
                .environmentObject(state.autocompleteManager)
                .environmentObject(state.browserTabsManager)
        }
        .padding()
        .frame(width: 600, height: 150, alignment: .top)
        Group {
            Omnibox()
                .environmentObject(incognitoState)
                .environmentObject(autocompleteManagerWithResults)
                .environmentObject(state.browserTabsManager)
        }
        .padding()
        .frame(width: 600, height: 300, alignment: .top)
    }
}
