//
//  NoteMediaPlayingButton.swift
//  Beam
//
//  Created by Remi Santos on 30/06/2021.
//

import SwiftUI

struct NoteMediaPlayingButton: View {
    @ObservedObject var playerManager: NoteMediaPlayerManager
    var onOpenNote: ((NoteMediaPlaying) -> Void)?
    var onMuteNote: ((NoteMediaPlaying?) -> Void)?

    @State private var isHoveringButton = false
    @State private var isHoveringMenu = false
    @State private var hoverButtonDelayedBlock: DispatchWorkItem?
    @State private var hoverMenuDelayedBlock: DispatchWorkItem?

    @StateObject var contextMenuModel: ContextMenuViewModel = ContextMenuViewModel()
    @State var contextMenuSize = CGSize.zero

    var body: some View {
        ZStack(alignment: .center) {
            let isAnyMediaUnmuted = playerManager.isAnyMediaUnmuted
            ButtonLabel(icon: isAnyMediaUnmuted ? "tabs-media" : "tabs-media_muted") {
                onMuteNote?(nil)
                updateContextMenuItems()
            }.onHover { hovering in
                hoverButtonDelayedBlock?.cancel()
                let block = DispatchWorkItem(block: {
                    self.isHoveringButton = hovering
                    if !isHoveringMenu {
                        self.updateContextMenuItems()
                    }
                })
                hoverButtonDelayedBlock = block
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(hovering ? 500 : 1000)), execute: block)
            }
            .accessibilityIdentifier("note-media-\(isAnyMediaUnmuted ? "playing" : "muted")")
            if let contextMenuModel = contextMenuModel, contextMenuModel.visible {
                ContextMenuView(viewModel: contextMenuModel)
                    .frame(width: contextMenuSize.width, height: contextMenuSize.height)
                    .onHover { hovering in
                        isHoveringMenu = hovering

                        guard !hovering else { return }
                        hoverMenuDelayedBlock?.cancel()
                        let block = DispatchWorkItem(block: {
                            self.isHoveringMenu = hovering
                            contextMenuModel.visible = hovering
                        })
                        hoverMenuDelayedBlock = block
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(1000)), execute: block)
                    }
                    .offset(x: (-contextMenuSize.width / 2) + 18, y: -contextMenuSize.height + 6)
            }
        }
        .frame(width: 20, height: 20)
        .onAppear {
            updateContextMenuItems()
        }
        .onDisappear {
            clearContextMenuModel()
        }
    }

    private func clearContextMenuModel() {
        contextMenuModel.items = []
    }

    func updateContextMenuItems() {
        var alreadyAddedNotes = [UUID: ContextMenuItem]()
        let items = playerManager.playings.compactMap { i -> ContextMenuItem? in
            guard alreadyAddedNotes[i.note.id] == nil else { return nil }
            let icon = i.muted ? "tabs-media_muted" : "tabs-media"
            let item = ContextMenuItem(title: i.note.title, icon: icon, iconPlacement: .trailing, action: {
                onOpenNote?(i)
            }, iconAction: {
                onMuteNote?(i)
                updateContextMenuItems()
            })
            alreadyAddedNotes[i.note.id] = item
            return item
        }
        contextMenuSize = CGSize(width: 240, height: ContextMenuView.idealSizeForItems(items).height)
        contextMenuModel.items = items
        contextMenuModel.animationDirection = .top
        contextMenuModel.containerSize = contextMenuSize
        contextMenuModel.visible = isHoveringButton || isHoveringMenu
    }

}

struct NoteMediaPlayingButton_Previews: PreviewProvider {
    static var previews: some View {
        NoteMediaPlayingButton(playerManager: NoteMediaPlayerManager())
    }
}
