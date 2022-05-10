//
//  UserInfoRequest+Foundation.swift
//  Beam
//
//  Created by Remi Santos on 13/12/2021.
//

import Foundation

extension UserInfoRequest {

    @discardableResult
    func getUserInfos() async throws -> UserInfos {

        let bodyParamsRequest = GraphqlParameters(fileName: "user_infos", variables: EmptyVariable())

        return try await performRequest(bodyParamsRequest: bodyParamsRequest, authenticatedCall: true)
    }

    @discardableResult
    func setUsername(username: String) async throws -> UpdateMe {

        let variables = UpdateMeParameters(username: username)

        let bodyParamsRequest = GraphqlParameters(fileName: "set_username", variables: variables)

        return try await performRequest(bodyParamsRequest: bodyParamsRequest)
    }

    @discardableResult
    func updatePassword(currentPassword: String,
                        newPassword: String) async throws -> UpdatePassword {
        let variables = UpdatePasswordParameters(currentPassword: currentPassword, newPassword: newPassword)

        let bodyParamsRequest = GraphqlParameters(fileName: "update_password", variables: variables)

        let result: UpdatePassword = try await performRequest(bodyParamsRequest: bodyParamsRequest, authenticatedCall: true)
        guard result.success == true else {
            throw UserSessionRequestError.updatePasswordFailed
        }
        return result
    }
}
