//
//  OmniboxV2Box.swift
//  Beam
//
//  Created by Remi Santos on 22/11/2021.
//

import SwiftUI
import BeamCore

struct OmniboxV2Box: View {

    @EnvironmentObject var state: BeamState
    @EnvironmentObject var autocompleteManager: AutocompleteManager
    @EnvironmentObject var browserTabsManager: BrowserTabsManager

    var isLaunchAppear = false
    @State private var modifierFlagsPressed: NSEvent.ModifierFlags?

    private var enableAnimations: Bool {
        !state.windowIsResizing
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
    private var isEditingCurrentTabURL: Bool {
        autocompleteManager.searchQuery == browserTabsManager.currentTab?.url?.absoluteString
    }

    private var shouldShowAutocompleteResults: Bool {
        !autocompleteManager.autocompleteResults.isEmpty &&
        !isEditingCurrentTabURL
    }

    private var boxIsPulled: Bool {
        (autocompleteManager.autocompleteResults.isEmpty && autocompleteManager.searchQuery.isEmpty) &&
        [.today, .note].contains(state.mode)
    }

    private var showPressedState: Bool {
        autocompleteManager.animateInputingCharacter
    }

    var body: some View {
        OmniboxV2Box.Background(isPulled: boxIsPulled, isPressingCharacter: showPressedState) {
            VStack(spacing: 0) {
                HStack(spacing: BeamSpacing._200) {
                    OmniBarSearchField(isEditing: isEditingBinding,
                                       modifierFlagsPressed: $modifierFlagsPressed,
                                       enableAnimations: false,
                                       designV2: true)
                        .frame(height: 46)
                        .frame(maxWidth: .infinity)
                    if !autocompleteManager.searchQuery.isEmpty {
                        OmniboxV2ClearButton()
                            .simultaneousGesture(TapGesture().onEnded {
                                autocompleteManager.resetQuery()
                            })
                    }
                }
                .padding(.horizontal, 14)
                .overlay(shouldShowAutocompleteResults ? Separator(horizontal: true) : nil,
                         alignment: .bottom)
                .frame(height: 46, alignment: .top)
                if shouldShowAutocompleteResults {
                    AutocompleteList(selectedIndex: $autocompleteManager.autocompleteSelectedIndex, elements: $autocompleteManager.autocompleteResults, modifierFlagsPressed: modifierFlagsPressed,
                                     designV2: true)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .animation(BeamAnimation.easeInOut(duration: 0.3), value: autocompleteManager.autocompleteResults)
        .animation(BeamAnimation.easeInOut(duration: 0.3), value: autocompleteManager.searchQuery.isEmpty)
        .onAppear {
            if !isLaunchAppear && autocompleteManager.searchQuery.isEmpty {
                autocompleteManager.getEmptyQuerySuggestions()
            }
        }
    }

    private func setIsEditing(_ editing: Bool) {
        state.focusOmniBox = editing
        if editing {
            if state.mode == .web, let url = browserTabsManager.currentTab?.url?.absoluteString {
                autocompleteManager.resetQuery()
                autocompleteManager.searchQuerySelectedRange = url.wholeRange
                autocompleteManager.setQuery(url, updateAutocompleteResults: false)
            }
        } else if state.mode != .web || browserTabsManager.currentTab?.url != nil {
            autocompleteManager.resetQuery()
        }
    }
}

/// Places the OmniboxV2Box in the window relative to the context.
/// And sets up transitions.
struct OmniboxV2Container: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var autocompleteManager: AutocompleteManager
    @EnvironmentObject var browserTabsManager: BrowserTabsManager

    @State private var isFirstLaunchAppear = true
    @State private var savedTopOffset: CGFloat?
    private var topOffset: CGFloat {
        if let savedTopOffset = savedTopOffset {
            return savedTopOffset
        }
        let offset: CGFloat = state.mode == .web && browserTabsManager.currentTab?.url != nil ? 11 : 100
        DispatchQueue.main.async {
            savedTopOffset = offset
        }
        return offset
    }

    private var showPressedState: Bool {
        autocompleteManager.animateInputingCharacter
    }

    var body: some View {
        Group {
            if state.focusOmniBox {
                OmniboxV2Box(isLaunchAppear: isFirstLaunchAppear)
                    .frame(width: 600)
                    .padding(.top, topOffset)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.animation(BeamAnimation.defaultiOSEasing(duration: 0.04).delay(0.02))
                                .combined(with:
                                                .animatableOffset(offset: CGSize(width: 0, height: 3)).animation(BeamAnimation.defaultiOSEasing(duration: 0.3)))
                                .combined(with:
                                                .scale(scale: 0.95).animation(BeamAnimation.spring(stiffness: 480, damping: 34))),
                            removal: .opacity.animation(BeamAnimation.easeInOut(duration: 0.1))
                                .combined(with:
                                                .animatableOffset(offset: CGSize(width: 0, height: 3)).animation(BeamAnimation.defaultiOSEasing(duration: 0.3)))
                                .combined(with:
                                                .scale(scale: 0.9).animation(BeamAnimation.defaultiOSEasing(duration: 0.25)))
                        )
                    )
                    .animatableOffsetEffect(offset: CGSize(width: 0, height: showPressedState ? 10 : 0))
                    .onAppear {
                        guard isFirstLaunchAppear else { return }
                        DispatchQueue.main.async {
                            isFirstLaunchAppear = false
                        }
                    }
                    .onDisappear {
                        savedTopOffset = nil
                    }
            }
        }
    }
}

struct OmniboxV2Box_Previews: PreviewProvider {
    static let state = BeamState()
    static let autocompleteManager = AutocompleteManager(with: BeamData(), searchEngine: GoogleSearch())

    static var autocompleteManagerWithResults: AutocompleteManager {
        let mngr = AutocompleteManager(with: BeamData(), searchEngine: MockSearchEngine())
        mngr.setQuery("Res", updateAutocompleteResults: false)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(100)) {
            mngr.autocompleteResults = [
                .init(text: "Result A", source: .autocomplete),
                .init(text: "Result B", source: .autocomplete),
                .init(text: "Result C", source: .autocomplete),
                .init(text: "Result D", source: .autocomplete)
            ]
        }
        return mngr
    }
    static var previews: some View {
        Group {
            OmniboxV2Box()
                .environmentObject(state)
                .environmentObject(state.autocompleteManager)
                .environmentObject(state.browserTabsManager)
        }
        .padding()
        .frame(width: 600, height: 150, alignment: .top)
        Group {
            OmniboxV2Box()
                .environmentObject(state)
                .environmentObject(autocompleteManagerWithResults)
                .environmentObject(state.browserTabsManager)
        }
        .padding()
        .frame(width: 600, height: 300, alignment: .top)
    }
}
