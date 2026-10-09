//
//  NoteHeaderView.swift
//  Beam
//
//  Created by Remi Santos on 10/05/2021.
//

import BeamCore
import Combine
import SwiftUI
import Lottie


struct NoteHeaderView: View {

    private static let leadingPadding: CGFloat = 18
    static let topPadding: CGFloat = PreferencesManager.editorHeaderTopPadding
    @StateObject var model: NoteHeaderView.ViewModel = NoteHeaderView.ViewModel()
    @ObservedObject var pinnedManager: PinnedNotesManager
    @EnvironmentObject var windowInfo: BeamWindowInfo
    @Environment(\.undoManager) var undoManager

    var topPadding: CGFloat = Self.topPadding
    private let errorColor = BeamColor.Shiraz
    private var textColor: BeamColor {
        model.isTitleTaken.value ? errorColor : BeamColor.Generic.text
    }


    private var titleView: some View {
        ZStack(alignment: .leading) {
            // TODO: Support multiline editing
            // https://linear.app/beamapp/issue/BE-799/renaming-cards-multiline-support
            if model.canEditTitle {
                BeamTextField(text: $model.titleText,
                              isEditing: $model.isEditingTitle,
                              placeholder: "Note's title",
                              font: BeamFont.semibold(size: PreferencesManager.editorCardTitleFontSize).nsFont,
                              textColor: textColor.nsColor,
                              placeholderColor: BeamColor.Generic.placeholder.nsColor,
                              selectedRange: model.titleSelectedRange,
                              multiline: true,
                              onTextChanged: model.textFieldDidChange,
                              onCommit: { _ in
                                model.commitRenameCard(fromTextField: true)
                              }, onEscape: {
                                model.commitRenameCard(fromTextField: true)
                              }, onStopEditing: {
                                model.commitRenameCard(fromTextField: true)
                              })
                    .allowsHitTesting(model.isEditingTitle)
                    .frame(height: 40)
            } else {
                Text(model.titleText)
                    .lineLimit(2)
                    .font(BeamFont.semibold(size: PreferencesManager.editorCardTitleFontSize).swiftUI)
                    .foregroundColor(textColor.swiftUI)
            }
        }
        .contentShape(Rectangle())
        .gesture(TapGesture().onEnded(model.onTap))
        .simultaneousGesture(TapGesture(count: 2).onEnded(model.onDoubleTap))
        .transaction { $0.animation = nil }
        .wiggleEffect(animatableValue: model.wiggleValue)
        .animation(model.wiggleValue > 0 ? BeamAnimation.easeInOut(duration: 0.3) : nil, value: model.wiggleValue)
        .onDisappear {
            model.commitRenameCard(fromTextField: false)
        }
        .accessibility(identifier: "Note's title")
    }

    private var subtitleInfoView: some View {
        Group {
            if model.isTitleTaken.value {
                Text("This note’s title ")
                + Text("already exists")
                    .foregroundColor(errorColor.swiftUI)
                + Text(" in your knowledge base")
            }
        }
        .font(BeamFont.medium(size: 10).swiftUI)
        .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
        .transition(AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: model.isTitleTaken.animated ? 0.15 : .zero)))
    }

    private var dateView: some View {
        Text("\(BeamDate.journalNoteTitle(for: model.note?.creationDate ?? BeamDate.now))")
            .font(BeamFont.medium(size: 12).swiftUI)
            .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
    }

    private struct AnimatedActionButton: View {
        let iconName: String
        let lottieName: String
        let disable: Bool
        let action: () -> Void
        @State private var isHovering = false

        var body: some View {
            ButtonLabel(icon: isHovering ? "transparent" : iconName, state: disable ? .disabled : .normal, action: action)
                .overlay(
                    !isHovering ? nil :
                        LottieView(animation: .named(lottieName))
                            .setColor(BeamColor.Niobium.nsColor)
                            .playing(loopMode: .playOnce)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .allowsHitTesting(false)
                )
                .onHover { isHovering = $0 && !disable }
                .disabled(disable)
        }
    }

    private var actionsView: some View {
        HStack(spacing: BeamSpacing._120) {
            AnimatedActionButton(iconName: "editor-delete", lottieName: "editor-delete", disable: model.note?.isTodaysNote ?? false) {
                model.deleteNote(undoManager: undoManager)
            }
            .offset(x: 0, y: -1)
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: BeamSpacing._40) {
                HStack(spacing: 6) {
                    ButtonLabel(icon: model.isPinned ? "sidebar-pin_fill" : "sidebar-pin", customStyle: buttonLabelStyle) {
                        model.togglePin()
                    }
                    .accessibilityLabel("pin-unpin-button")
                    .frame(width: 16, height: 16)
                    .tooltipOnHover(model.isPinned ? "Unpin" : "Pin", alignment: .leading)
                    dateView
                        .opacity(model.note?.type.isJournal == true ? 0 : 1)
                }
                HStack {
                    titleView
                    Spacer()
                    actionsView
                }
                subtitleInfoView
                if let note = model.note, !model.tabGroupObjects.isEmpty {
                    EditorTabGroupsContainerView(tabGroups: model.tabGroupObjects, note: note)
                        .padding(.top, 45)
                        .padding(.bottom, 45)
                }
            }
        }
        .padding(.top, self.topPadding)
        .padding(.leading, Self.leadingPadding)
        .id(model.note)
    }

    private var buttonLabelStyle: ButtonLabelStyle {
        ButtonLabelStyle(iconSize: 12, foregroundColor: BeamColor.AlphaGray.swiftUI, activeBackgroundColor: .clear)
    }
}

struct NoteHeaderView_Previews: PreviewProvider {
    static var classicModel: NoteHeaderView.ViewModel {
        NoteHeaderView.ViewModel(note: try! BeamNote(title: "My note title"))
    }
    static var titleTakenModel: NoteHeaderView.ViewModel {
        let model = NoteHeaderView.ViewModel(note: try! BeamNote(title: "Taken Title"))
        model.isTitleTaken = (true, true)
        return model
    }
    static var previews: some View {
        VStack {
            NoteHeaderView(model: classicModel, pinnedManager: PinnedNotesManager(), topPadding: 20)
            NoteHeaderView(model: titleTakenModel, pinnedManager: PinnedNotesManager(), topPadding: 60)
        }
        .border(Color.green)
        .padding(.vertical)
        .padding(.horizontal, 100)
        .border(Color.red)
        .background(BeamColor.Generic.background.swiftUI)
    }
}
