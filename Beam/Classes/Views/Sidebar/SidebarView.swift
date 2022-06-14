//
//  SidebarView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 17/05/2022.
//

import SwiftUI
import BeamCore
import Combine

struct SidebarView: View {

    @EnvironmentObject var state: BeamState
    @Environment(\.colorScheme) var colorScheme

    @State private var dismissTimerCancellable: Cancellable?
    @State private var didAppear = false
    @ObservedObject var pinnedManager: PinnedNotesManager

    private var shouldAutodismiss = false

    init(pinnedManager: PinnedNotesManager) {
        self.pinnedManager = pinnedManager
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3.0) {
            if didAppear {
                Group {
                    journal
                    allNotes
                    Separator(horizontal: true)
                        .padding(.top, 10)
                        .padding(.bottom, -3)
                        .blendModeLightMultiplyDarkScreen()
                    ScrollView {
                        VStack(spacing: 3.0) {
                            pinned
                            recents
                        }
                        .padding(.top, 10)
                    }
                    Spacer(minLength: 0)
                    Separator(horizontal: true)
                        .padding(.top, -6)
                        .padding(.bottom, 1)
                        .blendModeLightMultiplyDarkScreen()
                    footer
                }.transition(.animatableOffset(offset: CGSize(width: -40, height: 0)).animation(BeamAnimation.defaultiOSEasing(duration: 0.20)))
            }
        }
        .padding(.top, 144)
        .padding(.horizontal, 10)
        .background(sidebarBackground)
        .onHover { hover in
            if hover {
                dismissTimerCancellable?.cancel()
            } else if shouldAutodismiss {
                dismissTimerCancellable = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect().sink(receiveValue: { _ in
                    state.showSidebar = false
                    dismissTimerCancellable?.cancel()
                })
            }
        }
        .onAppear {
            didAppear = true
        }
        .onDisappear {
            dismissTimerCancellable?.cancel()
        }
        .transition(sidebarTransition)
        .offset(x: -3, y: 0)
        .frame(width: 243)
    }

    private var journal: some View {
        SidebarListPageButton(iconName: "editor-journal", text: "Journal", isSelected: state.mode == .today) {
            state.showSidebar = false
            state.navigateToJournal(note: nil)
        }
        .tooltipOnHover(Shortcut.AvailableShortcut.showJournal.keysDescription, alignment: .top)
        .accessibilityIdentifier("sidebar-journal")
    }

    private var allNotes: some View {
        SidebarListPageButton(iconName: "editor-allnotes", text: "All Notes", isSelected: isAllNotesActive) {
            state.showSidebar = false
            state.navigateToPage(.allNotesWindowPage)
        }
        .tooltipOnHover(Shortcut.AvailableShortcut.showAllNotes.keysDescription, alignment: .top)
        .accessibilityIdentifier("sidebar-all-notes")
    }

    @ViewBuilder private var pinned: some View {
        if pinnedManager.pinnedNotes.count > 0 {
            SidebarListSectionTitle(title: "Pinned", iconName: "sidebar-pin")
            ForEach(pinnedManager.pinnedNotes) { note in
                let isActive = note.id == state.currentNote?.id
                SidebarListNoteButton(note: note, pinnedManager: state.data.pinnedManager, isSelected: isActive) {
                    navigateTo(note: note)
                }
            }
        }
    }

    @ViewBuilder private var recents: some View {
        if state.recentsManager.recentNotes.count > 0 {
            SidebarListSectionTitle(title: "Recent", iconName: "editor-recent")
            ForEach(state.recentsManager.recentNotes) { note in
                let isToday = state.mode == .today
                let isActive = !isToday && note.id == state.currentNote?.id
                SidebarListNoteButton(note: note, pinnedManager: state.data.pinnedManager, isSelected: isActive) {
                    navigateTo(note: note)
                }
            }
        }
    }

    @ViewBuilder private var footer: some View {
        SidebarFooterView(username: AuthenticationManager.shared.username)
            .frame(height: 38)
            .padding(.bottom, 8)
            .padding(.leading, 8)
            .padding(.trailing, 6)
    }

    private var sidebarTransition: AnyTransition {
        .asymmetric(insertion: .opacity.animation(BeamAnimation.defaultiOSEasing(duration: 0.15))
                                    .combined(with: .animatableOffset(offset: CGSize(width: -250, height: 0)).animation(BeamAnimation.spring(stiffness: 480, damping: 36))),
                                removal: .opacity.animation(BeamAnimation.defaultiOSEasing(duration: 0.15))
                                    .combined(with: .animatableOffset(offset: CGSize(width: -250, height: 0)).animation(BeamAnimation.spring(stiffness: 480, damping: 36))))
    }

    private var shadowOpacity: CGFloat {
        colorScheme == .light ? 0.1 : 0.3
    }

    private var sideStroke: some View {
        Separator(hairline: true, color: BeamColor.From(color: .white, alpha: sideStrokeAlpha))
    }

    private var sideStrokeAlpha: CGFloat {
        colorScheme == .light ? 0.05 : 0.25
    }

    private var isAllNotesActive: Bool {
        state.mode == .page && state.currentPage?.id == .allNotes
    }

    private var sidebarBackground: some View {
        ZStack {
            BeamColor.Sidebar.background.swiftUI
            VisualEffectView(material: .headerView)
        }
        .overlay(sideStroke, alignment: .trailing)
        .shadow(color: .black.opacity(shadowOpacity), radius: 5, x: 1, y: 0)
    }

    private func navigateTo(note: BeamNote) {
        state.showSidebar = false
        state.navigateToNote(note)
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var state = BeamState()
    static var previews: some View {
        let recent = state.recentsManager
        SidebarView(pinnedManager: state.data.pinnedManager)
            .environmentObject(state)
            .environmentObject(recent)
    }
}
