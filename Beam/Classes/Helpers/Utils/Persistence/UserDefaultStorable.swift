//
//  UserDefaultStorable.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 13/07/2021.
//

import Foundation
import Combine

@propertyWrapper
struct UserDefault<Value> {
    let key: String
    let defaultValue: Value
    var suiteName: String?
    var container: UserDefaults?
    private let publisher = PassthroughSubject<Value, Never>()

    init(key: String, defaultValue: Value, suiteName: String? = nil) {
        self.key = key
        self.defaultValue = defaultValue
        self.suiteName = suiteName ?? Configuration.env
        container = UserDefaults(suiteName: self.suiteName)
    }

    var wrappedValue: Value {
        get {
            return container?.object(forKey: key) as? Value ?? defaultValue
        }
        set {
            if case Optional<Any>.none = newValue as Any {
                container?.removeObject(forKey: key)
                } else {
                    container?.set(newValue, forKey: key)
                }
            publisher.send(newValue)
        }
    }

    var projectedValue: AnyPublisher<Value, Never> {
        return publisher.eraseToAnyPublisher()
    }
}
