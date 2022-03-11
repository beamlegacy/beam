import Foundation
import Quick
import Nimble

@testable import Beam
@testable import BeamCore

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

        let semaResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(15))

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

        let semaphore = DispatchSemaphore(value: 0)
        var returnedBeamObject: BeamObject?

        do {
            let beamObject = try BeamObject(object)
            beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(object: object)

            let beamObjectRequest = BeamObjectRequest()
            _ = try beamObjectRequest.save(beamObject) { result in
                expect { returnedBeamObject = try result.get() }.toNot(throwError())
                semaphore.signal()
            }

            try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)

        } catch {
            fail(error.localizedDescription)
            return nil
        }

        let timeout = 50
        let semaResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(timeout))

        if case .timedOut = semaResult {
            fail("Timedout after \(timeout)sec")
        }

        return returnedBeamObject
    }

    // This saves objects on the server side
    func saveOnAPIWithDirectUploadAndSaveChecksum<T: BeamObjectProtocol>(_ object: T) {
        let semaphore = DispatchSemaphore(value: 0)

        do {
            let beamObject = try BeamObject(object)
            try beamObject.encrypt()
            
            beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(object: object)

            var beamObjectRequest = BeamObjectRequest()

            _ = try beamObjectRequest.prepare(beamObject) { result in

                switch result {
                case .failure(let error):
                    fail(error.localizedDescription)
                    semaphore.signal()
                    return
                case .success(let beamObjectUpload):
                    do {
                        let decoder = JSONDecoder()
                        let headers: [String: String] = try decoder.decode([String: String].self,
                                                                           from: beamObjectUpload.uploadHeaders.asData)
                        beamObjectRequest = BeamObjectRequest()
                        try beamObjectRequest.sendDataToUrl(urlString: beamObjectUpload.uploadUrl,
                                                            putHeaders: headers,
                                                            data: beamObject.data!) { result in
                            switch result {
                            case .failure(let error):
                                fail(error.localizedDescription)
                                semaphore.signal()
                                return
                            case .success:
                                beamObject.largeDataBlobId = beamObjectUpload.blobSignedId
                                beamObject.data = nil
                                beamObjectRequest = BeamObjectRequest()

                                do {
                                    // This is fake, but server wants it
                                    beamObject.privateKeySignature = try EncryptionManager.shared.privateKey(for: EnvironmentVariables.Account.testEmail).asString().SHA256()

                                    try beamObjectRequest.save(beamObject) { result in
                                        switch result {
                                        case .failure(let error):
                                            fail(error.localizedDescription)
                                            semaphore.signal()
                                            return
                                        case .success:
                                            do {
                                                try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)
                                            } catch {
                                                fail(error.localizedDescription)
                                            }
                                            semaphore.signal()
                                        }
                                    }
                                } catch {
                                    fail(error.localizedDescription)
                                    semaphore.signal()
                                }
                            }

                        }
                    } catch {
                        fail(error.localizedDescription)
                        semaphore.signal()
                        return
                    }
                }
            }
        } catch {
            fail(error.localizedDescription)
            return
        }

        let semaResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(20))

        if case .timedOut = semaResult {
            fail("Timedout")
        }
    }

    func saveOnAPI<T: BeamObjectProtocol>(_ objects: [T]) -> [BeamObject] {
        saveOnAPIAndSaveChecksum(objects)
    }

    /// Save objects on the API, and store its checksum
    @discardableResult
    func saveOnAPIAndSaveChecksum<T: BeamObjectProtocol>(_ objects: [T]) -> [BeamObject] {
        let beamObjectRequest = BeamObjectRequest()

        let semaphore = DispatchSemaphore(value: 0)

        var beamObjects: [BeamObject]

        do {
            beamObjects = try objects.map { object in
                let beamObject = try BeamObject(object)
                beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(object: object)
                return beamObject
            }

            _ = try beamObjectRequest.save(beamObjects) { result in
                semaphore.signal()
            }

            try beamObjects.forEach { beamObject in
                try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)
            }
        } catch {
            fail(error.localizedDescription)
            return []
        }

        let semaResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))

        if case .timedOut = semaResult {
            fail("Timedout")
        }

        return beamObjects
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
    func deleteAll(beamObjectType: BeamObjectObjectType? = nil) {
        let semaphore = DispatchSemaphore(value: 0)

        _ = try? BeamObjectRequest().deleteAll(beamObjectType: beamObjectType) { _ in
            semaphore.signal()
        }

        let timeout = 15
        let semaResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(timeout))

        if case .timedOut = semaResult {
            fail("Timedout after \(timeout)secs")
        }
    }
}
