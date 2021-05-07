//
//  WindowBottomToolBar.swift
//  Beam
//
//  Created by Remi Santos on 24/03/2021.
//

import SwiftUI
import BeamCore

struct WindowBottomToolBar: View {
    @EnvironmentObject var state: BeamState

    private var isJournal: Bool {
        return state.mode == .today
    }

    private var animationEnabled: Bool {
        return !state.windowIsResizing
    }

    private var currentNote: BeamNote? {
        return state.currentNote
    }

    private func recentsStack(containerGeometry: GeometryProxy) -> some View {
        GlobalCenteringContainer(enabled: true, containerGeometry: containerGeometry) {
            HStack(spacing: 6) {
                ButtonLabel("Journal", state: state.mode == .today ? .active : .normal) {
                    state.navigateToJournal()
                }
                .fixedSize(horizontal: true, vertical: false)
                if state.recentsManager.recentNotes.count > 0 {
                    Separator()
                    ForEach(state.recentsManager.recentNotes) { note in
                        let isToday = state.mode == .today
                        let isActive = !isToday && note.id == currentNote?.id
                        ButtonLabel(note.title, state: isActive ? .active : .normal)
                            .simultaneousGesture(
                                TapGesture(count: 1).onEnded {
                                    state.navigateToNote(named: note.title)
                                }
                            )
                    }
                }
            }
        }
        .animation(animationEnabled ? .easeInOut(duration: 0.3) : nil)
    }

    var body: some View {
        GeometryReader { geo in
            HStack {
                if let note = currentNote, state.mode == .note {
                    SharingStatusView(model: SharingStatusViewModel(note: note, documentManager: state.data.documentManager))
                }
                Spacer(minLength: 20)
                if [.today, .note].contains(state.mode) {
                    recentsStack(containerGeometry: geo)
                    Spacer(minLength: 20)
                }
                HStack {
                    if state.mode == .today {
                        ButtonLabel("All Cards") {
                            state.navigateToPage(WindowPage.allCardsWindowPage)
                        }
                        Separator()
                    }
                    ButtonLabel("?", customStyle: ButtonLabelStyle(font: BeamFont.medium(size: 11).swiftUI, horizontalPadding: 5, verticalPadding: 2))
                        .overlay(
                            Circle().stroke(BeamColor.Button.activeBackground.swiftUI, lineWidth: 1)
                                .frame(width: 16, height: 16)
                                .offset(x: -0.5)
                        )
                        .frame(width: 18, height: 18)
                        .cornerRadius(9)
                }
                .fixedSize(horizontal: true, vertical: false)
                .padding(.trailing, BeamSpacing._50)
            }
            .padding(.vertical, BeamSpacing._50)
            .background(
                BeamColor.Generic.background.swiftUI
                    .shadow(color: BeamColor.BottomBar.shadow.swiftUI, radius: 0, x: 0, y: -0.5)
            )
            .frame(height: 30)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 30)
    }
}

struct WindowBottomToolBar_Previews: PreviewProvider {
    static var previews: some View {
        let state = BeamState()
        state.mode = .today
        state.currentNote = BeamNote(title: "Note A")
        state.currentNote = BeamNote(title: "Long Note B")
        state.currentNote = BeamNote(title: "Note C ")
        state.currentNote = BeamNote(title: "Last Note D")
        state.currentNote = BeamNote(title: "Current Note")

        return WindowBottomToolBar()
            .environmentObject(state)
            .frame(width: 800)
            .padding()
            .background(Color.gray)
    }
}
