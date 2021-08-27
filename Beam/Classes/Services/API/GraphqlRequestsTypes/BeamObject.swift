import Foundation
import CryptoKit
import BeamCore

/// Anything to be stored as BeamObject should implement this protocol.
protocol BeamObjectProtocol: Codable {
    static var beamObjectTypeName: String { get }

    var beamObjectId: UUID { get set }

    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }

    // IMPORTANT: make sure you list in `enum CodingKeys: String, CodingKey` what you want
    // to store as `BeamObject` and not include `previousChecksum` and `checksum`
    var previousChecksum: String? { get set }
    var checksum: String? { get set }
    func copy() throws -> Self
}

/// Used to store data on the BeamObject Beam API.
class BeamObject: Codable {
    var beamObjectType: String
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?
    var receivedAt: Date?

    var data: Data?
    var dataChecksum: String?
    var previousChecksum: String?
    var privateKeySignature: String?

    var id: UUID

    public var debugDescription: String {
        "<BeamObject: \(id) [\(beamObjectType)]>"
    }

    public var description: String {
        "<BeamObject: \(id) [\(beamObjectType)]>"
    }

    enum BeamObjectError: Error {
        case noData
    }

    private enum CodingKeys: String, CodingKey {
        case id = "id"
        case beamObjectType = "type"
        case createdAt
        case updatedAt
        case deletedAt
        case data
        case dataChecksum = "checksum"
        case previousChecksum
        case privateKeySignature
    }

    init(id: UUID, beamObjectType: String) {
        self.id = id
        self.beamObjectType = beamObjectType
    }

    init<T: BeamObjectProtocol>(_ object: T, _ type: String) throws {
        id = object.beamObjectId
        beamObjectType = type

        createdAt = object.createdAt
        updatedAt = object.updatedAt
        deletedAt = object.deletedAt

        previousChecksum = object.previousChecksum
        try encodeObject(object)

        // Used when going deep in debug
//        if let data = data, let dataChecksum = dataChecksum, let text = data.asString {
//            Logger.shared.logDebug("🦞 SHA checksum on \(text): \(dataChecksum)",
//                                   category: .beamObjectDebug)
//        }
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    func copy() -> BeamObject {
        let result = BeamObject(id: id, beamObjectType: beamObjectType)
        result.createdAt = createdAt
        result.updatedAt = updatedAt
        result.deletedAt = deletedAt

        result.data = data
        result.privateKeySignature = privateKeySignature

        result.previousChecksum = previousChecksum
        result.dataChecksum = dataChecksum
        return result
    }

    func decodeBeamObject<T: BeamObjectProtocol>() throws -> T {
        guard let data = data else {
            throw BeamObjectError.noData
        }
        var decodedObject = try Self.decoder.decode(T.self, from: data)
        decodedObject.beamObjectId = id
        decodedObject.checksum = dataChecksum
        decodedObject.createdAt = createdAt ?? decodedObject.createdAt
        decodedObject.updatedAt = updatedAt ?? decodedObject.updatedAt
        decodedObject.deletedAt = deletedAt ?? decodedObject.deletedAt

        return decodedObject
    }

    func encodeObject<T: BeamObjectProtocol>(_ object: T) throws {
        let jsonData = try Self.encoder.encode(object)

        data = jsonData
        dataChecksum = jsonData.SHA256
    }

    func decode<T: BeamObjectProtocol>() -> T? {
        guard let data = data else { return nil }

        if let dataChecksum = dataChecksum, data.SHA256 != dataChecksum {
            Logger.shared.logError("Checksum received \(dataChecksum) is different from calculated one: \(data.SHA256) :( Data is potentially corrupted",
                                   category: .beamObjectNetwork)
            Logger.shared.logError("data: \(data)", category: .beamObjectNetwork)
        }

        do {
            var result = try Self.decoder.decode(T.self, from: data)

            // Checksum is used to check *after* we encoded the string, so it's not embedded in that encoded string and
            // I reinject it here so whatever is using beam objects can check for previous checksum if needed.
            result.checksum = dataChecksum
            return result
        } catch {
            Logger.shared.logError("Couldn't decode object \(T.self): \(self)",
                                   category: .beamObject)
        }
        return nil
    }

}

// MARK: - Encryption
extension BeamObject {
    func decrypt() throws {
        guard let dataBang = data else { return }

        do {
            data = try EncryptionManager.shared.decryptData(dataBang)
        } catch DecodingError.dataCorrupted {
            Logger.shared.logError("DecodingError.dataCorrupted", category: .encryption)
        } catch DecodingError.typeMismatch {
            Logger.shared.logError("DecodingError.typeMismatch", category: .encryption)
            Logger.shared.logDebug("Encoded data: \(dataBang)", category: .encryption)
        } catch EncryptionManagerError.authenticationFailure {
            Logger.shared.logError("Could not decrypt data with key \(privateKeySignature ?? "-")",
                                   category: .encryption)
            throw EncryptionManagerError.authenticationFailure
        } catch {
            Logger.shared.logError("\(type(of: error)): \(error) \(error.localizedDescription)", category: .encryption)
            Logger.shared.logDebug("Encoded string: \(dataBang)", category: .encryption)
            throw error
        }
    }

    func encrypt() throws {
        guard let clearData = data else { return }

        guard let encryptedClearData = try EncryptionManager.shared.encryptData(clearData) else {
            throw BeamObjectError.noData
        }

        data = encryptedClearData
        privateKeySignature = try EncryptionManager.shared.privateKey().asString().SHA256()
    }
}
