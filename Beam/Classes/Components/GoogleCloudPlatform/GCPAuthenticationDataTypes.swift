//
//  GCPDataTypes.swift
//  Beam
//
//  Created by Julien Plu on 09/03/2022.
//

import Foundation

struct GCPOauth2Payload: Codable {
    var access_token = ""
    var expires_in = 0
    var token_type = ""
}

struct GCPOauth2Error: Codable, CustomStringConvertible {
    var error = ""
    var error_description = ""

    var description: String {
        return """
        {
            "error": \(error),
            "error_description": \(error_description)
        }
        """
    }
}
