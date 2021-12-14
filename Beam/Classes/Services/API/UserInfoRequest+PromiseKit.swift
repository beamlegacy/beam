//
//  UserInfoRequest+PromiseKit.swift
//  Beam
//
//  Created by Remi Santos on 13/12/2021.
//

import Foundation
import PromiseKit

extension UserInfoRequest {
    func getUserInfos() -> Promise<UserInfos> {
        let bodyParamsRequest = GraphqlParameters(fileName: "user_infos", variables: EmptyVariable())
        let promise: PromiseKit.Promise<UserInfos> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                    authenticatedCall: true)
        return promise
    }

    func setUsername(username: String) -> Promise<UpdateMe> {
        let variables = UpdateMeParameters(username: username)
        let bodyParamsRequest = GraphqlParameters(fileName: "set_username", variables: variables)
        let promise: PromiseKit.Promise<UpdateMe> = performRequest(bodyParamsRequest: bodyParamsRequest,
                                                                   authenticatedCall: true)
        return promise
    }
}
