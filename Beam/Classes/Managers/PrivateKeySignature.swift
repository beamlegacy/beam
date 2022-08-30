import Foundation
import UUIDKit
import BeamCore

struct PrivateKeySignature: Codable, Hashable, Equatable {
    var id = UUID.null
    var signature: String
    var createdAt: Date = BeamDate.now
    var updatedAt: Date = BeamDate.now
    var deletedAt: Date?

    init() {
        let pkey = EncryptionManager.shared.privateKey(for: Persistence.emailOrRaiseError()).asString()
        id = UUID.v5(name: pkey, namespace: .url)
        signature = pkey
        if let date = Persistence.Encryption.creationDate {
            createdAt = date
        }
        if let date = Persistence.Encryption.updateDate {
            updatedAt = date
        }
    }

    var isCurrent: Bool {
        signature == EncryptionManager.shared.privateKey(for: Persistence.emailOrRaiseError()).asString()
    }

    enum CodingKeys: String, CodingKey {
        case signature
        case createdAt
        case updatedAt
        case deletedAt
    }
}

extension PrivateKeySignature: BeamObjectProtocol {
    static var beamObjectType: BeamObjectObjectType { .privateKeySignature }

    var beamObjectId: UUID { get { id } set { id = newValue } }

    func copy() throws -> Self {
        var pks = PrivateKeySignature()
        pks.id = id
        pks.signature = signature
        pks.createdAt = createdAt
        pks.updatedAt = updatedAt
        pks.deletedAt = deletedAt
        return pks
    }
}

class PrivateKeySignatureManager: BeamObjectManagerDelegate {
    let objectManager: BeamObjectManager

    var changedObjects: [UUID: PrivateKeySignature] = [:]
    let objectQueue = BeamObjectQueue<PrivateKeySignature>()
    
    internal static var conflictPolicy: BeamObjectConflictResolution = .replace
    static var uploadType: BeamObjectRequestUploadType {
        Configuration.directUploadAllObjects ? .directUpload : .multipartUpload
    }
    var privateKeySignature: PrivateKeySignature { PrivateKeySignature() }

    enum DistantKeyStatus {
        case valid
        case invalid
        case none
    }

    init(objectManager: BeamObjectManager) {
        self.objectManager = objectManager

        registerOnBeamObjectManager(objectManager)
    }

    func distantKeyStatus() async throws -> DistantKeyStatus {
        var status = DistantKeyStatus.none
        do {
            let signatures = try await self.fetchAllFromBeamObjectAPI(raisePrivateKeyError: true)
            status = signatures.isEmpty ? .none : .valid
        } catch {
            switch error {
            case let BeamObjectRequest.BeamObjectRequestError.privateKeyError(validObjects: _, invalidObjects: invalidObjects):
                assert(!invalidObjects.isEmpty)
                assert(invalidObjects.first?.beamObjectType == BeamObjectObjectType.privateKeySignature.rawValue)
            default:
                throw error
            }

            Logger.shared.logError("Error fetching distant key from API: \(error)", category: .privateKeySignature)
            status = .invalid
        }
        return status
    }

    func willSaveAllOnBeamObjectApi() {}

    func saveObjectsAfterConflict(_ signatures: [PrivateKeySignature]) throws {
        Logger.shared.logDebug("Ignoring saveObjectsAfterConflict for private key signatures \(signatures)", category: .privateKeySignature)
    }

    func manageConflict(_ dbStruct: PrivateKeySignature,
                        _ remoteDbStruct: PrivateKeySignature) throws -> PrivateKeySignature {
        Logger.shared.logDebug("Ignoring private key signature conflict", category: .privateKeySignature)
        return dbStruct
    }

    func receivedObjects(_ signatures: [PrivateKeySignature]) throws {
        // We don't really care about distant signature
    }

    static var sendLocalSignature = true
    func allObjects(updatedSince: Date?) throws -> [PrivateKeySignature] {
        guard Self.sendLocalSignature else { return [] }
        guard let updatedSince = updatedSince else { return [privateKeySignature] }
        return [privateKeySignature].filter { $0.updatedAt >= updatedSince }
    }

    func saveOnNetwork(_ signature: PrivateKeySignature) async throws {
        try await saveOnBeamObjectAPI(signature, force: true)
        Logger.shared.logDebug("Saved signature on the BeamObject API", category: .privateKeySignature)
    }
}
