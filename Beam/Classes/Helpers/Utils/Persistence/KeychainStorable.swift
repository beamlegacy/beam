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
    private let store = Keychain(service: Configuration.bundleIdentifier).synchronizable(true)

    private class InternalValueCache {
        var hasSetValue = false
        var lastValue: T? {
            didSet { hasSetValue = true }
        }
    }
    private var cache = InternalValueCache()

    init(_ key: String, _ label: String? = nil, _ comment: String? = nil) {
        self.key = Configuration.env.rawValue + "." + key
        self.label = label
        self.comment = comment
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
                } else {
                    Logger.shared.logError("Can't store \(key) -> \(newValue.debugDescription)", category: .keychain)
                }
            } catch {
                Logger.shared.logError("Can't store \(key): \(error.localizedDescription)",
                                       category: .keychain)
            }
        }
    }
}
