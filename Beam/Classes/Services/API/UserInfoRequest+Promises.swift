//
//  UserInfoRequest+Promises.swift
//  Beam
//
//  Created by Remi Santos on 13/12/2021.
//

import Foundation
import Promises

extension UserInfoRequest {
    func getUserInfos() -> Promise<UserInfos> {
        let bodyParamsRequest = GraphqlParameters(fileName: "user_infos", variables: EmptyVariable())
        let promise: Promises.Promise<UserInfos> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                  authenticatedCall: true)
        return promise
    }

    func setUsername(username: String) -> Promise<UpdateMe> {
        let variables = UpdateMeParameters(username: username)
        let bodyParamsRequest = GraphqlParameters(fileName: "set_username", variables: variables)
        let promise: Promises.Promise<UpdateMe> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                 authenticatedCall: true)
        return promise
    }
}
