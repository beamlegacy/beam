import Foundation
import BeamCore

enum BeamNoteSharingUtilsError: Error {
    case missingRequirement
    case canceled
}

/// Stub — remote publishing removed.
struct BeamNoteSharingUtils {
    static var canMakePublic: Bool { false }

    static func getPublicLink(for note: BeamNote) -> URL? { nil }
    static func getProfileLink() -> URL? { nil }

    static func copyLinkToClipboard(for note: BeamNote, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        completion?(.failure(BeamNoteSharingUtilsError.missingRequirement))
    }

    static func makeNotePublic(_ note: BeamNote, becomePublic: Bool, publicationGroups: [String]? = nil, fileManager: BeamFileDBManager? = nil, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        completion?(.failure(BeamNoteSharingUtilsError.missingRequirement))
    }

    static func updatePublicationGroup(_ note: BeamNote, publicationGroups: [String], fileManager: BeamFileDBManager? = nil, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        completion?(.failure(BeamNoteSharingUtilsError.missingRequirement))
    }

    static func removeFromProfile(_ note: BeamNote, fileManager: BeamFileDBManager? = nil, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        completion?(.failure(BeamNoteSharingUtilsError.missingRequirement))
    }

    static func unpublishNote(with id: UUID, fileManager: BeamFileDBManager? = nil, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        completion?(.failure(BeamNoteSharingUtilsError.missingRequirement))
    }
}
