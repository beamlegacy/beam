import Foundation
import Quick
import Nimble

@testable import Beam

class BeamObjectTestsHelper {
    func fetchOnAPI(_ objectID: UUID) -> BeamObject? {
        let beamObjectRequest = BeamObjectRequest()
        var beamObject: BeamObject?

        let semaphore = DispatchSemaphore(value: 0)

        _ = try? beamObjectRequest.fetch(objectID) { result in
            beamObject = try? result.get()
            semaphore.signal()
        }

        let semaResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))

        if case .timedOut = semaResult {
            fail("Timedout")
        }

        return beamObject
    }

    func fetchOnAPI<T: BeamObjectProtocol>(_ objectID: UUID) throws -> T? {
        let beamObjectRequest = BeamObjectRequest()
        var beamObject: BeamObject?

        let semaphore = DispatchSemaphore(value: 0)

        _ = try? beamObjectRequest.fetch(objectID) { result in
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
        let beamObjectRequest = BeamObjectRequest()

        let semaphore = DispatchSemaphore(value: 0)
        var returnedBeamObject: BeamObject?

        do {
            let beamObject = try BeamObject(object, T.beamObjectTypeName)
            _ = try beamObjectRequest.save(beamObject) { result in
                expect { returnedBeamObject = try result.get() }.toNot(throwError())
                semaphore.signal()
            }
        } catch {
            fail(error.localizedDescription)
            return nil
        }

        let semaResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(50))

        if case .timedOut = semaResult {
            fail("Timedout")
        }

        return returnedBeamObject
    }
}
