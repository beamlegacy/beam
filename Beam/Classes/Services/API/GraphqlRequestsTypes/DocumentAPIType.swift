import Foundation
import CryptoKit
import BeamCore

enum DocumentTypeType: String, Codable {
    case journal = "JOURNAL"
    case note = "NOTE"
}
/*
 Used for interacting with Beam API

 `data`: clear version of the data
 `dataChecksum`: MD5 hash of either `encryptedData` (if encryption is enabled) or `data`
 `encryptedData`: encrypted version of the data, either for sending or receiving
 `previousChecksum`: MD5 hash of the version we sent to Beam API.

 Document.beam_api_data must not be encrypted so we can use it as an text ancestor for our merges.
 */
class DocumentAPIType: Codable {
    var id: String?
    var title: String?
    var isPublic: Bool?
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?
    var data: String?
    var encryptedData: String?
    var dataChecksum: String?
    var documentType: DocumentTypeType?
    var previousChecksum: String?
    var database: DatabaseAPIType?
    var publicUrl: String?

    init(document: Document, context: NSManagedObjectContext) {
        title = document.title
        id = document.uuidString
        createdAt = document.created_at
        updatedAt = document.updated_at
        deletedAt = document.deleted_at
        documentType = document.document_type == 0 ? .journal : .note
        previousChecksum = document.beam_api_checksum
        data = document.data?.asString
        isPublic = document.is_public

        let dbDatabase = try? Database.rawFetchWithId(context, document.database_id)

        database = DatabaseAPIType(id: document.database_id.uuidString.lowercased())
        database?.title = dbDatabase?.title
    }

    init(document: DocumentStruct) {
        title = document.title
        id = document.uuidString
        createdAt = document.createdAt
        updatedAt = document.updatedAt
        deletedAt = document.deletedAt
        documentType = document.documentType == .journal ? .journal : .note
        previousChecksum = document.previousChecksum
        data = document.data.asString
        isPublic = document.isPublic
        database = DatabaseAPIType(id: document.databaseId.uuidString.lowercased())
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        context.performAndWait {
            guard let dbDatabase = try? Database.rawFetchWithId(context, document.databaseId) else { return }
            database = DatabaseAPIType(database: dbDatabase)
        }
    }

    // Used to recreate an instance *before* doing the network call
    // Not all attributes should be used, and we'll use encryptedData
    // if needed
    init(document: DocumentAPIType) {
        title = document.title
        id = document.id
        createdAt = document.createdAt
        updatedAt = document.updatedAt
        deletedAt = document.deletedAt
        documentType = document.documentType
        previousChecksum = document.previousChecksum
        data = document.shouldEncrypt ? document.encryptedData : document.data
        isPublic = document.isPublic
        database = document.database
    }

    init(id: String) {
        self.id = id
    }

    struct DataEncryption: Codable {
        let encryptionName: String?
        let data: String?
    }

    func decrypt() throws {
        guard Configuration.encryptionEnabled else { return }
        guard let encodedData = data else { return }

        let decoder = JSONDecoder()

        do {
            let decodedStruct = try decoder.decode(DataEncryption.self, from: encodedData.asData)
            guard let encodedString = decodedStruct.data else { return }
            guard let encryptionName = decodedStruct.encryptionName,
                  let algorithm = EncryptionManager.Algorithm(rawValue: encryptionName) else { return }

            data = try EncryptionManager.shared.decryptString(encodedString, using: algorithm)
            encryptedData = encodedData

        } catch DecodingError.dataCorrupted {
            Logger.shared.logError("DecodingError.dataCorrupted", category: .encryption)
            Logger.shared.logDebug("Encoded data: \(encodedData)", category: .encryption)

            // JSON decoding error might happen when the content wasn't encrypted
            encryptedData = nil
        } catch DecodingError.typeMismatch {
            Logger.shared.logError("DecodingError.typeMismatch", category: .encryption)
            Logger.shared.logDebug("Encoded data: \(encodedData)", category: .encryption)

            // JSON decoding error might happen when the content wasn't encrypted
            encryptedData = nil
        } catch {
            Logger.shared.logError("\(type(of: error)): \(error) \(error.localizedDescription)", category: .encryption)
            Logger.shared.logDebug("Encoded data: \(encodedData)", category: .encryption)
            throw error
        }
    }

    var shouldEncrypt: Bool {
        Configuration.encryptionEnabled && !(isPublic ?? false)
    }

    func encrypt() throws {
        guard shouldEncrypt else {
            dataChecksum = try data?.MD5()
            return
        }
        guard let clearData = data else { return }

        let encryptedClearData = try EncryptionManager.shared.encryptString(clearData)
        let encryptStruct = DataEncryption(encryptionName: EncryptionManager.Algorithm.AES_GCM.rawValue,
                                           data: encryptedClearData)

        let encoder = JSONEncoder()
        let encodedStruct = try encoder.encode(encryptStruct)

        encryptedData = encodedStruct.asString
        dataChecksum = try encodedStruct.asString?.MD5()
    }

    func clearForImports() {
        encryptedData = nil
        dataChecksum = nil
    }
}
