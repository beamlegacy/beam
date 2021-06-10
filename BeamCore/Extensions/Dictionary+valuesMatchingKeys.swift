//
//  Dictionary+valuesMatchingKeys.swift
//  BeamCore
//
//  Created by Sebastien Metrot on 19/04/2021.
//

import Foundation

public extension Dictionary {
    func valuesMatchingKeys(in keys: [Key]) -> [Value] {
        return keys.reduce([]) { (values, key) -> [Value] in
            if let value = self[key] {
                return values + [value]
            } else {
                return values
            }
        }
    }
}
