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
        state.mode == .today
    }

    private var animationEnabled: Bool {
        !state.windowIsResizing
    }

    private var currentNote: BeamNote? {
        state.currentNote
    }

    private let barHeight: CGFloat = 30
    private let verticalPadding: CGFloat = BeamSpacing._50
    private var buttonsHeight: CGFloat { barHeight - verticalPadding * 2 }

    private func recentsStack(containerGeometry: GeometryProxy) -> some View {
        GlobalCenteringContainer(containerGeometry: containerGeometry) {
            CardSwitcher(currentNote: currentNote)
                .environmentObject(state.recentsManager)
        }
        .animation(animationEnabled ? .easeInOut(duration: 0.3) : nil)
    }

    var body: some View {
        HStack {
            SmallUpdateIndicatorView(versionChecker: state.data.versionChecker)
                .padding(.leading, 7)
                .offset(x: 0, y: -6)
            Spacer(minLength: 20)
            HStack {
                BottomToolBarTrailingIconView()
                    .environmentObject(state.noteMediaPlayerManager)
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.trailing, BeamSpacing._70)
        }
        .padding(.vertical, BeamSpacing._70)
        .frame(height: barHeight)
        .frame(maxWidth: .infinity)
    }
}

private struct BottomToolBarTrailingIconView: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var noteMediaPlayerManager: NoteMediaPlayerManager

    var body: some View {
        Group {
            if noteMediaPlayerManager.playings.count > 0 {
                NoteMediaPlayingButton(playerManager: noteMediaPlayerManager, onOpenNote: { notePlaying in
                    state.navigateToNote(notePlaying.note, elementId: notePlaying.elementId)
                }, onMuteNote: { notePlaying in
                    if let n = notePlaying {
                        noteMediaPlayerManager.toggleMuteNotePlaying(note: n.note)
                    } else {
                        noteMediaPlayerManager.toggleMuteAll()
                    }
                })
                .padding(.trailing, BeamSpacing._50)
            } else {
                GeometryReader { proxy in
                    ButtonLabel("?", customStyle: ButtonLabelStyle(font: BeamFont.medium(size: 11).swiftUI, horizontalPadding: 5, verticalPadding: 2)) {
                        let window = CustomPopoverPresenter.shared.presentPopoverChildWindow()
                        let view = HelpAndFeedbackMenuView(window: window)
                            .environmentObject(state)
                        let buttonFrame = proxy.safeTopLeftGlobalFrame(in: window?.parent)
                        let y = buttonFrame.minY - 7
                        let x = buttonFrame.origin.x - HelpAndFeedbackMenuView.menuWidth + 16
                        var origin = CGPoint(x: x, y: y)
                        if let parentWindow = window?.parent {
                            origin = origin.flippedPointToBottomLeftOrigin(in: parentWindow)
                        }
                        window?.setView(with: view, at: origin)
                        window?.isMovable = false
                        window?.makeKey()
                    }
                    .accessibility(identifier: "HelpButton")
                    .background(
                        Circle()
                            .foregroundColor(BeamColor.Generic.background.swiftUI)
                            .frame(width: 16, height: 16)
                            .offset(x: -0.5)
                    )
                    .overlay(
                        Circle().stroke(BeamColor.Button.activeBackground.swiftUI, lineWidth: 1)
                            .frame(width: 16, height: 16)
                            .offset(x: -0.5)
                    )
                    .frame(width: 18, height: 18)
                    .cornerRadius(9)
                }.frame(width: 18, height: 18)
            }
        }
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
