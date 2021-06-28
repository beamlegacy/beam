import Foundation

public class BeamObjectManager {
}

// MARK: - Foundation
extension BeamObjectManager {
    func saveOnAPI(_ beamObject: Codable,
                   _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {

    }

    func deleteOnAPI(_ beamObject: Codable,
                     _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {

    }

    func fetchFromAPI(_ id: UUID,
                      _ completion: ((Swift.Result<Bool, Error>) -> Void)? = nil) {
    }
}
