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
                _ provider: Provider) async throws -> CreateIdentity {
        let identity = IdentityType(provider: provider.rawValue, accessToken: accessToken)
        let parameters = IdentityParameters(identity: identity)
        let bodyParamsRequest = GraphqlParameters(fileName: "create_identity", variables: parameters)

        return try await performRequest(bodyParamsRequest: bodyParamsRequest)
    }

    func delete(_ id: String) async throws -> DeleteIdentity {
        let identity = IdentityType(id: id)
        let parameters = IdentityParameters(identity: identity)
        let bodyParamsRequest = GraphqlParameters(fileName: "delete_identity", variables: parameters)

        return try await performRequest(bodyParamsRequest: bodyParamsRequest)
    }

    func fetchAll() async throws -> UserMe {
        let bodyParamsRequest = GraphqlParameters(fileName: "identities", variables: EmptyVariable())

        return try await performRequest(bodyParamsRequest: bodyParamsRequest)
    }
}
