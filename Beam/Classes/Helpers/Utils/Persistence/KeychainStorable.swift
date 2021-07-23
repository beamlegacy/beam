import Foundation
import KeychainAccess
import BeamCore

@propertyWrapper
struct KeychainStorable<T> {
    let key: String
    let label: String?
    let comment: String?
    private let store = Keychain(service: Configuration.bundleIdentifier).synchronizable(true)

    init(_ key: String, _ label: String? = nil, _ comment: String? = nil) {
        self.key = Configuration.env + "." + key
        self.label = label
        self.comment = comment
    }

    var wrappedValue: T? {
        get {
            if T.self == String.self {
                return store[key] as? T
            } else if T.self == Data.self {
                return store[data: key] as? T
            }
            return nil
        }
        set {
            do {
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
