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

    @State var contextMenuModel: ContextMenuViewModel? = ContextMenuViewModel()
    @State var contextMenuSize = CGSize.zero

    var body: some View {
        ZStack(alignment: .center) {
            ButtonLabel(icon: playerManager.isAnyMediaUnmuted ? "tabs-media" : "tabs-media_muted") {
                onMuteNote?(nil)
                updateContextMenuItems()
            }.onHover { hovering in
                hoverButtonDelayedBlock?.cancel()

                let block = DispatchWorkItem(block: {
                    self.isHoveringButton = hovering
                    self.updateContextMenuItems()
                })
                hoverButtonDelayedBlock = block
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(hovering ? 500 : 1000)), execute: block)
            }
            if let contextMenuModel = contextMenuModel {
                ContextMenuView(viewModel: contextMenuModel)
                    .frame(width: 180, height: contextMenuSize.height)
                    .onHover { hovering in
                        isHoveringMenu = hovering
                        hoverMenuDelayedBlock?.cancel()
                        let block = DispatchWorkItem(block: {
                            self.isHoveringMenu = hovering
                            self.updateContextMenuItems()
                        })
                        hoverMenuDelayedBlock = block
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(1000)), execute: block)
                    }
                    .offset(x: (-180 / 2) + 10, y: -contextMenuSize.height + 6)
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
        contextMenuModel?.items = []
        contextMenuModel = nil
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
        contextMenuSize = ContextMenuView.idealSizeForItems(items)
        contextMenuModel?.items = items
        contextMenuModel?.animationDirection = .top
        contextMenuModel?.visible = isHoveringButton || isHoveringMenu
    }

}

struct NoteMediaPlayingButton_Previews: PreviewProvider {
    static var previews: some View {
        NoteMediaPlayingButton(playerManager: NoteMediaPlayerManager())
    }
}
