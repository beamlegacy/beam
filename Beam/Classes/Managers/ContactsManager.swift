//
//  ContactsManager.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 07/12/2021.
//

import Foundation
import BeamCore

enum ContactType: String, Codable {
    case none
    case personal
    case work
}

struct Email: Codable, Hashable {
    var value: String
    var type: ContactType
}

class ContactsManager {
    private var contactsDB: ContactsDB? { BeamData.shared.contactsDB }


    // MARK: Fetch
    func fetch(for id: UUID) -> ContactRecord? {
        do {
            let contactRecord = try contactsDB?.fetchWithId(id)
            return contactRecord
        } catch ContactsDBError.errorFetchingContacts(let errorMsg) {
            Logger.shared.logError("Error while fetching contact: \(errorMsg)", category: .contactsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .contactsDB)
        }
        return nil
    }

    func fetchAll() -> [ContactRecord] {
        do {
            let allContactsRecords = (try contactsDB?.fetchAll()) ?? []
            return allContactsRecords
        } catch ContactsDBError.errorFetchingContacts(let errorMsg) {
            Logger.shared.logError("Error while fetching all contacts: \(errorMsg)", category: .contactsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .contactsDB)
        }
        return []
    }

    func emails(for noteId: UUID) -> [Email]? {
        do {
            guard let contactRecord = try contactsDB?.contact(for: noteId) else { return nil }
            return contactRecord.emails
        } catch ContactsDBError.errorFetchingContacts(let errorMsg) {
            Logger.shared.logError("Error while fetching contacts for \(noteId): \(errorMsg)", category: .contactsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .contactsDB)
        }
        return nil
    }

    func note(for email: String) -> UUID? {
        do {
            guard !email.isEmpty else { return nil }
            let contactRecords = (try contactsDB?.fetchAll()) ?? []
            return contactRecords.first { $0.emails.contains { $0.value == email } }?.noteId
        } catch ContactsDBError.errorFetchingContacts(let errorMsg) {
            Logger.shared.logError("Error while fetching contacts for \(email): \(errorMsg)", category: .contactsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .contactsDB)
        }
        return nil
    }

    // MARK: Search
    // Later on might not only checks for Emails but more like Twitter Handle/ Eth Adress etc
    func hasContactInformations(for noteId: UUID) -> Bool {
        guard let emails = emails(for: noteId) else { return false }
        return !emails.isEmpty
    }

    func search(for noteTitle: String) -> String {
        let searchResult = (try? BeamData.shared.currentDocumentCollection?.fetch(filters: [.titleMatch(noteTitle)])) ?? []
        for result in searchResult {
            if hasContactInformations(for: result.id) {
                return result.title
            }
        }
        return noteTitle
    }

    // MARK: Save & Update
    func save(email: String, to noteId: UUID) -> ContactRecord? {
        guard email.mayBeEmail else {
            return nil
        }
        do {
            var contactRecord: ContactRecord?
            if let previousContactRecord = try? contactsDB?.contact(for: noteId) {
                if !previousContactRecord.emails.compactMap({ $0.value }).contains(email) {
                    var emails = previousContactRecord.emails
                    emails.append(Email(value: email, type: .none))
                    contactRecord = try contactsDB?.update(record: previousContactRecord, with: emails)
                }
            } else {
                contactRecord = try contactsDB?.save([Email(value: email, type: .none)], to: noteId)
            }
            return contactRecord
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .contactsDB)
        }
        return nil
    }

    // MARK: Delete
    func markDeleted(noteId: UUID) {
        do {
            _ = try contactsDB?.markDeleted(noteId: noteId)
        } catch ContactsDBError.cantDeleteContact(errorMsg: let errorMsg) {
            Logger.shared.logError("Error while deleting contacts for \(noteId): \(errorMsg)", category: .contactsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription)", category: .contactsDB)
        }
    }

    func deleteAll() {
        do {
            try contactsDB?.deleteAll()
        } catch ContactsDBError.cantDeleteContact(errorMsg: let errorMsg) {
            Logger.shared.logError("Error while deleting all contacts: \(errorMsg)", category: .contactsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .contactsDB)
        }
    }
}

