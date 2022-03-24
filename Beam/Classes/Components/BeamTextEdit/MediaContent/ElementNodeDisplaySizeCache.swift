import Foundation

/// An object storing the display size of an element node. Used to display an element node with the right dimensions
/// before its content size properties are known.
final class ElementNodeDisplaySizeCache {

    var containsCachedDisplaySize: Bool {
        cache.cache[elementID] != nil
    }

    private let elementID: UUID
    private let cache: SizeCache

    init(elementID: UUID, cache: SizeCache? = nil) {
        self.elementID = elementID
        self.cache = cache ?? Self.cache
    }

    static let cache = SizeCache(filename: "ElementNodeDisplaySize", countLimit: 1000)

}

// MARK: - DisplaySizeCache

extension ElementNodeDisplaySizeCache: MediaContentDisplaySizeCache {

    var displaySize: CGSize? {
        get {
            cache.cache[elementID]
        }

        set {
            guard cache.cache[elementID] != newValue else { return }
            cache.cache[elementID] = newValue
            cache.save()
        }
    }

}
