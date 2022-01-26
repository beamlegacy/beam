import Foundation
import Quick
import Nimble

@testable import Beam

class BeamObjectTestsHelper {
    func fetchOnAPI(_ object: BeamObject) -> BeamObject? {
        let beamObjectRequest = BeamObjectRequest()
        var beamObject: BeamObject?

        let semaphore = DispatchSemaphore(value: 0)

        _ = try? beamObjectRequest.fetch(beamObject: object) { result in
            beamObject = try? result.get()
            semaphore.signal()
        }

        let semaResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))

        if case .timedOut = semaResult {
            fail("Timedout")
        }

        return beamObject
    }

    func fetchOnAPI<T: BeamObjectProtocol>(_ object: T?) throws -> T? {
        guard let object = object else { return nil }
    
        let beamObjectRequest = BeamObjectRequest()
        var beamObject: BeamObject?

        let semaphore = DispatchSemaphore(value: 0)

        _ = try? beamObjectRequest.fetch(object: object) { result in
            beamObject = try? result.get()
            semaphore.signal()
        }

        let semaResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))

        if case .timedOut = semaResult {
            fail("Timedout")
        }

        return try beamObject?.decodeBeamObject()
    }

    func saveOnAPI<T: BeamObjectProtocol>(_ object: T) -> BeamObject? {
        saveOnAPIAndSaveChecksum(object)
    }

    /// Save objects on the API, and store its checksum
    @discardableResult
    func saveOnAPIAndSaveChecksum<T: BeamObjectProtocol>(_ object: T) -> BeamObject? {
        let beamObjectRequest = BeamObjectRequest()

        let semaphore = DispatchSemaphore(value: 0)
        var returnedBeamObject: BeamObject?

        do {
            let beamObject = try BeamObject(object)
            beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(object: object)
            _ = try beamObjectRequest.save(beamObject) { result in
                expect { returnedBeamObject = try result.get() }.toNot(throwError())
                semaphore.signal()
            }
            try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)

        } catch {
            fail(error.localizedDescription)
            return nil
        }

        let semaResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))

        if case .timedOut = semaResult {
            fail("Timedout")
        }

        return returnedBeamObject
    }

    func delete<T: BeamObjectProtocol>(_ object: T) {
        let semaphore = DispatchSemaphore(value: 0)

        let request = BeamObjectRequest()
        _ = try? request.delete(object: object) { _ in
            semaphore.signal()
        }

        let semaResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))
        if case .timedOut = semaResult {
            fail("Timedout")
        }
    }

    /// Delete all beam objects
    func deleteAll() {
        let semaphore = DispatchSemaphore(value: 0)

        _ = try? BeamObjectRequest().deleteAll { _ in
            semaphore.signal()
        }

        let semaResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))

        if case .timedOut = semaResult {
            fail("Timedout")
        }
    }
}
