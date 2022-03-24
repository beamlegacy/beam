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

    private let barHeight: CGFloat = 42
    private let verticalPadding: CGFloat = BeamSpacing._50
    private var buttonsHeight: CGFloat { barHeight - verticalPadding * 2 }

    private func recentsStack(containerGeometry: GeometryProxy) -> some View {
        GlobalCenteringContainer(containerGeometry: containerGeometry) {
            CardSwitcher(currentNote: currentNote)
                .environmentObject(state.recentsManager)
        }
        .animation(animationEnabled ? .easeInOut(duration: 0.3) : nil)
    }

    private static let scrollLabelStyle: ButtonLabelStyle = {
        var style = ButtonLabelStyle.tinyIconStyle
        style.horizontalPadding = 10
        style.foregroundColor = BeamColor.AlphaGray.swiftUI.opacity(0.70)
        style.hoveredBackgroundColor = Color.clear
        style.activeBackgroundColor = Color.clear
        return style
    }()

    private func scrollJournalDown() {
        guard let stackView = state.cachedJournalStackView, let scrollView = stackView.enclosingScrollView else {
            return
        }
        let height = scrollView.contentView.bounds.height
        let verticalOffset = ModeView.omniboxEndFadeOffsetFor(height: height)
        stackView.scroll(toVerticalOffset: verticalOffset)
    }

    private var journalScrollButton: some View {
        HStack(spacing: 0) {
            ButtonLabel(icon: "editor-journal_scroll", customStyle: Self.scrollLabelStyle, action: scrollJournalDown)
                .cursorOverride(.arrow)
        }
        .frame(maxWidth: .infinity)
        .opacity(state.journalScrollOffset < (state.cachedJournalStackView?.enclosingScrollView?.contentView.bounds.height ?? 0) / 8 ? 1 : 0)
    }

    var body: some View {
        HStack {
            BottomToolBarLeadingIconView(versionChecker: state.data.versionChecker)
            if state.mode == .today {
                journalScrollButton
            } else {
                Spacer(minLength: BeamSpacing._200)
            }
            HStack {
                BottomToolBarTrailingIconView()
                    .environmentObject(state.noteMediaPlayerManager)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(BeamSpacing._100)
        .frame(height: barHeight)
        .frame(maxWidth: .infinity)
    }

    fileprivate static let buttonStyle: ButtonLabelStyle = {
        ButtonLabelStyle(
            font: BeamFont.medium(size: 12).swiftUI,
            spacing: 1,
            foregroundColor: BeamColor.LightStoneGray.swiftUI,
            activeForegroundColor: BeamColor.Niobium.swiftUI,
            backgroundColor: Color.clear,
            hoveredBackgroundColor: Color.clear,
            activeBackgroundColor: BeamColor.Mercury.swiftUI,
            leadingPaddingAdjustment: 4
        )
    }()

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
            ButtonLabel("Help", icon: "help-question", customStyle: WindowBottomToolBar.buttonStyle) {
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
        HStack(spacing: 12) {
            if shouldShowMediaButton {
                mediaButton
                Separator(color: BeamColor.Mercury)
                    .blendModeLightMultiplyDarkScreen()
                    .frame(height: 16)
            }

            newNoteButton
        }
    }

    private var newNoteButton: some View {
        ButtonLabel("New Note", icon: "tool-new", customStyle: WindowBottomToolBar.buttonStyle) {
            state.startNewNote()
        }
        .accessibility(identifier: "NewNoteButton")
    }

    private var mediaButton: some View {
        NoteMediaPlayingButton(playerManager: noteMediaPlayerManager, onOpenNote: { notePlaying in
            state.navigateToNote(notePlaying.note, elementId: notePlaying.elementId)
        }, onMuteNote: { notePlaying in
            if let n = notePlaying {
                noteMediaPlayerManager.toggleMuteNotePlaying(note: n.note)
            } else {
                noteMediaPlayerManager.toggleMuteAll()
            }
        })
    }

    private var shouldShowMediaButton: Bool {
        !noteMediaPlayerManager.playings.isEmpty
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
