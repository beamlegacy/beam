//
//  BeamDocumentCollection+Validation.swift
//  Beam
//
//  Created by Sebastien Metrot on 11/05/2022.
//

import Foundation
import BeamCore

public extension BeamDocumentCollection {
    // MARK: Validations
    func checkValidations(_ document: BeamDocument) throws {
        #if DEBUG
        guard document.deletedAt == nil else {
            throw BeamDocumentCollectionError.deletedDocumentsCantBeSavedLocally
        }

        Logger.shared.logDebug("checkValidations for \(document.titleAndId)", category: .documentDebug)
        guard !document.source.isEmpty else {
            throw BeamDocumentCollectionError.missingSource
        }
        try checkJournalDay(document)

        #if DEBUG
        // Disabling these checks for performance while typing. Should be checked only when the respective properties change. BE-4790
        try checkDuplicateJournalDates(document)
        try checkDuplicateTitles(document)
        #endif

        try checkVersion(document)
        #endif
    }

    private func checkJournalDay(_ document: BeamDocument) throws {
        guard document.documentType == .journal else { return }
        guard String(document.journalDate).count != 8 else { return }

        Logger.shared.logError("journalDate is \(document.journalDate) for \(document.titleAndId)", category: .document)
        throw BeamDocumentCollectionError.invalidJournalDay(document)
    }

    private func checkDuplicateJournalDates(_ document: BeamDocument) throws {
        guard document.documentType == .journal else { return }
        guard String(document.journalDate).count == 8 else { return }

        let documents = (try? fetch(filters: [.journalDate(document.journalDate), .notId(document.id)])) ?? []

        if !documents.isEmpty {
            Logger.shared.logError("Journal Date \(document.journalDate) for \(document.titleAndId) already used in \(documents.count) other documents: \(documents.map { $0.titleAndId })", category: .document)

            throw BeamDocumentCollectionError.duplicateJournalEntry(document)
        }
    }

    private func checkDuplicateTitles(_ document: BeamDocument) throws {
        let documents = (try? fetch(filters: [.title(document.title), .notId(document.id)])) ?? []

        if !documents.isEmpty {
            let documentIds = documents.compactMap { $0.titleAndId }.joined(separator: "; ")

            Logger.shared.logError("Title \(document.titleAndId) is already used in \(documents.count) other documents: \(documentIds)", category: .document)

            throw BeamDocumentCollectionError.duplicateTitle(document)
        }
    }

    private func checkVersion(_ document: BeamDocument) throws {
        // If document is deleted, we don't need to check version uniqueness
        guard document.deletedAt == nil else { return }

        guard let existingDocument = try? fetchWithId(document.id) else { return }

        if document.version <= existingDocument.version {
            Logger.shared.logError("\(document.title): stored version: \(existingDocument.version) should be < newVersion: \(document.version)", category: .document)
            throw BeamDocumentCollectionError.failedVersionCheck(document, existingVersion: existingDocument.version, newVersion: document.version)
        }
    }
}
