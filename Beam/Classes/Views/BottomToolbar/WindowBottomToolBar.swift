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

    static let height: CGFloat = 42

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
        ZStack {
            HStack(alignment: .center) {
                BottomToolBarLeadingIconView(versionChecker: state.data.versionChecker)
                Spacer()
                BottomToolBarTrailingIconView()
                    .environmentObject(state.noteMediaPlayerManager)
            }

            if state.mode == .today {
                journalScrollButton
            }
        }
        .padding(BeamSpacing._100)
        .frame(height: Self.height, alignment: .bottom)
    }

    fileprivate static func buttonStyle(withIcon hasIcon: Bool, withTitle: Bool) -> ButtonLabelStyle {
        ButtonLabelStyle(
            font: BeamFont.medium(size: 12).swiftUI,
            spacing: 1,
            foregroundColor: BeamColor.LightStoneGray.swiftUI,
            activeForegroundColor: BeamColor.Niobium.swiftUI,
            backgroundColor: BeamColor.Generic.background.swiftUI,
            hoveredBackgroundColor: BeamColor.Mercury.swiftUI,
            activeBackgroundColor: BeamColor.AlphaGray.swiftUI.opacity(0.5),
            disableAnimations: false,
            leadingPaddingAdjustment: hasIcon ? 3 : 0,
            trailingPaddingAdjustment: !withTitle && hasIcon ? 3 : 0
        )
    }

    /// Make the animation slightly longer for longer text
    /// base: "Help" = 0.2s . "New Note"  = 0.3s
    fileprivate static func buttonAnimation(forText text: String, appearing: Bool) -> Animation {
        if !appearing {
            return BeamAnimation.easeInOut(duration: 0.1)
        }
        let minLength = 4
        let additionalLength = max(0, text.count - minLength)
        return BeamAnimation.easeInOut(duration: 0.2 + Double(additionalLength / minLength) * 0.1)
    }
}

private struct HelpButtonView: View {

    @EnvironmentObject var state: BeamState
    @Environment(\.showHelpAction) var showHelpAction
    @Environment(\.isCompactWindow) private var isCompactWindow
    @State private var buttonFrameInGlobalCoordinates: CGRect?
    @State private var isHovering: Bool = false
    private let title = loc("Help")

    private var showTitle: Bool {
        isHovering && !isCompactWindow
    }
    var body: some View {
        ButtonLabel(showTitle ? title : nil, icon: "help-question", compactMode: isCompactWindow,
                    customStyle: WindowBottomToolBar.buttonStyle(withIcon: true, withTitle: showTitle)) {
            showHelpAction()
        }
                    .animation(WindowBottomToolBar.buttonAnimation(forText: title, appearing: showTitle), value: isHovering)
                    .accessibilityElement()
                    .accessibility(addTraits: .isButton)
                    .accessibility(identifier: "HelpButton")
                    .onHover { isHovering = $0 }
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
    @Environment(\.isCompactWindow) private var isCompactWindow
    @State private var isHoveringNewNote: Bool = false

    private let title = loc("New Note")
    private var showNewNoteTitle: Bool {
        isHoveringNewNote && !isCompactWindow
    }

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
        ButtonLabel(showNewNoteTitle ? title : nil, icon: "tool-new", compactMode: isCompactWindow,
                    customStyle: WindowBottomToolBar.buttonStyle(withIcon: true, withTitle: showNewNoteTitle)) {
            state.startNewNote()
        }
                    .tooltipOnHover(Shortcut.AvailableShortcut.newNote.keysDescription, alignment: .top)
                    .animation(WindowBottomToolBar.buttonAnimation(forText: title, appearing: showNewNoteTitle), value: isHoveringNewNote)
                    .onHover { isHoveringNewNote = $0 }
                    .accessibilityElement()
                    .accessibility(addTraits: .isButton)
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
        state.currentNote = try? BeamNote(title: "Note A")
        state.currentNote = try? BeamNote(title: "Long Note B")
        state.currentNote = try? BeamNote(title: "Note C ")
        state.currentNote = try? BeamNote(title: "Last Note D")
        state.currentNote = try? BeamNote(title: "Current Note")

        return WindowBottomToolBar()
            .environmentObject(state)
            .frame(width: 800)
            .padding()
            .background(Color.gray)
    }
}
