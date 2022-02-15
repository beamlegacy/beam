import Foundation
import CommonCrypto
import BeamCore

class BeamObjectRequest: APIRequest {
    struct DeleteAllBeamObjects: Decodable, Errorable {
        let success: Bool?
        let errors: [UserErrorData]?
    }

    struct BeamObjectIdParameters: Encodable {
        let id: UUID
        let beamObjectType: String
    }

    struct DeleteAllBeamObjectsParameters: Encodable {
        let beamObjectType: String?
    }

    class FetchBeamObject: BeamObject, Errorable, APIResponseCodingKeyProtocol {
        static let codingKey = "beamObject"
        let errors: [UserErrorData]? = nil
    }

    class UpdateBeamObject: Codable, Errorable {
        let beamObject: BeamObject?
        var privateKey: String?
        var errors: [UserErrorData]?

        init(beamObject: BeamObject?, privateKey: String?) {
            self.beamObject = beamObject
            self.privateKey = privateKey
        }
    }

    class DeleteBeamObject: UpdateBeamObject { }

    struct UpdateBeamObjects: Codable, Errorable {
        let beamObjects: [BeamObject]?
        var privateKey: String?
        var errors: [UserErrorData]?
    }

    struct BeamObjectUpload: Codable {
        let id: UUID
        let uploadUrl: String
        let uploadHeaders: String
        let blobSignedId: String
    }

    struct PrepareBeamObjectUpload: Codable, Errorable {
        let beamObjectUpload: BeamObjectUpload?
        var errors: [UserErrorData]?
    }

    struct PrepareBeamObjectsUpload: Codable, Errorable {
        let beamObjectsUpload: [BeamObjectUpload]?
        var errors: [UserErrorData]?
    }

    struct BeamObjectsParameters: Encodable {
        let receivedAtAfter: Date?
        let ids: [UUID]?
        let beamObjectType: String?
        let skipDeleted: Bool?
    }

    internal func saveBeamObjectParameters(_ beamObject: BeamObject) throws -> UpdateBeamObject {
        try beamObject.encrypt()

        #if DEBUG
        return UpdateBeamObject(beamObject: beamObject, privateKey: EncryptionManager.shared.privateKey(for: Persistence.emailOrRaiseError()).asString())
        #else
        return UpdateBeamObject(beamObject: beamObject, privateKey: nil)
        #endif
    }

    internal func saveBeamObjectsParameters(_ beamObjects: [BeamObject]) throws -> UpdateBeamObjects {
        let result: [BeamObject] = try beamObjects.map {
            try $0.encrypt()
            return $0
        }

        #if DEBUG
        return UpdateBeamObjects(beamObjects: result, privateKey: EncryptionManager.shared.privateKey(for: Persistence.emailOrRaiseError()).asString())
        #else
        return UpdateBeamObjects(beamObjects: result, privateKey: nil)
        #endif
    }

    struct BeamObjectUploadParameters: Codable {
        let id: UUID
        let type: String
        let byteSize: Int
        let checksum: String
    }

    struct PrepareBeamObjectsUploadParameters: Codable {
        let beamObjectsMetadata: [BeamObjectUploadParameters]
    }

    struct PrepareBeamObjectUploadParameters: Codable {
        let beamObjectMetadata: BeamObjectUploadParameters
    }

    internal func prepareBeamObjectsParameters(_ beamObjects: [BeamObject]) throws -> PrepareBeamObjectsUploadParameters {
        let encryptedBeamObjects: [BeamObjectUploadParameters] = beamObjects.compactMap {
            guard let data = $0.data else { return nil }

            return BeamObjectUploadParameters(id: $0.id,
                                              type: $0.beamObjectType,
                                              byteSize: data.count,
                                              checksum: data.md5Base64)
        }

        return PrepareBeamObjectsUploadParameters(beamObjectsMetadata: encryptedBeamObjects)
    }

    internal func prepareBeamObjectParameters(_ beamObject: BeamObject) throws -> PrepareBeamObjectUploadParameters {
        guard let data = beamObject.data else { throw BeamObjectRequestError.noData }

        let parameter = BeamObjectUploadParameters(id: beamObject.id,
                                                   type: beamObject.beamObjectType,
                                                   byteSize: data.count,
                                                   checksum: data.md5Base64)

        return PrepareBeamObjectUploadParameters(beamObjectMetadata: parameter)
    }

    override func cancel() {
        super.cancel()

        if Configuration.env == .debug {
            Logger.shared.logWarning("Be careful cancelling BeamObject requests! Can't do that for writes...",
                                     category: .beamObjectNetwork)
        }
    }
}
