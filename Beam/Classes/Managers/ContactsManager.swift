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
    var changedObjects: [UUID: ContactRecord] = [:]
    static let shared = ContactsManager()
    private var contactsDB: ContactsDB? { BeamData.shared.contactsDB }

    init() {
    }

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
    func save(email: String, to noteId: UUID, networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) -> ContactRecord? {
        guard email.mayBeEmail else {
            networkCompletion?(.success(false))
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
            if let contactRecord = contactRecord, AuthenticationManager.shared.isAuthenticated {
                try self.saveOnNetwork(contactRecord, networkCompletion)
            } else {
                networkCompletion?(.success(false))
            }
            return contactRecord
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .contactsDB)
        }
        networkCompletion?(.success(false))
        return nil
    }

    // MARK: Delete
    func markDeleted(noteId: UUID, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) {
        do {

            if let contactRecord = try contactsDB?.markDeleted(noteId: noteId),
               AuthenticationManager.shared.isAuthenticated {
                try self.saveOnNetwork(contactRecord, networkCompletion)
            } else {
                networkCompletion?(.success(false))
            }
            return
        } catch ContactsDBError.cantDeleteContact(errorMsg: let errorMsg) {
            Logger.shared.logError("Error while deleting contacts for \(noteId): \(errorMsg)", category: .contactsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription)", category: .contactsDB)
        }
        networkCompletion?(.success(false))
    }

    func deleteAll(includedRemote: Bool, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) {
        do {
            try contactsDB?.deleteAll()
            if AuthenticationManager.shared.isAuthenticated && includedRemote {
                Task {
                    do {
                        try await self.deleteAllFromBeamObjectAPI()
                        networkCompletion?(.success(true))
                    } catch {
                        Logger.shared.logError("Error while deleting all contacts: \(error)", category: .contactsDB)
                        networkCompletion?(.success(false))
                    }
                }
            } else {
                networkCompletion?(.success(false))
            }
            return
        } catch ContactsDBError.cantDeleteContact(errorMsg: let errorMsg) {
            Logger.shared.logError("Error while deleting all contacts: \(errorMsg)", category: .contactsDB)
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .contactsDB)
        }
        networkCompletion?(.success(false))
    }
}

extension ContactsManager: BeamObjectManagerDelegate {
    static var conflictPolicy: BeamObjectConflictResolution = .replace
    static var uploadType: BeamObjectRequestUploadType {
        Configuration.directUploadAllObjects ? .directUpload : .multipartUpload
    }
    internal static var backgroundQueue = DispatchQueue(label: "ContactsManager BeamObjectManager backgroundQueue", qos: .userInitiated)
    func willSaveAllOnBeamObjectApi() {}

    func saveObjectsAfterConflict(_ contacts: [ContactRecord]) throws {
        try self.contactsDB?.save(contacts: contacts)
    }

    func manageConflict(_ dbStruct: ContactRecord,
                        _ remoteDbStruct: ContactRecord) throws -> ContactRecord {
        fatalError("Managed by BeamObjectManager")
    }

    func receivedObjects(_ contacts: [ContactRecord]) throws {
        try self.contactsDB?.save(contacts: contacts)
    }

    func allObjects(updatedSince: Date?) throws -> [ContactRecord] {
        (try self.contactsDB?.allRecords(updatedSince)) ?? []
    }

    func saveAllOnNetwork(_ contacts: [ContactRecord], _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try await self?.saveOnBeamObjectsAPI(contacts)
                Logger.shared.logDebug("Saved contacts on the BeamObject API", category: .contactsDB)
                networkCompletion?(.success(true))
            } catch {
                Logger.shared.logDebug("Error when saving the contacts on the BeamObject API", category: .contactsDB)
                networkCompletion?(.failure(error))
            }
        }
    }

    private func saveOnNetwork(_ contact: ContactRecord, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try await self?.saveOnBeamObjectAPI(contact)
                Logger.shared.logDebug("Saved contact on the BeamObject API", category: .contactsDB)
                networkCompletion?(.success(true))
            } catch {
                Logger.shared.logDebug("Error when saving the contact on the BeamObject API with error: \(error.localizedDescription)", category: .contactsDB)
                networkCompletion?(.failure(error))
            }
        }
    }
}
