import Foundation
import PromiseKit
import BeamCore

extension BeamObjectRequest {
    @discardableResult
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
            if let beamObject = $0.beamObject {
                beamObject.previousChecksum = beamObject.dataChecksum
                return beamObject
            }

            throw APIRequestError.parserError
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
            if let beamObjects = $0.beamObjects {
                return beamObjects
            }

            throw APIRequestError.parserError
        }
    }

    func delete(_ id: UUID) -> Promise<BeamObject> {
        let parameters = BeamObjectIdParameters(id: id)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_beam_object", variables: parameters)

        let promise: Promise<DeleteBeamObject> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                authenticatedCall: true)

        return promise.map(on: self.backgroundQueue) {
            if let beamObject = $0.beamObject {
                try? beamObject.decrypt()
                return beamObject
            }

            throw APIRequestError.parserError
        }
    }

    func deleteAll(beamObjectType: String? = nil) -> Promise<Bool> {
        let parameters = DeleteAllBeamObjectsParameters(beamObjectType: beamObjectType)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_all_beam_objects", variables: parameters)

        let promise: Promise<DeleteAllBeamObjects> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                    authenticatedCall: true)

        return promise.map(on: self.backgroundQueue) {
            if $0.success == true {
                return true
            }

            throw APIRequestError.parserError
        }
    }

    func fetchAll(receivedAtAfter: Date? = nil,
                  ids: [UUID]? = nil) -> Promise<[BeamObject]> {
        let parameters = BeamObjectsParameters(receivedAtAfter: receivedAtAfter, ids: ids)

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
                    return $0
                } catch EncryptionManagerError.authenticationFailure {
                    Logger.shared.logError("Can't decrypt \($0)", category: .beamObjectNetwork)
                }

                return nil
            }
        }
    }

    func fetch(_ beamObjectID: UUID) -> Promise<BeamObject> {
        fetchWithFile("beam_object", beamObjectID)
    }

    func fetchMinimalBeamObject(_ beamObjectID: UUID) -> Promise<BeamObject> {
        fetchWithFile("beam_object_updated_at", beamObjectID)
    }

    private func fetchWithFile(_ filename: String,
                               _ beamObjectID: UUID) -> Promise<BeamObject> {
        let parameters = BeamObjectIdParameters(id: beamObjectID)
        let bodyParamsRequest = GraphqlParameters(fileName: filename, variables: parameters)

        let promise: Promise<FetchBeamObject> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                               authenticatedCall: true)

        return promise.map(on: self.backgroundQueue) {
            try $0.decrypt()
            return $0
        }
    }
}
