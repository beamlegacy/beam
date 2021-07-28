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
}

class BeamNoteSharingUtils {

    private let note: BeamNote

    init(note: BeamNote) {
        self.note = note
    }

    var canMakePublic: Bool {
        AuthenticationManager.shared.isAuthenticated
    }

    func getPublicLink(completion: @escaping ((Result<String, Error>) -> Void)) {
        let documentRequest = DocumentRequest()

        do {
            try documentRequest.publicUrl(note.id.uuidString.lowercased(), completion)
        } catch {
            completion(.failure(error))
        }
    }

    func copyLinkToClipboard(completion: ((Result<Bool, Error>) -> Void)? = nil) {
        getPublicLink { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    completion?(.failure(error))
                case .success(let link):
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(link, forType: .string)
                    completion?(.success(true))
                }
            }
        }
    }

    func makeNotePublic(_ becomePublic: Bool, documentManager: DocumentManager, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        note.isPublic = becomePublic
        note.save(documentManager: documentManager, completion: completion)
    }
}
