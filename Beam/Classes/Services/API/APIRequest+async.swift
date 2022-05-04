import Foundation
import BeamCore

// APRequest+async functions are wrapper of foundation closure based functions
// because URLSession async is only available on MacOS >= 12

extension APIRequest {

    // GraphQL
    func performRequest<T: Decodable & Errorable, E: GraphqlParametersProtocol>(bodyParamsRequest: E,
                                                                                authenticatedCall: Bool? = nil) async throws -> T {
        try await withTaskCancellationHandler {
            self.cancel()
        } operation: {
            try await withCheckedThrowingContinuation { continuation in
                do {
                    try self.performRequest(bodyParamsRequest: bodyParamsRequest,
                                            authenticatedCall: authenticatedCall) { (result: Swift.Result<T, Error>) in
                        switch result {
                        case .failure(let error):
                            return continuation.resume(throwing: error)
                        case .success(let res):
                            continuation.resume(returning: res)
                        }
                    }
                } catch {
                    return continuation.resume(throwing: error)
                }
            }
        }
    }

    // REST
    func performRestRequest<T: Decodable & Errorable, C: Codable>(path: BeamAPIRestPath,
                                                                  httpMethod: APIRequestMethod = .post,
                                                                  queryParams: [[String: String]]? = nil,
                                                                  postParams: C? = nil,
                                                                  authenticatedCall: Bool? = nil) async throws -> T {
        try await withTaskCancellationHandler {
            self.cancel()
        } operation: {
            try await withCheckedThrowingContinuation { continuation in
                do {
                    try self.performRestRequest(path: path,
                                                httpMethod: httpMethod,
                                                queryParams: queryParams,
                                                postParams: postParams,
                                                authenticatedCall: authenticatedCall) { (result: Swift.Result<T, Error>) in
                        switch result {
                        case .failure(let error):
                            return continuation.resume(throwing: error)
                        case .success(let res):
                            continuation.resume(returning: res)
                        }
                    }
                } catch {
                    return continuation.resume(throwing: error)
                }
            }
        }
    }
}
