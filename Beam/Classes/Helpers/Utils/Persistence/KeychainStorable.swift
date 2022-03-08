import Foundation
import KeychainAccess
import BeamCore

@propertyWrapper
struct KeychainStorable<T> {
    let key: String
    /// Looking into the keychain can be expensive, this reduces the unnecessary requests
    let useCache: Bool = true
    let label: String?
    let comment: String?
    private var store = Keychain(service: Configuration.bundleIdentifier)

    private class InternalValueCache {
        var hasSetValue = false
        var lastValue: T? {
            didSet { hasSetValue = true }
        }
    }
    private var cache = InternalValueCache()

    init(_ key: String, _ label: String? = nil, _ comment: String? = nil, synchronizable: Bool = true) {
        self.key = Configuration.env.rawValue + "." + key
        self.label = label
        self.comment = comment
        self.store = self.store.synchronizable(synchronizable)
    }

    var wrappedValue: T? {
        get {
            guard !useCache || !cache.hasSetValue else {
                return cache.lastValue
            }
            var value: T?
            if T.self == String.self {
                value = store[key] as? T
            } else if T.self == Data.self {
                value = store[data: key] as? T
            } else if T.self == Date.self {
                value = Formatter.iso8601withFractionalSeconds.date(from: key) as? T
            } else if T.self == [String: String].self {
                guard let storedValue = store[key] else { return nil }
                value = unserialize(str: storedValue) as? T
            }
            if useCache {
                cache.lastValue = value
            }
            return value
        }
        set {
            do {
                if useCache {
                    cache.lastValue = newValue
                }
                if newValue == nil {
                    try store.remove(key)
                    return
                }

                var storeWithLabelAndComment = store

                if let label = label {
                    storeWithLabelAndComment = store.label(label)
                }

                if let comment = comment {
                    storeWithLabelAndComment = store.comment(comment)
                }

                if let value = newValue as? String {
                    try storeWithLabelAndComment.set(value, key: key)
                } else if let value = newValue as? Data {
                    try storeWithLabelAndComment.set(value, key: key)
                } else if let value = newValue as? Date {
                    try storeWithLabelAndComment.set(value.iso8601withFractionalSeconds, key: key)
                } else if let dictValue = newValue as? [String: String],
                            let value = serialize(dict: dictValue) {
                    try storeWithLabelAndComment.set(value, key: key)
                } else {
                    Logger.shared.logError("Can't store \(key) -> \(newValue.debugDescription)", category: .keychain)
                    assert(false)
                }
            } catch {
                Logger.shared.logError("Can't store \(key): \(error.localizedDescription)",
                                       category: .keychain)
            }
        }
    }

    private func unserialize(str: String) -> [String: String]? {
        guard let data = str.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: String] else { return nil }
        return jsonArray
    }

    private func serialize(dict: [String: String]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
