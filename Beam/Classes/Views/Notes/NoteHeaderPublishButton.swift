//
//  NoteHeaderPublishButton.swift
//  Beam
//
//  Created by Remi Santos on 21/09/2021.
//

import SwiftUI

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
    var action: () -> Void

    @State private var hovering = false
    @State private var title: String?

    private let customButtonLabelStyle = ButtonLabelStyle(disableAnimations: false)
    var isWaitingChanges: Bool {
        [.publishing, .unpublishing].contains(publishState)
    }
    var body: some View {
        let justPublishedOrCopied = justCopiedLink || publishState == .justPublished
        let displayTitle = justPublishedOrCopied || hovering || isWaitingChanges
        var publishTitle: String?
        var displayCheckIcon = false
        let isPublic = publishState == .isPublic || publishState == .unpublishing
        let animateLottie = hovering && !isWaitingChanges
        if displayTitle {
            if publishState == .justPublished || justCopiedLink {
                publishTitle = "Published"
                displayCheckIcon = true
            } else if publishState == .publishing {
                publishTitle = "Publishing…"
            } else if publishState == .unpublishing {
                publishTitle = "Unpublishing…"
            } else {
                publishTitle = isPublic ? "Unpublish" : "Publish"
            }
        }
        let springAnimation = BeamAnimation.spring(stiffness: 480, damping: 30)
        let containerAnimation = BeamAnimation.easeInOut(duration: 0.15)

        @ViewBuilder var errorOverlay: some View {
            if let error = error {
                Tooltip(title: error.message, icon: "status-lock")
                .fixedSize().offset(x: 0, y: -25)
                .transition(AnyTransition.opacity.animation(BeamAnimation.defaultiOSEasing(duration: 0.3)))
            }
        }

        return HStack(spacing: BeamSpacing._100) {
            ButtonLabel(customView: { _, _ in
                AnyView(
                    HStack(spacing: BeamSpacing._20) {
                        ZStack {
                            // Using a ZStack with opacity to better animate alongside the spring text
                            Icon(name: "collect-generic", size: 16, color: BeamColor.Niobium.swiftUI)
                                .opacity(displayCheckIcon ? 1 : 0)
                            LottieView(name: "editor-publish", playing: animateLottie,
                                       color: displayTitle ? BeamColor.Niobium.nsColor : BeamColor.LightStoneGray.nsColor,
                                       loopMode: .loop, speed: 2)
                                .opacity(displayCheckIcon || isPublic ? 0 : 1)
                            LottieView(name: "editor-unpublish", playing: animateLottie,
                                       color: displayTitle ? BeamColor.Niobium.nsColor : BeamColor.LightStoneGray.nsColor,
                                       loopMode: .loop, speed: 2)
                                .opacity(displayCheckIcon || !isPublic ? 0 : 1)
                        }
                        .frame(width: 16, height: 16)
                        if let title = publishTitle {
                            Text(title)
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
            }, state: displayTitle ? .clicked : .normal, customStyle: customButtonLabelStyle, action: action)
            .animation(containerAnimation, value: displayCheckIcon)
            .animation(containerAnimation, value: isPublic)
            .animation(containerAnimation, value: publishTitle)
            .onHover { h in
                hovering = h
            }
            .accessibilityElement(children: .ignore)
            .accessibility(addTraits: .isButton)
            .accessibility(value: Text(title ?? "Publish"))
            .accessibility(identifier: "NoteHeaderPublishButton")
            .overlay(!justCopiedLink ? nil :
                        Tooltip(title: "Link Copied")
                        .fixedSize().offset(x: 0, y: -25)
                        .transition(AnyTransition.opacity.animation(BeamAnimation.defaultiOSEasing(duration: 0.3))), alignment: .top)
            .overlay(errorOverlay, alignment: .top)
        }
    }
}
