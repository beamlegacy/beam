//
//  UserInfoRequest.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 21/09/2021.
//

import Foundation

class UserInfoRequest: APIRequest {
    override init() {
        super.init()
        authenticatedAPICall = true
    }

    struct UserInfos: Decodable, Errorable, APIResponseCodingKeyProtocol {
        static let codingKey = "me"
        let username: String?
        let errors: [UserErrorData]?
    }
}

extension UserInfoRequest {

    @discardableResult
    func getUserInfos(completionHandler: @escaping (Result<UserInfos, Error>) -> Void) throws -> URLSessionDataTask {

        let bodyParamsRequest = GraphqlParameters(fileName: "user_infos", variables: EmptyVariable())

        return try performRequest(bodyParamsRequest: bodyParamsRequest, authenticatedCall: true, completionHandler: { (result: Result<UserInfos, Error>) in
            completionHandler(result)
        })
    }
}
