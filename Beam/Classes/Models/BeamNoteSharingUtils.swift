//
//  BeamNoteSharingUtils.swift
//  Beam
//
//  Created by Remi Santos on 06/05/2021.
//

import Foundation
import BeamCore

enum BeamNoteSharingUtilsError: Error {
    case emptyPublicUrl
    case userNotLoggedIn
    case notPublishedURLAndDate
    case ongoingOperation
}

class BeamNoteSharingUtils {

    static private let publicServer: PublicServer = PublicServer()

    static var canMakePublic: Bool {
        AuthenticationManager.shared.isAuthenticated
    }

    static func getPublicLink(for note: BeamNote) -> URL? {
        if case .published(let link, _) = note.publicationStatus {
            return link
        } else {
            return nil
        }
    }

    static func copyLinkToClipboard(for note: BeamNote, completion: ((Result<URL, Error>) -> Void)? = nil) {
            DispatchQueue.main.async {
                guard let publicLink = getPublicLink(for: note) else {
                    completion?(.failure(BeamNoteSharingUtilsError.emptyPublicUrl))
                    return
                }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(publicLink.absoluteString, forType: .string)
                completion?(.success(publicLink))
        }
    }

    /// Change the publication status of a note
    /// - Parameters:
    ///   - note: The note to publish or unpublish
    ///   - becomePublic: If we should publish or unpublish
    ///   - documentManager: The document manager to save the note after the udpate
    ///   - completion: The callback with the result (is note public) or the error
    static func makeNotePublic(_ note: BeamNote, becomePublic: Bool, documentManager: DocumentManager, completion: ((Result<Bool, Error>) -> Void)? = nil) {

        guard note.ongoingPublicationOperation == false else {
            completion?(.failure(BeamNoteSharingUtilsError.ongoingOperation))
            return
        }

        guard AuthenticationManager.shared.isAuthenticated else {
            let error = BeamNoteSharingUtilsError.userNotLoggedIn
            Logger.shared.logError(error.localizedDescription, category: .notePublishing)
            completion?(.failure(error))
            return
        }

        guard let username = Persistence.Authentication.username ?? Persistence.Authentication.email else {
            let error = BeamNoteSharingUtilsError.userNotLoggedIn
            Logger.shared.logError(error.localizedDescription, category: .notePublishing)
            completion?(.failure(error))
            return
        }

        note.ongoingPublicationOperation = true

        if becomePublic {
            publishNote(note, username: username) { result in
                makeNotePublicHandler(note, becomePublic, documentManager, result, completion)
            }
        } else {
            unpublishNote(with: note.id, completion: { result in
                makeNotePublicHandler(note, becomePublic, documentManager, result, completion)
            })
        }
    }

    static private func makeNotePublicHandler(_ note: BeamNote,
                                              _ becomePublic: Bool,
                                              _ documentManager: DocumentManager,
                                              _ result: Result<PublicationStatus, Error>,
                                              _ completion: ((Result<Bool, Error>) -> Void)? = nil) {
        DispatchQueue.main.async {
            switch result {
            case .failure(let error):
                Logger.shared.logError(error.localizedDescription, category: .notePublishing)
                completion?(.failure(error))
            case .success(let status):
                note.publicationStatus = status
                note.save(documentManager: documentManager) { result in
                    switch result {
                    case .failure(let error):
                        Logger.shared.logError(error.localizedDescription, category: .notePublishing)
                        completion?(result)
                    case .success:
                        // TODO: if `save` isn't successful, we should probably call completion with `.failure`
                        completion?(.success(becomePublic))
                    }

                    note.ongoingPublicationOperation = false
                }
            }
        }
    }

    /// Publish a note to the Public Server.
    /// This method DOESN'T update the note with the PublicationStatus
    /// - Parameters:
    ///   - note: The note to publish
    ///   - username: The current user username, or if not set it's email
    ///   - completion: The callback with the resulted PublicationStatus or error
    static func publishNote(_ note: BeamNote, username: String, completion: @escaping ((Result<PublicationStatus, Error>) -> Void)) {
        Self.publicServer.request(publicServerRequest: .publishNote(note: note, username: username), completion: { completion($0) })
    }

    /// Unpublish a note from the Public Server.
    /// This method DOESN'T update the note with the PublicationStatus
    /// - Parameters:
    ///   - noteId: The id of the note to unpublish
    ///   - completion: The callback with the resulted PublicationStatus or error
    static func unpublishNote(with noteId: UUID, completion: @escaping ((Result<PublicationStatus, Error>) -> Void)) {
        BeamNoteSharingUtils.publicServer.request(publicServerRequest: .unpublishNote(noteId: noteId), completion: { completion($0) })
    }
}
