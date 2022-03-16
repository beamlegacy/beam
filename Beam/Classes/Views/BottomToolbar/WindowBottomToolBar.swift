//
//  WindowBottomToolBar.swift
//  Beam
//
//  Created by Remi Santos on 24/03/2021.
//

import SwiftUI
import BeamCore
import AutoUpdate

struct WindowBottomToolBar: View {
    @EnvironmentObject var state: BeamState
    @EnvironmentObject var windowInfo: BeamWindowInfo

    private var isJournal: Bool {
        state.mode == .today
    }

    private var animationEnabled: Bool {
        !windowInfo.windowIsResizing
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
            BottomToolBarLeadingIconView(versionChecker: state.data.versionChecker)
                .padding(.leading, 10)
                .offset(y: -9)
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

private struct BottomToolBarLeadingIconView: View {

    @ObservedObject var versionChecker: VersionChecker
    @EnvironmentObject var state: BeamState

    var body: some View {
        if shouldShowUpdateStatus {
            SmallUpdateIndicatorView(versionChecker: versionChecker)
        } else {
            helpButton
        }
    }

    private var helpButton: some View {
        GeometryReader { proxy in
            ButtonLabel("Help", icon: "help-question", customStyle: buttonStyle) {
                showHelpAndFeedbackMenuView(proxy: proxy)
            }
            .onReceive(state.$showHelpAndFeedback, perform: { showHelp in
                if showHelp {
                    showHelpAndFeedbackMenuView(proxy: proxy)
                    state.showHelpAndFeedback = false
                }
            })
            .accessibility(identifier: "HelpButton")
        }
    }

    private var shouldShowUpdateStatus: Bool {
        switch versionChecker.state {
        case .noUpdate, .checking: return false
        default: return true
        }
    }

    private let buttonStyle: ButtonLabelStyle = {
        ButtonLabelStyle(
            font: BeamFont.medium(size: 12).swiftUI,
            spacing: 1,
            foregroundColor: BeamColor.LightStoneGray.swiftUI,
            activeForegroundColor: BeamColor.Niobium.swiftUI,
            backgroundColor: BeamColor.Generic.background.swiftUI,
            hoveredBackgroundColor: BeamColor.Generic.background.swiftUI,
            activeBackgroundColor: BeamColor.Mercury.swiftUI,
            leadingPaddingAdjustment: 4
        )
    }()

    private func showHelpAndFeedbackMenuView(proxy: GeometryProxy) {
        let window = CustomPopoverPresenter.shared.presentPopoverChildWindow(useBeamShadow: true)
        let view = HelpAndFeedbackMenuView(window: window)
            .environmentObject(state)

        let buttonFrame = proxy.safeTopLeftGlobalFrame(in: window?.parent)
        var origin = CGPoint(
            x: buttonFrame.origin.x,
            y: buttonFrame.minY - 7
        )
        if let parentWindow = window?.parent {
            origin = origin.flippedPointToBottomLeftOrigin(in: parentWindow)
        }

        window?.setView(with: view, at: origin)
        window?.isMovable = false
        window?.makeKey()
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
