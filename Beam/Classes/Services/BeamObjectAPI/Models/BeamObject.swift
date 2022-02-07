import Foundation
import CryptoKit
import BeamCore

/// Anything to be stored as BeamObject should implement this protocol.
protocol BeamObjectProtocol: Codable, Hashable {
    static var beamObjectType: BeamObjectObjectType { get }

    var beamObjectId: UUID { get set }

    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }

    func copy() throws -> Self

    var description: String { get }
    var hasLocalChanges: Bool { get }
    var previousSavedObject: Self? { get }
    var previousChecksum: String? { get }
    func checksum() throws -> String
}

extension BeamObjectProtocol {
    public var description: String {
        "<BeamObjectProtocol: \(beamObjectId) [\(Self.beamObjectType.rawValue)]>"
    }

    /// Do we have local changes not yet synced to the API
    var hasLocalChanges: Bool {
        previousSavedObject != self
    }

    var previousSavedObject: Self? {
        try? BeamObjectChecksum.previousSavedObject(object: self)
    }

    var previousChecksum: String? {
        BeamObjectChecksum.previousChecksum(object: self)
    }

    func checksum() throws -> String {
        guard let result = try BeamObject(self).dataChecksum else {
            assert(false)
            return ""
        }
        return result
    }
}

/// Used to store data on the BeamObject Beam API.
class BeamObject: Codable {
    var beamObjectType: String
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?
    var receivedAt: Date?

    var data: Data?
    var dataUrl: String?
    var dataChecksum: String?
    var previousChecksum: String?
    var privateKeySignature: String?

    var id: UUID

    private var encoded: Bool = false
    private var encrypted: Bool = false

    public var debugDescription: String {
        "<BeamObject: \(id) [\(beamObjectType)]>"
    }

    public var description: String {
        "<BeamObject: \(id) [\(beamObjectType)]>"
    }

    enum BeamObjectError: Error {
        case noData
        case differentEncryptionKey
    }

    private enum CodingKeys: String, CodingKey {
        case id = "id"
        case beamObjectType = "type"
        case createdAt
        case updatedAt
        case deletedAt
        case receivedAt
        case data
        case dataUrl = "dataUrl"
        case dataChecksum = "checksum"
        case previousChecksum
        case privateKeySignature
    }

    init(id: UUID, beamObjectType: String) {
        self.id = id
        self.beamObjectType = beamObjectType
    }

    init<T: BeamObjectProtocol>(object: T) throws {
        id = object.beamObjectId
        beamObjectType = type(of: object).beamObjectType.rawValue

        createdAt = object.createdAt
        updatedAt = object.updatedAt
        deletedAt = object.deletedAt

        try encodeObject(object)
    }

    init<T: BeamObjectProtocol>(_ object: T) throws {
        id = object.beamObjectId
        beamObjectType = type(of: object).beamObjectType.rawValue

        createdAt = object.createdAt
        updatedAt = object.updatedAt
        deletedAt = object.deletedAt

        try encodeObject(object)
    }

    init<T: BeamObjectProtocol>(_ object: T, _ type: String) throws {
        id = object.beamObjectId
        beamObjectType = type

        createdAt = object.createdAt
        updatedAt = object.updatedAt
        deletedAt = object.deletedAt

        try encodeObject(object)

        // Used when going deep in debug
//        if let data = data, let dataChecksum = dataChecksum, let text = data.asString {
//            Logger.shared.logDebug("🦞 SHA checksum on \(text): \(dataChecksum)",
//                                   category: .beamObjectDebug)
//        }
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601withFractionalSeconds
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601withFractionalSeconds
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    func copy() -> BeamObject {
        let result = BeamObject(id: id, beamObjectType: beamObjectType)
        result.createdAt = createdAt
        result.updatedAt = updatedAt
        result.deletedAt = deletedAt
        result.receivedAt = receivedAt

        result.data = data
        result.privateKeySignature = privateKeySignature

        result.previousChecksum = previousChecksum
        result.dataChecksum = dataChecksum
        result.encrypted = encrypted
        return result
    }

    func decodeBeamObject<T: BeamObjectProtocol>() throws -> T {
        guard let data = data else {
            throw BeamObjectError.noData
        }

        var decodedObject: T

        do {
            decodedObject = try Self.decoder.decode(T.self, from: data)
        } catch {
            Logger.shared.logError("Error decoding \(self.beamObjectType) error: \(error.localizedDescription)",
                                   category: .beamObject)
            Logger.shared.logError(data.asString ?? "Can't output data", category: .beamObject)
            dump(data.asString)
            throw error
        }

        decodedObject.beamObjectId = id

        // Don't use `createdAt` and `updatedAt` as those might be changed on the API side, only trust the encrypted signed
        // ones from internal data
        // decodedObject.createdAt = createdAt ?? decodedObject.createdAt
        // decodedObject.updatedAt = updatedAt ?? decodedObject.updatedAt

        decodedObject.deletedAt = deletedAt ?? decodedObject.deletedAt

        return decodedObject
    }

    func encodeObject<T: BeamObjectProtocol>(_ object: T) throws {
        assert(!encoded)
        let localTimer = BeamDate.now

        let jsonData = try Self.encoder.encode(object)

        encoded = true
        data = jsonData
        dataChecksum = jsonData.SHA256

        let timeDiff = BeamDate.now.timeIntervalSince(localTimer)
        if timeDiff > 0.1 {
            Logger.shared.logWarning("Slow BeamObject encoding for \(object.beamObjectId) \(T.beamObjectType), size: \(jsonData.count.byteSize)",
                                     category: .beamObject,
                                     localTimer: localTimer)
        }
    }

    func decode<T: BeamObjectProtocol>() -> T? {
        guard let data = data else { return nil }

        if let dataChecksum = dataChecksum, data.SHA256 != dataChecksum {
            Logger.shared.logError("Checksum received \(dataChecksum) is different from calculated one: \(data.SHA256) :( Data is potentially corrupted",
                                   category: .beamObjectNetwork)
            Logger.shared.logError("data: \(data)", category: .beamObjectNetwork)
        }

        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            Logger.shared.logError("Couldn't decode object \(T.self): \(self)",
                                   category: .beamObject)
        }
        return nil
    }
}

extension BeamObject: Equatable {
    static func == (lhs: BeamObject, rhs: BeamObject) -> Bool {
        lhs.beamObjectType == rhs.beamObjectType && lhs.id == rhs.id
    }
}

extension BeamObject: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(beamObjectType)
        hasher.combine(id)
    }
}

// MARK: - Encryption
extension BeamObject {
    func setTimestamps() throws {
        guard let data = data else { return }

        /*
         The returned unencrypted `created_at` and `updated_at` from the API might be different from the one we sent which
         are embed inside the encrypted data. We don't trust the API and only rely on signed data.
         */
        struct BeamObjectDates: Codable {
            let createdAt: Date?
            let updatedAt: Date?
        }

        do {
            let parsedRemoteObject = try Self.decoder.decode(BeamObjectDates.self, from: data)
            createdAt = parsedRemoteObject.createdAt ?? createdAt
            updatedAt = parsedRemoteObject.updatedAt ?? updatedAt
        } catch {
            dump(error)
            throw error
        }
    }
}

// MARK: - Encryption
extension BeamObject {
    func decrypt() throws {
        guard let dataBang = data else { return }

        let currentPrivateKeySignature = try EncryptionManager.shared.privateKey().asString().SHA256()
        guard privateKeySignature == currentPrivateKeySignature else {
            throw BeamObjectError.differentEncryptionKey
        }

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
            throw error
        }

        encrypted = false
    }

    func encrypt() throws {
        assert(!encrypted)

        guard let clearData = data else { return }

        if Configuration.env == .test,
           EncryptionManager.shared.privateKey().asString() != Configuration.testPrivateKey {
            fatalError("Not using the test key! Please use `try? EncryptionManager.shared.replacePrivateKey(Configuration.testPrivateKey)` in your tests")
        }

        guard let encryptedClearData = try EncryptionManager.shared.encryptData(clearData) else {
            throw BeamObjectError.noData
        }

        encrypted = true
        data = encryptedClearData
        privateKeySignature = try EncryptionManager.shared.privateKey().asString().SHA256()
    }
}
