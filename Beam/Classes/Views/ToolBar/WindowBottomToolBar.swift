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

    var isJournal: Bool {
        return state.mode == .today
    }

    private var animationEnabled: Bool {
        return !state.windowIsResizing
    }

    var body: some View {
        GeometryReader { geo in
            HStack {
                if let currentNote = state.currentNote, state.mode == .note {
                    HStack(spacing: 4) {
                        ButtonLabel(currentNote.isPublic ? "Public" : "Private", variant: .dropdown)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                Spacer(minLength: 20)
                GlobalCenteringContainer(enabled: true, containerGeometry: geo) {
                    HStack(spacing: 6) {
                        ButtonLabel("Journal", state: state.mode == .today ? .active : .normal)
                            .simultaneousGesture(
                                TapGesture(count: 1).onEnded {
                                    state.navigateToJournal()
                                }
                            )
                            .fixedSize(horizontal: true, vertical: false)
                        if state.recentsManager.recentNotes.count > 0 {
                            Separator()
                            ForEach(state.recentsManager.recentNotes) { note in
                                let isToday = state.mode == .today
                                let isActive = !isToday && note.id == state.currentNote?.id
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
                Spacer(minLength: 20)
                HStack {
                    if state.mode == .today {
                        ButtonLabel("All Cards")
                        Separator()
                    }
                    ButtonLabel("?", customStyle: ButtonLabelStyle(font: NSFont.beam_medium(ofSize: 11).toSwiftUIFont(), horizontalPadding: 5, verticalPadding: 2))
                        .overlay(
                            Circle().stroke(Color(.buttonActiveBackgroundColor), lineWidth: 1)
                                .frame(width: 16, height: 16)
                                .offset(x: -0.5)
                        )
                        .frame(width: 18, height: 18)
                        .cornerRadius(9)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(5)
            .background(
                Color(.bottomBarBackgroundColor)
                    .shadow(color: Color(.bottomBarShadowColor), radius: 0, x: 0, y: -0.5)
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
