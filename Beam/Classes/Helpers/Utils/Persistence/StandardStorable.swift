import Foundation

@propertyWrapper
struct StandardStorable<T> {
    let key: String
    private let store = UserDefaults(suiteName: Configuration.env) ?? UserDefaults.standard

    init(_ key: String) {
        self.key = key
    }

    var wrappedValue: T? {
        get {
            switch T.self {
            case is UUID.Type:
                if let unarchivedObject = store.object(forKey: key) as? Data {
                    return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(unarchivedObject) as? T
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
                let data: Data? = try? NSKeyedArchiver.archivedData(withRootObject: newValue,
                                                                    requiringSecureCoding: true)

                store.set(data, forKey: key)
            default:
                store.set(newValue, forKey: key)
            }
        }
    }

    static func clear() {
        let store = UserDefaults(suiteName: Configuration.env) ?? UserDefaults.standard
        store.dictionaryRepresentation().keys.forEach { key in
            store.removeObject(forKey: key)
        }
    }
}
