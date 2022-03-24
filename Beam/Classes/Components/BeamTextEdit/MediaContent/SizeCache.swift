import Foundation
import BeamCore

final class SizeCache {

    let cache: Cache<UUID, CGSize>

    private let filename: String

    private lazy var debouncedSave: () -> Void = {
        debounce(delay: .seconds(5)) { [weak self] in
            self?.saveToDisk()
        }
    }()

    init(filename: String, countLimit: Int) {
        self.filename = filename
        cache = Cache.diskCache(filename: filename, countLimit: countLimit)
    }

    func save() {
        debouncedSave()
    }

    private func saveToDisk() {
        do {
            try cache.saveToDisk(withName: filename)
        } catch {
            Logger.shared.logError("SizeCache couldn't be saved to disk. \(error.localizedDescription)", category: .embed)
        }
    }

}
