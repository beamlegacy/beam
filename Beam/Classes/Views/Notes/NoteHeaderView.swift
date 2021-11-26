//
//  NoteHeaderView.swift
//  Beam
//
//  Created by Remi Santos on 10/05/2021.
//

import SwiftUI
import BeamCore
import Combine

struct NoteHeaderView: View {

    private static let leadingPadding: CGFloat = 18
    static let topPadding: CGFloat = PreferencesManager.editorHeaderTopPadding
    @ObservedObject var model: NoteHeaderView.ViewModel

    var topPadding: CGFloat = Self.topPadding
    private let errorColor = BeamColor.Shiraz
    private var textColor: BeamColor {
        model.isTitleTaken ? errorColor : BeamColor.Generic.text
    }

    @State private var publishShowError: NoteHeaderPublishButton.ErrorMessage?
    @State private var hoveringLinkButton = false

    private var copyLinkView: some View {
        let justCopiedLink = model.justCopiedLinkFrom == .fromLinkIcon
        let transition = AnyTransition.asymmetric(insertion: AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.2)),
                                                  removal: AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.05)))
        return ButtonLabel(icon: "editor-url_link", customStyle: .tinyIconStyle) {
            model.copyLink(source: .fromLinkIcon)
        }
        .overlay(
            ZStack {
                if justCopiedLink {
                    Tooltip(title: "Link Copied")
                        .fixedSize().offset(x: -22, y: 0)
                        .transition(transition)
                } else if hoveringLinkButton {
                    Tooltip(title: "Copy Link")
                        .fixedSize().offset(x: -22, y: 0)
                        .transition(transition)
                }
            }, alignment: .trailing)
        .onHover { hoveringLinkButton = $0 }
        .transition(AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.15)))
        .offset(x: -30, y: 0)
    }

    private var titleView: some View {
        ZStack(alignment: .leading) {
            // TODO: Support multiline editing
            // https://linear.app/beamapp/issue/BE-799/renaming-cards-multiline-support
            if model.canEditTitle {
                BeamTextField(text: $model.titleText,
                              isEditing: $model.isEditingTitle,
                              placeholder: "Card's title",
                              font: BeamFont.medium(size: PreferencesManager.editorCardTitleFontSize).nsFont,
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
            } else {
                Text(model.titleText)
                    .lineLimit(2)
                    .font(BeamFont.medium(size: PreferencesManager.editorCardTitleFontSize).swiftUI)
                    .foregroundColor(textColor.swiftUI)
            }
        }
        .contentShape(Rectangle())
        .gesture(TapGesture().onEnded(model.onTap))
        .simultaneousGesture(TapGesture(count: 2).onEnded(model.onDoubleTap))
        .animation(nil)
        .wiggleEffect(animatableValue: model.wiggleValue)
        .animation(model.wiggleValue > 0 ? BeamAnimation.easeInOut(duration: 0.3) : nil)
        // force reloading the view on note change to clean up text states
        // and enables appear/disappear events between notes
        .id(model.note)
        .onDisappear {
            model.commitRenameCard(fromTextField: false)
        }
        .accessibility(identifier: "Card's title")
    }

    private var subtitleInfoView: some View {
        Group {
            if model.isTitleTaken {
                Text("This card’s title ")
                + Text("already exists")
                    .foregroundColor(errorColor.swiftUI)
                + Text(" in your knowledge base")
            }
        }
        .font(BeamFont.medium(size: 10).swiftUI)
        .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
        .transition(AnyTransition.opacity.animation(BeamAnimation.easeInOut(duration: 0.15)))
    }

    private var dateView: some View {
        Text("\(BeamDate.journalNoteTitle(for: model.note?.creationDate ?? BeamDate.now))")
            .font(BeamFont.medium(size: 12).swiftUI)
            .foregroundColor(BeamColor.Generic.placeholder.swiftUI)
    }

    private var actionsView: some View {
        HStack(spacing: BeamSpacing._100) {
            NoteHeaderPublishButton(publishState: model.publishState,
                                    justCopiedLink: model.justCopiedLinkFrom == .fromPublishButton,
                                    error: publishShowError,
                                    action: {
                                        let canPerform = model.togglePublish { result in
                                            switch result {
                                            case .success:
                                                break
                                            case .failure(let error):
                                                handlePublicationError(error: error)
                                            }
                                        }
                                        if !canPerform {
                                            showPublicationError(error: .loggedOut)
                                        }
                                    })
//            Feature not available yet.
//            ButtonLabel(icon: "editor-sources", state: .disabled)
            ButtonLabel(icon: "editor-delete", action: model.promptConfirmDelete)
        }
    }

    private func handlePublicationError(error: Error) {
        if let error = error as? RestAPIServer.Error {
            switch error {
            case .noUsername:
                showPublicationError(error: .noUsername)
            case .serverError(error: let error):
                showPublicationError(error: .custom(error ?? "An error occurred…"))
            default:
                showPublicationError(error: .custom(error.localizedDescription))
            }
        } else if let error = error as? BeamNoteSharingUtilsError {
            switch error {
            case .canceled:
                break
            default:
                showPublicationError(error: .custom(error.localizedDescription))
            }
        } else {
            showPublicationError(error: .custom(error.localizedDescription))
        }
    }

    private func showPublicationError(error: NoteHeaderPublishButton.ErrorMessage) {
        publishShowError = error
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .seconds(2))) {
            publishShowError = nil
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: BeamSpacing._40) {
                dateView
                    .opacity(model.note?.type.isJournal == true ? 0 : 1)
                    .offset(x: 1, y: 0) // compensate for different font size leading alignment
                HStack {
                    titleView
                        .overlay(model.publishState != .isPublic ? nil : copyLinkView, alignment: .leading)
                    Spacer()
                    actionsView
                }
                subtitleInfoView
            }
        }
        .padding(.top, self.topPadding)
        .padding(.leading, Self.leadingPadding)
    }
}

struct NoteHeaderView_Previews: PreviewProvider {
    static var classicModel: NoteHeaderView.ViewModel {
        NoteHeaderView.ViewModel(note: BeamNote(title: "My note title"))
    }
    static var titleTakenModel: NoteHeaderView.ViewModel {
        let model = NoteHeaderView.ViewModel(note: BeamNote(title: "Taken Title"))
        model.isTitleTaken = true
        return model
    }
    static var previews: some View {
        VStack {
            NoteHeaderView(model: classicModel, topPadding: 20)
            NoteHeaderView(model: titleTakenModel, topPadding: 60)
        }
        .border(Color.green)
        .padding(.vertical)
        .padding(.horizontal, 100)
        .border(Color.red)
        .background(BeamColor.Generic.background.swiftUI)
    }
}
