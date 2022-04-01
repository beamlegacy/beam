//
//  NoteMediaPlayerManager.swift
//  Beam
//
//  Created by Remi Santos on 30/06/2021.
//

import Foundation
import BeamCore

struct NoteMediaPlaying {
    var note: BeamNote
    var elementId: UUID
    var webview: BeamWebView?
    var page: WebPage?
    var originalURL: URL?
    var muted: Bool = false
}

class NoteMediaPlayerManager: ObservableObject {

    @Published private(set) var playings = [NoteMediaPlaying]()

    var isAnyMediaUnmuted: Bool {
        playings.firstIndex { !$0.muted } != nil
    }

    func playingWebViewForNote(note: BeamNote, elementId: UUID, url: URL) -> BeamWebView? {
        let item = playings.first { i in
            i.note.id == note.id && i.elementId == elementId && i.originalURL == url
        }
        return item?.webview
    }

    func addNotePlaying(note: BeamNote, elementId: UUID, webView: BeamWebView? = nil, url: URL) {
        playings.append(
            NoteMediaPlaying(note: note, elementId: elementId, webview: webView, page: webView?.page, originalURL: url)
        )
    }

    func stopNotePlaying(note: BeamNote, elementId: UUID, url: URL) {
        playings.removeAll { i in
            if i.note.id == note.id && i.elementId == elementId && i.originalURL == url {
                return true
            }
            return false
        }
    }

    func toggleMuteNotePlaying(note: BeamNote) {
        playings = playings.map { i in
            if i.note.id == note.id, let page = i.page {
                page.mediaPlayerController?.toggleMute()
                var updated = i
                updated.muted = !i.muted
                return updated
            }
            return i
        }
    }

    func toggleMuteAll() {
        let shouldMute = isAnyMediaUnmuted ? true : false
        playings = playings.map { i in
            if let page = i.page {
                page.mediaPlayerController?.setMuted(shouldMute)
            }
            var updated = i
            updated.muted = shouldMute
            return updated
        }
    }
}
