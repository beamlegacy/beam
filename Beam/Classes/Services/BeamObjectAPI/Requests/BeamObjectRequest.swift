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
        let privateKey: String?
        var errors: [UserErrorData]?

        init(beamObject: BeamObject?, privateKey: String?) {
            self.beamObject = beamObject
            self.privateKey = privateKey
        }
    }

    class DeleteBeamObject: UpdateBeamObject { }

    struct UpdateBeamObjects: Codable, Errorable {
        let beamObjects: [BeamObject]?
        let privateKey: String?
        var errors: [UserErrorData]?
    }

    struct BeamObjectsParameters: Encodable {
        let receivedAtAfter: Date?
        let ids: [UUID]?
        let beamObjectType: String?
    }

    internal func saveBeamObjectParameters(_ beamObject: BeamObject) throws -> UpdateBeamObject {
        try beamObject.encrypt()

        #if DEBUG
        return UpdateBeamObject(beamObject: beamObject, privateKey: EncryptionManager.shared.privateKey().asString())
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
        return UpdateBeamObjects(beamObjects: result, privateKey: EncryptionManager.shared.privateKey().asString())
        #else
        return UpdateBeamObjects(beamObjects: result, privateKey: nil)
        #endif
    }

    override func cancel() {
        super.cancel()

        if Configuration.env == "dev" {
            Logger.shared.logWarning("Be careful cancelling BeamObject requests! Can't do that for writes...",
                                     category: .beamObjectNetwork)
        }
    }
}
