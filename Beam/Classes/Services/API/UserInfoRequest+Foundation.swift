//
//  UserInfoRequest+Foundation.swift
//  Beam
//
//  Created by Remi Santos on 13/12/2021.
//

import Foundation

extension UserInfoRequest {

    @discardableResult
    func getUserInfos(completionHandler: @escaping (Result<UserInfos, Error>) -> Void) throws -> URLSessionDataTask {

        let bodyParamsRequest = GraphqlParameters(fileName: "user_infos", variables: EmptyVariable())

        return try performRequest(bodyParamsRequest: bodyParamsRequest, authenticatedCall: true, completionHandler: { (result: Result<UserInfos, Error>) in
            completionHandler(result)
        })
    }

    @discardableResult
    func setUsername(username: String,
                     completionHandler: @escaping (Result<UpdateMe, Error>) -> Void) throws -> URLSessionDataTask {

        let variables = UpdateMeParameters(username: username)

        let bodyParamsRequest = GraphqlParameters(fileName: "set_username", variables: variables)

        return try performRequest(bodyParamsRequest: bodyParamsRequest) { (result: Result<UpdateMe, Error>) in
            completionHandler(result)
        }
    }
}
