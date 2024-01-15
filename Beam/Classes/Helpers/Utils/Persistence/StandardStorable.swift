import Foundation

@propertyWrapper
struct StandardStorable<T> {
    let key: String
    private let store = UserDefaults(suiteName: Configuration.env.rawValue) ?? UserDefaults.standard

    init(_ key: String) {
        self.key = key
    }

    var wrappedValue: T? {
        get {
            switch T.self {
            case is UUID.Type:
                if let stringValue = store.object(forKey: key) as? String {
                    return UUID(uuidString: stringValue) as? T
                }

                return nil
            default:
                return store.object(forKey: key) as? T
            }
        }

        set {
            switch T.self {
            case is UUID.Type:
                guard let newValue = newValue else {
                    store.set(nil, forKey: key)
                    return
                }
                let stringValue: String? = (newValue as? UUID)?.uuidString

                store.set(stringValue, forKey: key)
            default:
                store.set(newValue, forKey: key)
            }
        }
    }

    static func clear() {
        let store = UserDefaults(suiteName: Configuration.env.rawValue) ?? UserDefaults.standard
        store.dictionaryRepresentation().keys.forEach { key in
            store.removeObject(forKey: key)
        }
    }
}
