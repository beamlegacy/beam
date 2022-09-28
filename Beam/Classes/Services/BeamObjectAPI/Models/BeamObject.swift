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

    var hasBeenSyncedOnce: Bool {
        previousChecksum != nil
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
class BeamObject: Decodable {
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
    var largeDataBlobId: String?

    // Only used for multipart uploads
    var largeData: String?

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
        case noEmail
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case beamObjectType = "type"
        case createdAt
        case updatedAt
        case deletedAt
        case receivedAt
        case data
        case largeData
        case dataUrl
        case dataChecksum = "checksum"
        case previousChecksum
        case privateKeySignature
        case largeDataBlobId
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

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        id = try values.decode(UUID.self, forKey: .id)
        beamObjectType = try values.decode(String.self, forKey: .beamObjectType)

        createdAt = try values.decodeIfPresent(String.self, forKey: .createdAt)?.iso8601withFractionalSeconds
        updatedAt = try values.decodeIfPresent(String.self, forKey: .updatedAt)?.iso8601withFractionalSeconds
        deletedAt = try values.decodeIfPresent(String.self, forKey: .deletedAt)?.iso8601withFractionalSeconds
        receivedAt = try values.decodeIfPresent(String.self, forKey: .receivedAt)?.iso8601withFractionalSeconds

        data = try values.decodeIfPresent(Data.self, forKey: .data)
        dataUrl = try values.decodeIfPresent(String.self, forKey: .dataUrl)
        dataChecksum = try values.decodeIfPresent(String.self, forKey: .dataChecksum)
        previousChecksum = try values.decodeIfPresent(String.self, forKey: .previousChecksum)
        privateKeySignature = try values.decodeIfPresent(String.self, forKey: .privateKeySignature)
        largeDataBlobId = try values.decodeIfPresent(String.self, forKey: .largeDataBlobId)
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601withFractionalSeconds
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.userInfo[Self.beamObjectCoding] = true
        return encoder
    }

    static var decoder: BeamJSONDecoder {
        let decoder = BeamJSONDecoder()
        decoder.dateDecodingStrategy = .iso8601withFractionalSeconds
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.userInfo[Self.beamObjectCoding] = true
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
        result.largeDataBlobId = largeDataBlobId

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
            Logger.shared.logError("Error decoding \(self.beamObjectType) error: \(error)",
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

    public static let beamObjectCoding = CodingUserInfoKey(rawValue: "beamObjectCoding")!
    public static let beamObjectId = CodingUserInfoKey(rawValue: "beamObjectId")!

    func encodeObject<T: BeamObjectProtocol>(_ object: T) throws {
        assert(!encoded)
        let localTimer = Date()

        let encoder = Self.encoder
        encoder.userInfo[Self.beamObjectId] = object.beamObjectId
        let jsonData = try encoder.encode(object)

        encoded = true
        data = jsonData
        dataChecksum = jsonData.SHA256

        let timeDiff = Date().timeIntervalSince(localTimer)
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

            let decoder = Self.decoder
            decoder.userInfo[Self.beamObjectId] = id
            return try decoder.decode(T.self, from: data)
        } catch {
            Logger.shared.logError("Couldn't decode object \(T.self): \(self)",
                                   category: .beamObject)
        }
        return nil
    }
}

// The GraphQL API expects `largeData: nil` when we upload with multipart but Swift doesn't support that and remove null values
// Writing our own encodable to keep those
extension BeamObject: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(beamObjectType, forKey: .beamObjectType)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try container.encodeIfPresent(receivedAt, forKey: .receivedAt)
        try container.encodeIfPresent(data, forKey: .data)
        try container.encodeIfPresent(dataUrl, forKey: .dataUrl)
        try container.encodeIfPresent(dataChecksum, forKey: .dataChecksum)
        try container.encodeIfPresent(previousChecksum, forKey: .previousChecksum)
        try container.encodeIfPresent(privateKeySignature, forKey: .privateKeySignature)
        try container.encodeIfPresent(largeDataBlobId, forKey: .largeDataBlobId)

        // If we don't send this as `null` multipart uploads aren't considered on the GraphQL server-side
        try container.encode(largeData, forKey: .largeData)
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

        guard let email = Persistence.Authentication.email else {
            throw BeamObjectError.noEmail
        }
        let currentPrivateKeySignature = try EncryptionManager.shared.privateKey(for: email).asString().SHA256()
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
        guard let clearData = data else { return }

        assert(!encrypted)

        guard let email = Persistence.Authentication.email else {
            throw BeamObjectError.noEmail
        }

        if Configuration.env == .test,
           EncryptionManager.shared.privateKey(for: Persistence.emailOrRaiseError()).asString() != Configuration.testPrivateKey, Configuration.env != .uiTest {
            fatalError("Not using the test key! Please use `try? EncryptionManager.shared.replacePrivateKey(for: Configuration.testAccountEmail, with: Configuration.testPrivateKey)` in your tests")
        }

        guard let encryptedClearData = try EncryptionManager.shared.encryptData(clearData) else {
            throw BeamObjectError.noData
        }

        encrypted = true
        data = encryptedClearData

        privateKeySignature = try EncryptionManager.shared.privateKey(for: email).asString().SHA256()
    }
}
