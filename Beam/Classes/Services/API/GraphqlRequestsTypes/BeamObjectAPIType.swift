import Foundation
import CryptoKit
import BeamCore

protocol BeamObjectProtocol: Codable {
    var uuid: String { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
    var deletedAt: Date? { get }
    var previousChecksum: String? { get }
}

enum BeamObjectType: String {
    case password
    case database
    case document
}

class BeamObjectAPIType: Codable {
    var id: String?
    var beamObjectType: String?
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?
    var data: String?
    var encryptedData: String?
    var dataChecksum: String?
    var previousChecksum: String?

    enum CodingKeys: String, CodingKey {
        case id
        case beamObjectType = "type"
        case createdAt
        case updatedAt
        case deletedAt
        case data
        case dataChecksum = "checksum"
        case previousChecksum
    }

    init<T: BeamObjectProtocol>(_ object: T, _ type: BeamObjectType) throws {
        id = object.uuid
        beamObjectType = type.rawValue

        createdAt = object.createdAt
        updatedAt = object.updatedAt
        deletedAt = object.deletedAt

        previousChecksum = object.previousChecksum

        let jsonData = try Self.encoder.encode(object)
        data = jsonData.asString
        dataChecksum = jsonData.SHA256
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Encryption
    struct DataEncryption: Codable {
        let encryptionName: String?
        let privateKeySha256: String?
        let data: String?
        //swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case encryptionName
            case privateKeySha256
            case data
        }
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

            do {
                data = try EncryptionManager.shared.decryptString(encodedString, using: algorithm)
                encryptedData = encodedData
            } catch EncryptionManagerError.authenticationFailure {
                Logger.shared.logError("Could not decrypt data with key \(decodedStruct.privateKeySha256 ?? "-")", category: .encryption)
            }
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

    func encrypt() throws {
        guard let clearData = data else { return }

        dataChecksum = try clearData.SHA256()

        let encryptedClearData = try EncryptionManager.shared.encryptString(clearData)

        let encryptStruct = DataEncryption(encryptionName: EncryptionManager.Algorithm.AES_GCM.rawValue,
                                           privateKeySha256: try? EncryptionManager.shared.privateKey().asString().SHA256(),
                                           data: encryptedClearData)

        let encoder = JSONEncoder()
        let encodedStruct = try encoder.encode(encryptStruct)

        data = encodedStruct.asString
    }
}
