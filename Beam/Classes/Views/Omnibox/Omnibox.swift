//
//  Omnibox.swift
//  Beam
//
//  Created by Remi Santos on 22/11/2021.
//

import SwiftUI
import BeamCore

struct Omnibox: View {

    static let defaultHeight: CGFloat = 50

    @EnvironmentObject var state: BeamState
    @EnvironmentObject var autocompleteManager: AutocompleteManager
    @EnvironmentObject var browserTabsManager: BrowserTabsManager

    var isInsideNote = false
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
                HStack(spacing: BeamSpacing._200) {
                    OmniboxSearchField(isEditing: isEditingBinding,
                                       modifierFlagsPressed: $modifierFlagsPressed,
                                       enableAnimations: false)
                        .frame(height: Self.defaultHeight)
                        .frame(maxWidth: .infinity)
                    if !autocompleteManager.searchQuery.isEmpty {
                        OmniboxClearButton()
                            .simultaneousGesture(TapGesture().onEnded {
                                autocompleteManager.resetQuery()
                            })
                    }
                }
                .padding(.horizontal, 15)
                .overlay(!shouldShowAutocompleteResults ? nil :
                            Separator(horizontal: true, color: BeamColor.Autocomplete.separatorColor)
                            .blendModeLightMultiplyDarkScreen(),
                         alignment: .bottom)
                .frame(height: Self.defaultHeight, alignment: .top)
                if shouldShowAutocompleteResults {
                    AutocompleteList(selectedIndex: $autocompleteManager.autocompleteSelectedIndex, elements: $autocompleteManager.autocompleteResults, modifierFlagsPressed: modifierFlagsPressed)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .animation(BeamAnimation.easeInOut(duration: 0.3), value: autocompleteManager.autocompleteResults)
        .animation(BeamAnimation.easeInOut(duration: 0.3), value: autocompleteManager.searchQuery.isEmpty)
    }

    private func setIsEditing(_ editing: Bool) {
        state.focusOmniBox = editing
    }
}

/// Places the Omnibox in the window relative to the context.
/// And sets up transitions.
struct OmniboxContainer: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var autocompleteManager: AutocompleteManager
    @EnvironmentObject var browserTabsManager: BrowserTabsManager

    private let boxWidth: CGFloat = 680
    private let boxMinX: CGFloat = 87

    @State private var isFirstLaunchAppear = true
    private func boxOffset(with containerGeometry: GeometryProxy) -> CGSize {
        var offset: CGSize = CGSize(width: 0, height: 190)

        if boxIsInsideNote {
            offset.height = 140
        } else if state.mode == .web && state.focusOmniBoxFromTab && browserTabsManager.currentTab?.url != nil,
                    let currentTabUIFrame = browserTabsManager.currentTabUIFrame {
            var x = currentTabUIFrame.midX - boxWidth / 2
            x = max(boxMinX, x)
            x = min(containerGeometry.size.width - boxWidth - 11, x)
            offset = CGSize(width: x, height: 11)
        }
        return offset
    }

    private var showPressedState: Bool {
        autocompleteManager.animateInputingCharacter
    }

    private var boxIsInsideNote: Bool {
        isFirstLaunchAppear && state.mode == .today
    }

    var body: some View {
        Group {
            if state.focusOmniBox {
                GeometryReader { proxy in
                    let offset = boxOffset(with: proxy)
                    HStack(spacing: 0) {
                        if offset.width != 0 {
                            Rectangle().stroke(Color.clear).frame(width: offset.width, height: 1)
                        } else {
                            Spacer(minLength: 0)
                        }
                        Omnibox(isInsideNote: boxIsInsideNote)
                            .frame(width: boxWidth)
                            .padding(.top, offset.height)
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(customTranstion)
                .animatableOffsetEffect(offset: CGSize(width: 0, height: showPressedState ? 10 : 0))
                .onDisappear {
                    guard isFirstLaunchAppear else { return }
                    DispatchQueue.main.async {
                        isFirstLaunchAppear = false
                    }
                }
            }
        }
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
