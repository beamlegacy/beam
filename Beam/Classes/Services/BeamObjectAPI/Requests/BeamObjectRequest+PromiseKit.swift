import Foundation
import PromiseKit
import BeamCore

/*
 WARNING

 This has not been tested as much as the Foundation/callback handler code.
 */

extension BeamObjectRequest {
    // return multiple errors, as the API might return more than one.
    func save(_ beamObject: BeamObject) -> Promise<BeamObject> {
        let saveObject = beamObject.copy()
        var parameters: UpdateBeamObject
        do {
            parameters = try saveBeamObjectParameters(saveObject)
        } catch {
            return Promise(error: error)
        }
        let bodyParamsRequest = GraphqlParameters(fileName: "update_beam_object", variables: parameters)

        let promise: Promise<UpdateBeamObject> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                authenticatedCall: true)

        return promise.map(on: self.backgroundQueue) {
            guard let beamObject = $0.beamObject else {
                throw APIRequestError.parserError
            }

            beamObject.previousChecksum = beamObject.dataChecksum
            return beamObject
        }
    }

    func saveAll(_ beamObjects: [BeamObject]) -> Promise<[BeamObject]> {
        var parameters: UpdateBeamObjects

        let saveObjects: [BeamObject] = beamObjects.map {
            $0.copy()
        }

        do {
            parameters = try saveBeamObjectsParameters(saveObjects)
        } catch {
            return Promise(error: error)
        }

        let bodyParamsRequest = GraphqlParameters(fileName: "update_beam_objects", variables: parameters)

        let promise: Promise<UpdateBeamObjects> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                 authenticatedCall: true)

        return promise.map(on: self.backgroundQueue) {
            guard let beamObjects = $0.beamObjects else {
                throw APIRequestError.parserError
            }

            return beamObjects
        }
    }

    func delete(beamObject: BeamObject) -> Promise<BeamObject> {
        let parameters = BeamObjectIdParameters(id: beamObject.id,
                                                beamObjectType: beamObject.beamObjectType)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_beam_object", variables: parameters)

        let promise: Promise<DeleteBeamObject> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                authenticatedCall: true)

        return promise.map(on: self.backgroundQueue) {
            guard let beamObject = $0.beamObject else {
                throw APIRequestError.parserError
            }

            try? beamObject.decrypt()
            return beamObject
        }
    }

    func delete<T: BeamObjectProtocol>(object: T) -> Promise<BeamObject?> {
        let parameters = BeamObjectIdParameters(id: object.beamObjectId,
                                                beamObjectType: type(of: object).beamObjectType.rawValue)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_beam_object", variables: parameters)

        let promise: Promise<DeleteBeamObject> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                authenticatedCall: true)

        return promise.map(on: self.backgroundQueue) {
            guard let beamObject = $0.beamObject else {
                throw APIRequestError.parserError
            }

            try? beamObject.decrypt()
            return beamObject
        }
    }

    func deleteAll(beamObjectType: BeamObjectObjectType? = nil) -> Promise<Bool> {
        let parameters = DeleteAllBeamObjectsParameters(beamObjectType: beamObjectType?.rawValue)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_all_beam_objects", variables: parameters)

        let promise: Promise<DeleteAllBeamObjects> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                    authenticatedCall: true)

        return promise.map(on: self.backgroundQueue) {
            guard $0.success == true else {
                throw APIRequestError.parserError

            }

            return true
        }
    }

    func fetchAll(receivedAtAfter: Date? = nil,
                  ids: [UUID]? = nil,
                  beamObjectType: String? = nil) -> Promise<[BeamObject]> {
        let parameters = BeamObjectsParameters(receivedAtAfter: receivedAtAfter,
                                               ids: ids,
                                               beamObjectType: beamObjectType)

        return fetchAllWithFile("beam_objects", parameters)
    }

    private func fetchAllWithFile<T: Encodable>(_ filename: String,
                                                _ parameters: T) -> PromiseKit.Promise<[BeamObject]> {
        let bodyParamsRequest = GraphqlParameters(fileName: filename, variables: parameters)

        let promise: Promise<UserMe> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                      authenticatedCall: true)

        return promise.map(on: self.backgroundQueue) {
            guard let beamObjects = $0.beamObjects else {
                throw APIRequestError.parserError
            }

            /*
             When fetching all beam objects, we decrypt them if needed. We might have decryption issue
             like not having the key it was encrypted with. In such case we filter those out as the calling
             code wouldn't know what to do with it anyway.
             */
            return try beamObjects.compactMap {
                do {
                    try $0.decrypt()
                    try $0.setTimestamps()
                    return $0
                } catch EncryptionManagerError.authenticationFailure {
                    Logger.shared.logError("Can't decrypt \($0)", category: .beamObjectNetwork)
                }

                return nil
            }
        }
    }

    func fetch<T: BeamObjectProtocol>(object: T) -> Promise<BeamObject> {
        fetchWithFile(filename: "beam_object",
                      id: object.beamObjectId,
                      beamObjectType: type(of: object).beamObjectType.rawValue)
    }

    func fetch(beamObject: BeamObject) -> Promise<BeamObject> {
        fetchWithFile(filename: "beam_object", id: beamObject.id, beamObjectType: beamObject.beamObjectType)
    }

    func fetchMinimalBeamObject(beamObject: BeamObject) -> Promise<BeamObject> {
        fetchWithFile(filename: "beam_object_updated_at", id: beamObject.id, beamObjectType: beamObject.beamObjectType)
    }

    func fetchMinimalBeamObject<T: BeamObjectProtocol>(object: T) -> Promise<BeamObject> {
        fetchWithFile(filename: "beam_object_updated_at",
                      id: object.beamObjectId,
                      beamObjectType: type(of: object).beamObjectType.rawValue)
    }

    private func fetchWithFile(filename: String, id: UUID, beamObjectType: String) -> Promise<BeamObject> {
        let parameters = BeamObjectIdParameters(id: id, beamObjectType: beamObjectType)
        let bodyParamsRequest = GraphqlParameters(fileName: filename, variables: parameters)

        let promise: Promise<FetchBeamObject> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                               authenticatedCall: true)

        return promise.map(on: self.backgroundQueue) {
            try $0.decrypt()
            try $0.setTimestamps()
            return $0
        }
    }
}
