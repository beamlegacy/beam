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

    init(urlToShare: URL?, of noteTitle: String?) {
        let items =  [
            ContextMenuItem(title: "Twitter", icon: "social-twitter_fill", action: {
                SocialShareContextMenu.share(url: urlToShare, of: noteTitle, to: .twitter)
            }),
            ContextMenuItem(title: "Facebook", icon: "social-facebook_fill", action: {
                SocialShareContextMenu.share(url: urlToShare, of: noteTitle, to: .facebook)
            }),
            ContextMenuItem(title: "LinkedIn", icon: "social-linkedin_fill", action: {
                SocialShareContextMenu.share(url: urlToShare, of: noteTitle, to: .linkedin)
            }),
            ContextMenuItem(title: "Reddit", icon: "social-reddit_fill", action: {
                SocialShareContextMenu.share(url: urlToShare, of: noteTitle, to: .reddit)
            }),
            ContextMenuItem(title: "Messages", icon: "social-message_fill", action: {
                SocialShareContextMenu.share(url: urlToShare, of: noteTitle, to: .messages)
            }),
            ContextMenuItem(title: "Mail", icon: "social-mail_fill", action: {
                SocialShareContextMenu.share(url: urlToShare, of: noteTitle, to: .email)
            }),
            ContextMenuItem(title: "Copy URL", icon: "editor-url_link", action: {
                SocialShareContextMenu.share(url: urlToShare, of: noteTitle, to: .copy)
            })
        ]

        socialShareMenuViewModel = SocialShareContextMenuViewModel()
        socialShareMenuViewModel.items = items
        socialShareMenuViewModel.sizeToFit = false
        socialShareMenuViewModel.containerSize = CGSize(width: 120, height: 208)
        socialShareMenuViewModel.forcedWidth = 120
        socialShareMenuViewModel.urlToShare = urlToShare
    }

    private static func share(url: URL?, of noteTitle: String?, to service: ShareService) {
        guard let url = url else { return }
        Task { @MainActor in
            let helper = ShareHelper { url in
                AppDelegate.main.openMinimalistWebWindow(url: url, title: nil, rect: ShareWindowFeatures(for: service).toRect())
            }
            await helper.share(link: url, of: noteTitle, to: service)
        }
    }
}
