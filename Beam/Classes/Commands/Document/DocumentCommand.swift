//
//  DocumentCommand.swift
//  Beam
//
//  Created by Remi Santos on 25/05/2021.
//

import Foundation
import BeamCore

class DocumentCommand: CommandAsync<DocumentManager> {
    var documentIds = [UUID]()
    var documents = [DocumentStruct]()

    override func coalesce(command: Command<DocumentManager>) -> Bool {
        guard let command = command as? DocumentCommand,
              type(of: command) === type(of: self) else { return false }
        documentIds = Array(Set(documentIds + command.documentIds))
        return true
    }

    // should we implement encode/decode? why?
}
