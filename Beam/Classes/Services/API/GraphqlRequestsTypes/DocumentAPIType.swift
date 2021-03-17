import Foundation
import CryptoKit

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
    var documentType: Int16?
    var previousChecksum: String?

    init(document: Document) {
        title = document.title
        id = document.uuidString
        createdAt = document.created_at
        updatedAt = document.updated_at
        deletedAt = document.deleted_at
        documentType = document.document_type
        previousChecksum = document.beam_api_checksum
        data = document.data?.asString
        isPublic = document.is_public
    }

    init(document: DocumentStruct) {
        title = document.title
        id = document.uuidString
        createdAt = document.createdAt
        updatedAt = document.updatedAt
        deletedAt = document.deletedAt
        documentType = document.documentType.rawValue
        previousChecksum = document.previousChecksum
        data = document.data.asString
        isPublic = document.isPublic
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

            data = try EncryptionManager.shared.decryptString(encodedString)
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
        let encryptStruct = DataEncryption(encryptionName: EncryptionManager.shared.name,
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
