//
//  SharingStatusView.swift
//  Beam
//
//  Created by Remi Santos on 06/05/2021.
//

import SwiftUI
import BeamCore

struct SharingStatusView: View {

    @ObservedObject var model: SharingStatusViewModel
    private var note: BeamNote {
        model.note
    }

    private var shareButtonText: String {
        if model.isLoading && model.isHovering {
            return "Cancel"
        }
        switch model.loadingState {
        case .publishing:
            return "Publishing..."
        case .unpublishing:
            return "Unpublishing..."
        default:
            return note.isPublic ? "Published" : "Private"
        }
    }

    private var shareButtonIcon: String {
        if model.isLoading && model.isHovering {
            return "status-publish_cancel"
        }
        switch model.loadingState {
        case .publishing:
            return "status-publish"
        case .unpublishing:
            return "status-unpublish"
        default:
            return note.isPublic ? "editor-url_link" : "status-private"
        }
    }

    private var linkCopyStyle: ButtonLabelStyle {
        var style = ButtonLabelStyle.tinyIconStyle
        style.foregroundColor = BeamColor.AlphaGray.swiftUI
        style.hoveredBackgroundColor = nil
        style.activeBackgroundColor = BeamColor.Button.activeBackground.swiftUI
        return style
    }

    private var shouldShowLinkButton: Bool {
        note.isPublic == true && !model.isLoading
    }

    var body: some View {
        let showLinkButton = shouldShowLinkButton
        HStack(spacing: 0) {
            if showLinkButton {
                ButtonLabel(icon: shareButtonIcon, customStyle: linkCopyStyle) {
                    model.copyLink()
                }
            }
            ButtonLabel(shareButtonText,
                        icon: !showLinkButton ? shareButtonIcon : nil,
                        variant: model.isLoading ? .secondary : .dropdown) {
                guard !model.isLoading else {
                    model.cancelChange()
                    return
                }
                guard !model.isCancelling else { return }
                model.showShareMenu()
            }
            .onHover { hovering in
                model.isHovering = model.isLoading && hovering
            }
        }
        .padding(.horizontal, showLinkButton ? 7 : BeamSpacing._40)
        .fixedSize(horizontal: true, vertical: false)
        .overlay(
            VStack {
                if let info = model.toastInformation {
                    // TODO: Replace this with OverlayViewCenter once implemented
                    // by password ui work (here https://gitlab.com/beamgroup/beam/-/merge_requests/547)
                    SharingBannerInfo(text: info, icon: "tooltip-mark")
                        .offset(x: 0, y: -32)
                }
            }
            .animation(.easeInOut(duration: 0.15))
        )
    }
}

class SharingStatusViewModel: ObservableObject {
    enum LoadingState {
        case publishing
        case unpublishing
        case none
    }

    @ObservedObject var note: BeamNote
    private var documentManager: DocumentManager
    private var sharingUtils: BeamNoteSharingUtils

    init(note: BeamNote, documentManager: DocumentManager) {
        self.note = note
        self.documentManager = documentManager
        self.sharingUtils = BeamNoteSharingUtils(note: note)
    }

    @Published var loadingState: LoadingState = .none
    @Published var toastInformation: String?
    @Published var isCancelling: Bool = false
    @Published var isHovering: Bool = false

    var isLoading: Bool {
        loadingState != .none
    }

    func showShareMenu() {
        var items: [ContextMenuItem] = []
        if note.isPublic {
            items.append(contentsOf: [
                ContextMenuItem(title: "Copy Link", action: copyLink),
                ContextMenuItem(title: "Invite...", action: nil),
                ContextMenuItem.separator()
            ])
        }
        items.append(ContextMenuItem(title: note.isPublic ? "Unpublish" : "Publish", action: togglePublish))
        let menuView = ContextMenuFormatterView(items: items, direction: .top) {
            ContextMenuPresenter.shared.dismissMenu()
        }
        // Temporarily fixed position, will be replaced by a "toast" implementation
        let atPoint = CGPoint(x: 5, y: menuView.idealSize.height + 27)
        ContextMenuPresenter.shared.presentMenu(menuView, atPoint: atPoint)
    }

    func cancelChange() {
        guard loadingState != .none else { return }
        let makePublic = loadingState == .unpublishing
        isCancelling = true
        sharingUtils.makeNotePublic(makePublic, documentManager: documentManager) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isCancelling = false
            }
        }
        loadingState = .none
    }

    func copyLink() {
        sharingUtils.copyLinkToClipboard(completion: { [weak self] _ in
            guard let self = self else { return }
            self.toastInformation = "Link copied"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.toastInformation = nil
            }
        })
    }

    func togglePublish() {
        let isPublic = note.isPublic
        withAnimation {
            if isPublic {
                loadingState = .unpublishing
            } else {
                loadingState = .publishing
            }
        }
        // Add a little time to emphasize in the UI that we're publishing...
        let minimumLoadingTime: Double = 1.5
        let startTime = Date()
        sharingUtils.makeNotePublic(!isPublic, documentManager: documentManager) { [weak self] _ in
            guard let self = self, !self.isCancelling else { return }
            let delay = max(0, minimumLoadingTime - Date().timeIntervalSince(startTime))
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation {
                    self.loadingState = .none
                }
                if self.note.isPublic {
                    self.copyLink()
                }
            }
        }
    }
}
