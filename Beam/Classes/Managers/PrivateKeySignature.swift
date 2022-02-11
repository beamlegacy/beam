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
    static var shared = PrivateKeySignatureManager()

    internal static var conflictPolicy: BeamObjectConflictResolution = .replace
    internal static var backgroundQueue: DispatchQueue = DispatchQueue(label: "PrivateKeySignatureManager BeamObjectManager backgroundQueue", qos: .userInitiated)
    var privateKeySignature: PrivateKeySignature { PrivateKeySignature() }

    enum DistantKeyStatus {
        case valid
        case invalid
        case none
    }

    func distantKeyStatus() throws -> DistantKeyStatus {
        var status = DistantKeyStatus.none
        let semaphore = DispatchSemaphore(value: 0)
        try self.fetchAllFromBeamObjectAPI(raisePrivateKeyError: true) { result in
            switch result {
            case .failure(let error):
                switch error {
                case let BeamObjectRequest.BeamObjectRequestError.privateKeyError(validObjects: _, invalidObjects: invalidObjects):
                    assert(!invalidObjects.isEmpty)
                    assert(invalidObjects.first?.beamObjectType == BeamObjectObjectType.privateKeySignature.rawValue)
                default:
                    break
                }

                Logger.shared.logError("Error fetching distant key from API: \(error)", category: .privateKeySignature)
                status = .invalid
            case .success(let signatures):
                status = signatures.isEmpty ? .none : .valid
            }
            semaphore.signal()
        }
        semaphore.wait()
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

    func saveOnNetwork(_ signature: PrivateKeySignature, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        Self.backgroundQueue.async { [weak self] in
            do {
                try self?.saveOnBeamObjectAPI(signature, force: true) { result in
                    switch result {
                    case .success:
                        Logger.shared.logDebug("Saved signature on the BeamObject API", category: .privateKeySignature)
                        networkCompletion?(.success(true))
                    case .failure(let error):
                        Logger.shared.logDebug("Error when saving the signature on the BeamObject API", category: .privateKeySignature)
                        networkCompletion?(.failure(error))
                    }
                }
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .privateKeySignature)
            }
        }
    }
}
