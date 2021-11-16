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
    case ongoingOperation
    case missingRequirement
    case canceled
}

class BeamNoteSharingUtils {

    static private let publicServer: RestAPIServer = RestAPIServer()

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
    ///   - completion: The callback with the result (is note public) or the error
    static func makeNotePublic(_ note: BeamNote, becomePublic: Bool, completion: ((Result<Bool, Error>) -> Void)? = nil) {

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

        note.ongoingPublicationOperation = true

        if becomePublic {
            publishNote(note) { result in
                makeNotePublicHandler(note, becomePublic, result, completion)
            }
        } else {
            unpublishNote(with: note.id, completion: { result in
                makeNotePublicHandler(note, becomePublic, result, completion)
            })
        }
    }

    static private func makeNotePublicHandler(_ note: BeamNote,
                                              _ becomePublic: Bool,
                                              _ result: Result<PublicationStatus, Error>,
                                              _ completion: ((Result<Bool, Error>) -> Void)? = nil) {
        DispatchQueue.main.async {
            switch result {
            case .failure(let error):
                Logger.shared.logError(error.localizedDescription, category: .notePublishing)
                completion?(.failure(error))
                note.ongoingPublicationOperation = false
            case .success(let status):
                note.publicationStatus = status
                note.save() { result in
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
    static func publishNote(_ note: BeamNote, completion: @escaping ((Result<PublicationStatus, Error>) -> Void)) {
        Self.publicServer.request(serverRequest: .publishNote(note: note), completion: { completion($0) })
    }

    /// Unpublish a note from the Public Server.
    /// This method DOESN'T update the note with the PublicationStatus
    /// - Parameters:
    ///   - noteId: The id of the note to unpublish
    ///   - completion: The callback with the resulted PublicationStatus or error
    static func unpublishNote(with noteId: UUID, completion: @escaping ((Result<PublicationStatus, Error>) -> Void)) {
        BeamNoteSharingUtils.publicServer.request(serverRequest: .unpublishNote(noteId: noteId), completion: { completion($0) })
    }
}
