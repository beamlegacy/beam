import Foundation

@propertyWrapper
struct StandardStorable<T> {
    let key: String
    private let store = UserDefaults.standard

    init(_ key: String) {
        self.key = key
    }

    var wrappedValue: T? {
        get {
            return store.object(forKey: key) as? T
        }
        set {
            store.set(newValue, forKey: key)
        }
    }
}
