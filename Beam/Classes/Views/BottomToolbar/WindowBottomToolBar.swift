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
        ButtonLabel(icon: "editor-journal_scroll", customStyle: Self.scrollLabelStyle, action: scrollJournalDown)
            .cursorOverride(.arrow)
            .opacity(state.journalScrollOffset < (state.cachedJournalStackView?.enclosingScrollView?.contentView.bounds.height ?? 0) / 8 ? 1 : 0)
    }

    var body: some View {
        VStack {
            Spacer()
            ZStack {
                HStack(alignment: .lastTextBaseline) {
                    BottomToolBarLeadingIconView(versionChecker: state.data.versionChecker)
                    Spacer()
                    BottomToolBarTrailingIconView()
                        .environmentObject(state.noteMediaPlayerManager)
                }

                if state.mode == .today {
                    journalScrollButton
                }
            }
        }
        .padding(BeamSpacing._100)
    }

    fileprivate static func buttonStyle(withIcon hasIcon: Bool) -> ButtonLabelStyle {
        ButtonLabelStyle(
            font: BeamFont.medium(size: 12).swiftUI,
            spacing: 1,
            foregroundColor: BeamColor.LightStoneGray.swiftUI,
            activeForegroundColor: BeamColor.Niobium.swiftUI,
            backgroundColor: Color.clear,
            hoveredBackgroundColor: Color.clear,
            activeBackgroundColor: BeamColor.Mercury.swiftUI,
            leadingPaddingAdjustment: hasIcon ? 4 : 0
        )
    }

}

private struct HelpButtonView: View {

    @EnvironmentObject var state: BeamState
    @State private var buttonFrameInGlobalCoordinates: CGRect?

    var body: some View {
        ButtonLabel("Help", customStyle: WindowBottomToolBar.buttonStyle(withIcon: false)) {
            showHelpAndFeedbackMenuView()
        }
        .accessibility(identifier: "HelpButton")
        .background(geometryReaderView)
        .onPreferenceChange(FramePreferenceKey.self) { frame in
            buttonFrameInGlobalCoordinates = frame
        }
    }

    private var geometryReaderView: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            Color.clear.preference(key: FramePreferenceKey.self, value: frame)
        }
    }

    private func showHelpAndFeedbackMenuView() {
        let window = CustomPopoverPresenter.shared.presentPopoverChildWindow(useBeamShadow: true)

        guard let buttonFrame = buttonFrameInGlobalCoordinates?.swiftUISafeTopLeftGlobalFrame(in: window) else { return }

        let view = HelpAndFeedbackMenuView(window: window)
            .environmentObject(state)

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

    private struct FramePreferenceKey: PreferenceKey {
        static var defaultValue: CGRect?
        static func reduce(value: inout Value, nextValue: () -> Value) {
            value = value ?? nextValue()
        }
    }

}

private struct BottomToolBarLeadingIconView: View {

    @ObservedObject var versionChecker: VersionChecker

    var body: some View {
        if shouldShowUpdateStatus {
            SmallUpdateIndicatorView(versionChecker: versionChecker)
        } else {
            HelpButtonView()
        }
    }

    private var shouldShowUpdateStatus: Bool {
        switch versionChecker.state {
        case .noUpdate, .checking: return false
        default: return true
        }
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
        ButtonLabel("New Note", icon: "tool-new", customStyle: WindowBottomToolBar.buttonStyle(withIcon: true)) {
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
