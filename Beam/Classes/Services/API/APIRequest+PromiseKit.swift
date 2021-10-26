import Foundation
import os.log
import PromiseKit
import PMKFoundation
import BeamCore
import Vinyl

extension APIRequest {
    /// Make a performRequest which can be cancelled later on calling the tuple
    func performRequest<T: Decodable & Errorable, E: GraphqlParametersProtocol>(bodyParamsRequest: E,
                                                                                authenticatedCall: Bool? = nil) -> Promise<T> {
        PromiseKit.Promise<T> { seal in
            do {
                guard !self.cancelRequest else { throw APIRequestError.operationCancelled }

                // I can't use the PromiseKit foundation data request as it doesn't return a task, and I can't
                // cancel it later
                try self.performRequest(bodyParamsRequest: bodyParamsRequest,
                                        authenticatedCall: authenticatedCall) { (result: Swift.Result<T, Error>) in
                    switch result {
                    case .failure(let error):
                        seal.reject(error)
                    case .success(let dataResult):
                        seal.fulfill(dataResult)
                    }
                }
            } catch {
                seal.reject(error)
            }
        }
    }
}
