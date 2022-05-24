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
    @EnvironmentObject var data: BeamData

    var topPadding: CGFloat = Self.topPadding
    private let errorColor = BeamColor.Shiraz
    private var textColor: BeamColor {
        model.isTitleTaken ? errorColor : BeamColor.Generic.text
    }

    @State private var publishShowError: NoteHeaderPublishButton.ErrorMessage?
    @State private var hoveringLinkButton = false

    private var titleView: some View {
        ZStack(alignment: .leading) {
            // TODO: Support multiline editing
            // https://linear.app/beamapp/issue/BE-799/renaming-cards-multiline-support
            if model.canEditTitle {
                BeamTextField(text: $model.titleText,
                              isEditing: $model.isEditingTitle,
                              placeholder: "Note's title",
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
        .accessibility(identifier: "Note's title")
    }

    private var subtitleInfoView: some View {
        Group {
            if model.isTitleTaken {
                Text("This note’s title ")
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
                        LottieView(name: lottieName, playing: true,
                                   color: BeamColor.Niobium.nsColor, loopMode: .playOnce)
                        .frame(width: 16, height: 16)
                        .allowsHitTesting(false)
                )
                .onHover { isHovering = $0 && !disable }
                .disabled(disable)
        }
    }

    @State private var forceDropDownMenu: Bool = false
    @State private var forceHovering: Bool = false
    private var actionsView: some View {
        var style = model.publishState == .isPublic ? ButtonLabelStyle.leftFilledStyle : ButtonLabelStyle(disableAnimations: false)
        if model.publishState == .isPublic {
            style.horizontalPadding = 7
        }

        return HStack(spacing: BeamSpacing._120) {
            ZStack {
                if model.publishState == .isPublic {
                    HStack(spacing: BeamSpacing._10) {
                        notePublishButton(style: style, forceHovering: forceHovering)
                        DropDownButton(parentWindow: AppDelegate.main.window, items: publishedContextItems, customStyle: .rightFilledStyle, menuForcedWidth: 180, forceMenuToAppear: forceDropDownMenu)
                    }
                    .offset(x: -7, y: 0)
                    .onAppear {
                        if forceDropDownMenu {
                            forceDropDownMenu = false
                        }
                    }
                    .onHover {
                        forceHovering = $0
                    }
                } else {
                    notePublishButton(style: ButtonLabelStyle(disableAnimations: false))
                }
            }
            .transition(.asymmetric(insertion: .opacity, removal: .slide))
            .animation(BeamAnimation.easeInOut(duration: 0.15))
            //            Feature not available yet.
            //            ButtonLabel(icon: "editor-sources", state: .disabled)
            Separator(horizontal: false, hairline: false, rounded: true, color: BeamColor.Generic.separator)
                .frame(height: 16)
            AnimatedActionButton(iconName: "editor-delete", lottieName: "editor-delete", disable: model.note?.isTodaysNote ?? false, action: model.promptConfirmDelete)
                .offset(x: 0, y: -1) // alignment adjustment for the eye
        }
    }

    private func notePublishButton(style: ButtonLabelStyle, forceHovering: Bool = false) -> some View {
        return NoteHeaderPublishButton(publishState: model.publishState,
                                justCopiedLink: model.justCopiedLinkFrom == .fromPublishButton,
                                       error: publishShowError, forceHovering: forceHovering, customButtonLabelStyle: style,
                                action: {
            if model.publishState == .isPrivate {
                let canPerform = model.togglePublish { result in
                    switch result {
                    case .success:
                        self.forceDropDownMenu = true
                    case .failure(let error):
                        handlePublicationError(error: error)
                    }
                }
                if !canPerform {
                    showConnectWindow()
                }
            }
            if model.publishState == .isPublic {
                model.copyLink(source: .fromPublishButton)
            }
        })
    }

    private func handlePublicationError(error: Error) {
        if let error = error as? RestAPIServer.Error {
            switch error {
            case .noUsername:
                showPublicationError(error: .noUsername)
            case .notFound:
                break
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

    private func showConnectWindow() {
        publishShowError = nil
        data.onboardingManager.showOnboardingForConnectOnly(withConfirmationAlert: true)
    }

    private func showPublicationError(error: NoteHeaderPublishButton.ErrorMessage) {
        publishShowError = error
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .seconds(2))) {
            publishShowError = nil
        }
    }

    private var publishedContextItems: [ContextMenuItem] {
        [
            ContextMenuItem(title: "Add to profile",
                            subtitleButton: model.getProfileLink()?.urlStringWithoutScheme, showSubtitleButton: model.isOnUserProfile,
                            type: .itemWithToggle, action: nil, isToggleOn: model.isOnUserProfile, toggleAction: { _ in
                model.togglePublishOnProfile() { _ in }
            }),
            ContextMenuItem(title: "Share", icon: "editor-arrow_right", iconPlacement: ContextMenuItem.IconPlacement.trailing, iconSize: 16, iconColor: BeamColor.AlphaGray, type: .itemWithDisclosure, action: { }, subMenuModel: SocialShareContextMenu(urlToShare: model.getLink(), of: model.note?.title).socialShareMenuViewModel),
            ContextMenuItem.separator(),
            ContextMenuItem(title: "Unpublish", action: {
                CustomPopoverPresenter.shared.dismissPopovers(animated: false)
                _ = model.togglePublish { _ in }
            })
        ]
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: BeamSpacing._40) {
                dateView
                    .opacity(model.note?.type.isJournal == true ? 0 : 1)
                    .offset(x: 1, y: 0) // compensate for different font size leading alignment
                HStack {
                    titleView
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
