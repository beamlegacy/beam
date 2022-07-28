import Foundation
import Quick
import Nimble

@testable import Beam
@testable import BeamCore

class BeamObjectTestsHelper {
    func fetchOnAPI(_ object: BeamObject) async -> BeamObject? {
        do {
            return try await BeamObjectRequest().fetch(beamObject: object)
        } catch {
            return nil
        }
    }

    func fetchOnAPI<T: BeamObjectProtocol>(_ object: T?) async throws -> T? {
        guard let object = object else { return nil }

        do {
            let object = try await BeamObjectRequest().fetch(object: object)
            return try object.decodeBeamObject()
        } catch {
            return nil
        }
    }

    func saveOnAPI<T: BeamObjectProtocol>(_ object: T) async -> BeamObject? {
        await saveOnAPIAndSaveChecksum(object)
    }

    /// Save objects on the API, and store its checksum
    @discardableResult
    func saveOnAPIAndSaveChecksum<T: BeamObjectProtocol>(_ object: T) async -> BeamObject? {
        do {
            let beamObject = try BeamObject(object)
            beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(object: object)

            let beamObjectRequest = BeamObjectRequest()
            let returnedBeamObject = try await beamObjectRequest.save(beamObject)
            try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)
            return returnedBeamObject
        } catch {
            fail(error.localizedDescription)
            return nil
        }

    }

    // This saves objects on the server side
    func saveOnAPIWithDirectUploadAndSaveChecksum<T: BeamObjectProtocol>(_ object: T) async {
        Logger.shared.logDebug("saveOnAPIWithDirectUploadAndSaveChecksum: starts", category: .beamObjectNetwork)

        do {
            let beamObject = try BeamObject(object)
            try beamObject.encrypt()
            
            beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(object: object)

            var beamObjectRequest = BeamObjectRequest()

            let beamObjectUpload = try await beamObjectRequest.prepare(beamObject)
            let decoder = JSONDecoder()
            let headers: [String: String] = try decoder.decode([String: String].self,
                                                               from: beamObjectUpload.uploadHeaders.asData)
            beamObjectRequest = BeamObjectRequest()
            let result = try await beamObjectRequest.sendDataToUrl(urlString: beamObjectUpload.uploadUrl,
                                                putHeaders: headers,
                                                data: beamObject.data!)
            guard result == true else {
                fail("Cannot send data to URL")
                return
            }
            beamObject.largeDataBlobId = beamObjectUpload.blobSignedId
            beamObject.data = nil
            beamObjectRequest = BeamObjectRequest()

            // This is fake, but server wants it
            beamObject.privateKeySignature = try EncryptionManager.shared.privateKey(for: EnvironmentVariables.Account.testEmail).asString().SHA256()

            try await beamObjectRequest.save(beamObject)
            try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)
        } catch {
            fail(error.localizedDescription)
            return
        }
    }

    func saveOnAPI<T: BeamObjectProtocol>(_ objects: [T]) async -> [BeamObject] {
        await saveOnAPIAndSaveChecksum(objects)
    }

    /// Save objects on the API, and store its checksum
    @discardableResult
    func saveOnAPIAndSaveChecksum<T: BeamObjectProtocol>(_ objects: [T]) async -> [BeamObject] {
        let beamObjectRequest = BeamObjectRequest()

        var beamObjects: [BeamObject]

        do {
            beamObjects = try objects.map { object in
                let beamObject = try BeamObject(object)
                beamObject.previousChecksum = BeamObjectChecksum.previousChecksum(object: object)
                return beamObject
            }

            _ = try await beamObjectRequest.save(beamObjects)

            try beamObjects.forEach { beamObject in
                try BeamObjectChecksum.savePreviousChecksum(beamObject: beamObject)
            }
        } catch {
            fail(error.localizedDescription)
            return []
        }

        return beamObjects
    }

    func delete<T: BeamObjectProtocol>(_ object: T) async {
        let request = BeamObjectRequest()
        do {
            _ = try await request.delete(object: object)
        } catch {
            fail("Cannot delete object")
        }
    }

    /// Delete all beam objects
    func deleteAll(beamObjectType: BeamObjectObjectType? = nil) async {
        do {
            _ = try await BeamObjectRequest().deleteAll(beamObjectType: beamObjectType)
        } catch {
            fail("Cannot delete object")
        }
    }
}
