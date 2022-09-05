//
//  SocialShareContextMenu.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 09/05/2022.
//

import Foundation

class SocialShareContextMenuViewModel: ContextMenuViewModel {
    var urlToShare: URL?
}

struct SocialShareContextMenu {
    var socialShareMenuViewModel: SocialShareContextMenuViewModel
    init(urlToShare: URL?, of noteTitle: String?, data: BeamData) {
        var items = [
            ContextMenuItem(title: "Copy URL", icon: "editor-url_link", action: {
                SocialShareContextMenu.share(url: urlToShare, of: noteTitle, to: .copy, data: data)
            }),
            ContextMenuItem.separator()
        ]
        items.append(contentsOf: ShareService.allCases(except: [.copy]).map { service -> ContextMenuItem in
            ContextMenuItem(title: service.title, icon: service.icon, action: {
                SocialShareContextMenu.share(url: urlToShare, of: noteTitle, to: service, data: data)
            })
        })

        socialShareMenuViewModel = SocialShareContextMenuViewModel()
        socialShareMenuViewModel.items = items
        socialShareMenuViewModel.sizeToFit = false
        socialShareMenuViewModel.containerSize = CGSize(width: 120, height: 208)
        socialShareMenuViewModel.forcedWidth = 120
        socialShareMenuViewModel.urlToShare = urlToShare
    }

    private static func share(url: URL?, of noteTitle: String?, to service: ShareService, data: BeamData) {
        guard let url = url else { return }
        Task { @MainActor in
            let helper = ShareHelper(data: data) { url in
                AppDelegate.main.openMinimalistWebWindow(url: url, title: service.title, rect: ShareWindowFeatures(for: service).toRect())
            }
            await helper.share(link: url, of: noteTitle, to: service)
        }
    }
}
