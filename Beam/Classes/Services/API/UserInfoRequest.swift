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

    struct UpdateMeParameters: Encodable {
        let username: String
    }

    struct UpdateMe: Decodable, Errorable {
        let me: UserMe?
        let errors: [UserErrorData]?
    }

    struct UpdatePasswordParameters: Encodable {
        let currentPassword: String
        let newPassword: String
    }

    struct UpdatePassword: Decodable, Errorable {
        let success: Bool?
        let errors: [UserErrorData]?
    }

    struct DeleteAccount: Decodable, Errorable {
        let success: Bool
        let errors: [UserErrorData]?
    }
}
