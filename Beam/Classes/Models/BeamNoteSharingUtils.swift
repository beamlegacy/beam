//
//  BeamNoteSharingUtils.swift
//  Beam
//
//  Created by Remi Santos on 06/05/2021.
//

import Foundation
import BeamCore

class BeamNoteSharingUtils {

    private let note: BeamNote

    init(note: BeamNote) {
        self.note = note
    }

    private func buildPublicLink(for note: BeamNote) -> String {
        return "\(Configuration.publicHostnameDefault)/documents/\(note.id.uuidString.lowercased())"
    }

    func getPublicLink(completion: ((Result<String, Error>) -> Void)) {
        // We will need to call the api to get the correct link someday.
        let link = buildPublicLink(for: note)
        completion(.success(link))
    }

    func copyLinkToClipboard(completion: ((Result<Bool, Error>) -> Void)? = nil) {
        getPublicLink { result in
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

    func makeNotePublic(_ becomePublic: Bool, documentManager: DocumentManager, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        note.isPublic = becomePublic
        note.save(documentManager: documentManager, completion: completion)
    }

}
