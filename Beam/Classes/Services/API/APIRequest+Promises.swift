import Foundation
import os.log
import Promises
import BeamCore
import Vinyl

extension APIRequest {
    func performRequest<T: Decodable & Errorable, E: GraphqlParametersProtocol>(bodyParamsRequest: E,
                                                                                authenticatedCall: Bool? = nil) -> Promise<T> {
        wrap(on: backgroundQueue) { (handler: @escaping (Swift.Result<T, Error>) -> Void) in
            guard !self.cancelRequest else { throw APIRequestError.operationCancelled }
            try self.performRequest(bodyParamsRequest: bodyParamsRequest,
                                    authenticatedCall: authenticatedCall,
                                    completionHandler: handler)
        }.then(on: backgroundQueue) { result -> Promises.Promise<T> in
            return Promise(try result.get())
        }
    }
}
