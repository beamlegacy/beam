//
//  NoteHeaderPublishButton.swift
//  Beam
//
//  Created by Remi Santos on 21/09/2021.
//

import SwiftUI
import Lottie

struct NoteHeaderPublishButton: View {

    enum ErrorMessage {
        case loggedOut
        case noUsername
        case custom(String)

        var message: String {
            switch self {
            case .loggedOut:
                return "You need to be logged in"
            case .noUsername:
                return "You need to have a username"
            case .custom(let message):
                return message
            }
        }
    }

    enum PublishButtonState {
        case isPublic
        case isPrivate
        case publishing
        case unpublishing
        case justPublished
        case justUnpublished
    }

    var publishState: PublishButtonState
    var justCopiedLink = false
    var error: ErrorMessage?
//    var enableAnimations: Bool = true
    var forceHovering: Bool = false
    var customButtonLabelStyle: ButtonLabelStyle
    var action: () -> Void

    @State private var hovering = false
    @State private var title: String?
    @State private var lottiePlaybackMode: LottiePlaybackMode = .paused

    var isWaitingChanges: Bool {
        [.publishing, .unpublishing].contains(publishState)
    }
    var body: some View {
        let justPublishedOrCopied = justCopiedLink || publishState == .justPublished
        let displayTitle = justPublishedOrCopied || hovering || isWaitingChanges || forceHovering

        var publishTitle: String?
        var displayCheckIcon = false
        let isPublic = publishState == .isPublic || publishState == .unpublishing

        let playbackMode: LottiePlaybackMode = (forceHovering && !isWaitingChanges) ? .playing(.fromProgress(0, toProgress: 1, loopMode: .loop)) : lottiePlaybackMode

        if displayTitle {
            if publishState == .justPublished || justCopiedLink {
                publishTitle = "Published"
                displayCheckIcon = true
            } else if publishState == .publishing {
                publishTitle = "Publishing…"
            } else if publishState == .unpublishing {
                publishTitle = "Unpublishing…"
            } else {
                publishTitle = isPublic ? "Published" : "Publish"
            }
        }
        let springAnimation = BeamAnimation.spring(stiffness: 480, damping: 30)
        let containerAnimation = BeamAnimation.easeInOut(duration: 0.15)

        @ViewBuilder var errorOverlay: some View {
            if let error = error {
                Tooltip(title: LocalizedStringKey(error.message), icon: "status-lock")
                .fixedSize().offset(x: 0, y: -28)
                .transition(AnyTransition.opacity.animation(BeamAnimation.defaultiOSEasing(duration: 0.3)))
            }
        }

        return HStack(spacing: BeamSpacing._100) {
            ButtonLabel(customView: { _, _ in
                AnyView(
                    HStack(spacing: BeamSpacing._20) {
                        ZStack {
                            LottieView(animation: .named("editor-publish"))
                                .playbackMode(playbackMode)
                                .setColor(displayTitle ? BeamColor.Niobium.nsColor : BeamColor.LightStoneGray.nsColor)
                                .opacity(isPublic ? 0 : 1)

                            Icon(name: "editor-url_link", color: displayTitle ? BeamColor.Niobium.swiftUI : BeamColor.LightStoneGray.swiftUI)
                                .blendModeLightMultiplyDarkScreen()
                                .opacity(isPublic ? 1 : 0)
                        }
                        .frame(width: 16, height: 16)
                        if let title = publishTitle {
                            Text(title)
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                                .font(BeamFont.regular(size: 12).swiftUI)
                                .foregroundColor(BeamColor.Niobium.swiftUI)
                                .transition(.asymmetric(insertion: AnyTransition.opacity.combined(with: .move(edge: .trailing)),
                                                        removal: AnyTransition.opacity.combined(with: .move(edge: .trailing)).animation(BeamAnimation.easeInOut(duration: 0.05))
                                ))
                        }
                    }
                    .animation(springAnimation, value: displayCheckIcon)
                    .animation(springAnimation, value: isPublic)
                    .animation(springAnimation, value: publishTitle)
                    .animation(nil)
                )
            }, state: displayTitle ? (publishState != .isPublic ? .clicked : .hovered) : .normal,
                        customStyle: customButtonLabelStyle,
                        action: action)
            .animation(containerAnimation, value: displayCheckIcon)
            .animation(containerAnimation, value: isPublic)
            .animation(containerAnimation, value: publishTitle)
            .onHover { h in
                hovering = h
                lottiePlaybackMode = h && !isWaitingChanges ? .playing(.fromProgress(0, toProgress: 1, loopMode: .loop)) : .paused
            }
            .accessibilityElement(children: .ignore)
            .accessibility(addTraits: .isButton)
            .accessibility(value: Text(title ?? "Publish"))
            .accessibility(identifier: "NoteHeaderPublishButton")
            .overlay(!justCopiedLink ? nil :
                        Tooltip(title: "Link Copied")
                        .fixedSize().offset(x: 0, y: -28)
                        .transition(AnyTransition.opacity.animation(BeamAnimation.defaultiOSEasing(duration: 0.3))), alignment: .top)
            .overlay(errorOverlay, alignment: .top)
        }
    }
}
