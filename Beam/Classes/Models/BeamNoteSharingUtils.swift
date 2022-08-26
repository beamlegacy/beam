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
    case cantUpdatePublicationGroup
}

private struct BeamNoteSharingUtilsDataSource: BeamDocumentSource {
    static var sourceId: String { "BeamNoteSharingUtils" }
}

class BeamNoteSharingUtils {

    static private let publicServer: RestAPIServer = RestAPIServer()

    static var canMakePublic: Bool {
        AuthenticationManager.shared.isAuthenticated
    }

    static func getPublicLink(for note: BeamNote) -> URL? {
        if case .published(let link, let shortLink, _, _) = note.publicationStatus {
            return shortLink ?? link
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

    static func getProfileLink() -> URL? {
        guard AuthenticationManager.shared.isAuthenticated, let username = AuthenticationManager.shared.username else { return nil }
        var profileURL = URL(string: Configuration.publicAPIpublishServer)
        profileURL?.appendPathComponent(username)

        return profileURL
    }

    /// Change the publication status of a note
    /// - Parameters:
    ///   - note: The note to publish or unpublish
    ///   - becomePublic: If we should publish or unpublish
    ///   - publicationGroups: The publication groups the note belongs to
    ///   - completion: The callback with the result (is note public) or the error
    static func makeNotePublic(_ note: BeamNote, becomePublic: Bool, publicationGroups: [String]? = nil, completion: ((Result<Bool, Error>) -> Void)? = nil) {

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
            let tabGroups = getAssociatedTabGroups(for: note)
            publishNote(note, tabGroups: tabGroups, publicationGroups: publicationGroups) { result in
                makeNotePublicHandler(note, becomePublic, result, completion)
            }
        } else {
            unpublishNote(with: note.id, completion: { result in
                makeNotePublicHandler(note, becomePublic, result, completion)
            })
        }
    }

    static private func getAssociatedTabGroups(for note: BeamNote) -> [TabGroupBeamObject]? {
        if case .tabGroup(let groupId) = note.type, let tabGroup = BeamData.shared.tabGroupingDBManager?.fetch(byIds: [groupId]) {
            return tabGroup
        } else if !note.tabGroups.isEmpty {
            return BeamData.shared.tabGroupingDBManager?.fetch(byIds: note.tabGroups)
        }
        return nil
    }

    static private func makeNotePublicHandler(_ note: BeamNote,
                                              _ becomePublic: Bool,
                                              _ result: Result<PublicationStatus, Error>,
                                              _ completion: ((Result<Bool, Error>) -> Void)? = nil) {
        DispatchQueue.main.async {
            switch result {
            case .failure(let error):
                Logger.shared.logError(error.localizedDescription, category: .notePublishing)
                if !becomePublic, let serverError = error as? RestAPIServer.Error, serverError == .notFound {
                    // This is when you try to unpublish an unexisting note server-side (probably server deleted)
                    // Even if we had a failure, we need to update and save the note, and report the completion as a failure.
                    note.publicationStatus = .unpublished
                    _ = note.save(BeamNoteSharingUtilsDataSource())
                    completion?(.failure(error))
                } else {
                    completion?(.failure(error))
                }
                note.ongoingPublicationOperation = false
            case .success(let status):
                note.publicationStatus = status
                _ = note.save(BeamNoteSharingUtilsDataSource())
                completion?(.success(becomePublic))
                note.ongoingPublicationOperation = false
            }
        }
    }

    // MARK: - Publish on Profile

    static func addToProfile(_ note: BeamNote, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard note.publicationStatus.isPublic,
              var publicationGroups = note.publicationStatus.publicationGroups else {
            completion?(.failure(BeamNoteSharingUtilsError.missingRequirement))
            return
        }

        if !publicationGroups.contains("profile") {
            publicationGroups.append("profile")
        }
        Self.updatePublicationGroup(note, publicationGroups: publicationGroups, completion: completion)
    }

    static func removeFromProfile(_ note: BeamNote, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard note.publicationStatus.isPublic,
              var publicationGroups = note.publicationStatus.publicationGroups,
                let idx = publicationGroups.firstIndex(where: { $0 == "profile" }) else {
            completion?(.failure(BeamNoteSharingUtilsError.cantUpdatePublicationGroup))
            return
        }
        publicationGroups.remove(at: idx)

        Self.updatePublicationGroup(note, publicationGroups: publicationGroups, completion: completion)
    }

    // MARK: - Update Publication Groups

    static func updatePublicationGroup(_ note: BeamNote, publicationGroups: [String], completion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard note.publicationStatus.isPublic else {
            completion?(.failure(BeamNoteSharingUtilsError.cantUpdatePublicationGroup))
            return
        }

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
        let tabGroups = getAssociatedTabGroups(for: note)

        updatePublicationGroup(for: note, tabGroups: tabGroups, publicationGroups: publicationGroups, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let status):
                    note.publicationStatus = status
                    _ = note.save(BeamNoteSharingUtilsDataSource())
                    // TODO: if `save` isn't successful, we should probably call completion with `.failure`
                    completion?(.success(true))
                    note.ongoingPublicationOperation = false
                case .failure(let error):
                    note.ongoingPublicationOperation = false
                    completion?(.failure(error))
                }
            }
        })
    }

    /// Publish a note to the Public Server.
    /// This method DOESN'T update the note with the PublicationStatus
    /// - Parameters:
    ///   - note: The note to publish
    ///   - tabGroups: The tab groups included in that note (in type or in content)
    ///   - publicationGroups: The publication groups the note belongs to
    ///   - completion: The callback with the resulted PublicationStatus or error
    static func publishNote(_ note: BeamNote,
                            tabGroups: [TabGroupBeamObject]?,
                            publicationGroups: [String]?,
                            completion: @escaping ((Result<PublicationStatus, Error>) -> Void)) {
        Self.publicServer.request(serverRequest: .publishNote(note: note,
                                                              tabGroups: tabGroups,
                                                              publicationGroups: publicationGroups),
                                  completion: { completion($0) })
    }

    /// Unpublish a note from the Public Server.
    /// This method DOESN'T update the note with the PublicationStatus
    /// - Parameters:
    ///   - noteId: The id of the note to unpublish
    ///   - completion: The callback with the resulted PublicationStatus or error
    static func unpublishNote(with noteId: UUID, completion: @escaping ((Result<PublicationStatus, Error>) -> Void)) {
        BeamNoteSharingUtils.publicServer.request(serverRequest: .unpublishNote(noteId: noteId), completion: { completion($0) })
    }

    /// Update a note publication group to the Public Server.
    /// This method DOESN'T update the note with the PublicationStatus
    /// - Parameters:
    ///   - note: The note to updates its publcationGroups
    ///   - tabGroups: The tab groups included in that note (in type or in content)
    ///   - publicationGroups: The publication groups the note belongs to
    ///   - completion: The callback with the resulted PublicationStatus or error
    private static func updatePublicationGroup(for note: BeamNote,
                                               tabGroups: [TabGroupBeamObject]?,
                                               publicationGroups: [String],
                                               completion: @escaping ((Result<PublicationStatus, Error>) -> Void)) {
        Self.publicServer.request(serverRequest: .updatePublicationGroup(note: note,
                                                                         tabGroups: tabGroups,
                                                                         publicationGroups: publicationGroups),
                                  completion: { completion($0) })
    }
}
