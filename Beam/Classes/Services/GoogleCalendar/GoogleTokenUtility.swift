//
//  GoogleTokenUtility.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 21/12/2021.
//

import Foundation

class GoogleTokenUtility {
    static func objectifyOauth(str: String) -> [String: String]? {
        guard let data = str.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: String] else { return nil }
        return jsonArray
    }

    static func stringifyOauth(dict: [String: String]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
