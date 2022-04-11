import Foundation
import Promises

enum IdentityRequestError: Error, Equatable {
    case parserError
}

class IdentityRequest: APIRequest {
    struct IdentityParameters: Encodable {
        let identity: IdentityType
    }

    class CreateIdentity: Decodable, Errorable {
        let identity: IdentityType?
        let errors: [UserErrorData]?
    }

    class DeleteIdentity: CreateIdentity { }

    enum Provider: String {
        case google
        case github
    }
}

// MARK: Foundation
extension IdentityRequest {
    @discardableResult
    func create(_ accessToken: String,
                _ provider: Provider,
                _ completion: @escaping (Swift.Result<CreateIdentity, Error>) -> Void) throws -> URLSessionDataTask {
        let identity = IdentityType(provider: provider.rawValue, accessToken: accessToken)
        let parameters = IdentityParameters(identity: identity)
        let bodyParamsRequest = GraphqlParameters(fileName: "create_identity", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completion)
    }

    @discardableResult
    func delete(_ id: String,
                _ completion: @escaping (Swift.Result<DeleteIdentity, Error>) -> Void) throws -> URLSessionDataTask {
        let identity = IdentityType(id: id)
        let parameters = IdentityParameters(identity: identity)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_identity", variables: parameters)

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completion)
    }

    @discardableResult
    func fetchAll(_ completion: @escaping (Swift.Result<UserMe, Error>) -> Void) throws -> URLSessionDataTask {
        let bodyParamsRequest = GraphqlParameters(fileName: "identities", variables: EmptyVariable())

        return try performRequest(bodyParamsRequest: bodyParamsRequest, completionHandler: completion)
    }
}

// MARK: Promises
extension IdentityRequest {
    func create(_ accessToken: String,
                _ provider: Provider) -> Promises.Promise<CreateIdentity> {
        let identity = IdentityType(provider: provider.rawValue, accessToken: accessToken)
        let parameters = IdentityParameters(identity: identity)
        let bodyParamsRequest = GraphqlParameters(fileName: "create_identity", variables: parameters)

        let promise: Promises.Promise<CreateIdentity> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                       authenticatedCall: true)

        return promise
    }

    func delete(_ id: String) -> Promises.Promise<DeleteIdentity> {
        let identity = IdentityType(id: id)
        let parameters = IdentityParameters(identity: identity)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_identity", variables: parameters)

        let promise: Promises.Promise<DeleteIdentity> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                         authenticatedCall: true)

        return promise
    }

    func fetchAll() -> Promises.Promise<[IdentityType]> {
        let bodyParamsRequest = GraphqlParameters(fileName: "identities", variables: EmptyVariable())

        let promise: Promises.Promise<UserMe> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                           authenticatedCall: true)

        return promise.then(on: backgroundQueue) { me in
            guard let identities = me.identities else {
                throw IdentityRequestError.parserError
            }

            return Promise(identities)
        }
    }
}
