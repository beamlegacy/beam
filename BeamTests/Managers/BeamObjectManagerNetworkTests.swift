import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam
@testable import BeamCore

class BeamObjectManagerNetworkTests: QuickSpec {
    static let networkTimeout = 30

    override func spec() {
        var sut: BeamObjectManager!
        let beamObjectHelper = BeamObjectTestsHelper()
        let beamHelper = BeamTestsHelper()

        beforeEach {
            MyRemoteObjectManager.receivedMyRemoteObjects = []
            Configuration.networkEnabled = true
            // Need to freeze date to compare objects, as `createdAt` would be different from the network stubs we get
            // back from Vinyl
            BeamDate.freeze("2021-03-19T12:21:03Z")

            APIRequest.networkCallFiles = []

            sut = BeamObjectManager()
            BeamTestsHelper.logout()

            beamHelper.beginNetworkRecording()

            BeamObjectManager.disableSendingObjects = false
            BeamTestsHelper.login()

            BeamObjectManager.unregisterAll()
            MyRemoteObjectManager().registerOnBeamObjectManager()

            MyRemoteObjectManager.store.removeAll()

            Configuration.beamObjectDirectCall = false
            Configuration.beamObjectOnRest = false

            try? BeamObjectChecksum.deleteAll()
            try? EncryptionManager.shared.replacePrivateKey(for: Configuration.testAccountEmail, with: Configuration.testPrivateKey)
//            try? EncryptionManager.shared.replacePrivateKey(Configuration.testPrivateKey)
        }

        afterEach {
            beamHelper.endNetworkRecording()

            BeamDate.reset()
            // Sad: this is broken when using Vinyl
//            if !sut.isAllNetworkCallsCompleted() {
//                fail("not all network calls are completed")
//            }
            MyRemoteObjectManager.receivedMyRemoteObjects = []
        }

        describe("fetchAllFromAPI()") {
            let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd58".uuid ?? UUID()
            let title = "my title"
            var object: MyRemoteObject!

            beforeEach {
                object = MyRemoteObject(beamObjectId: uuid,
                                            createdAt: BeamDate.now,
                                            updatedAt: BeamDate.now,
                                            deletedAt: nil,
                                            title: title)

                _ = beamObjectHelper.saveOnAPI(object)
            }

            afterEach {
                let semaphore = DispatchSemaphore(value: 0)
                _ = try? sut.delete(object: object) { _ in
                    semaphore.signal()
                }

                let semaResult = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))
                if case .timedOut = semaResult {
                    fail("Timedout")
                }
            }

            context("without last_received_at") {
                beforeEach {
                    Persistence.Sync.BeamObjects.last_received_at = nil
                    try? BeamObjectChecksum.deletePreviousChecksums(type: .myRemoteObject)
                }

                it("fetches all objects") {
                    var networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                        do {
                            try sut.fetchAllFromAPI { result in
                                done()
                            }
                        } catch {
                            fail(error.localizedDescription)
                            done()
                        }
                    }

                    expect(APIRequest.callsCount - networkCalls) == 1
                    expect(Persistence.Sync.BeamObjects.last_received_at).toNot(beNil())

                    expect(MyRemoteObjectManager.receivedMyRemoteObjects).to(haveCount(1))
                    expect(MyRemoteObjectManager.receivedMyRemoteObjects.first) == object
                }
            }
        }

        context("fetchAllFromAPI() with paginated checksum queries") {
            let uuid1 = "115d94e1-e0df-4eca-93e6-7778984bcd58".uuid ?? UUID()
            let uuid2 = "115d84e1-efdf-4eca-93e6-7778984bcd58".uuid ?? UUID()
            let title1 = "my title - 1"
            let title2 = "my title - 2"
            var object1: MyRemoteObject!
            var object2: MyRemoteObject!
            let checksumsChunkSize = Configuration.checksumsChunkSize

            beforeEach {
                Configuration.setChecksumsChunkSize(1)
                object1 = MyRemoteObject(beamObjectId: uuid1,
                                            createdAt: BeamDate.now,
                                            updatedAt: BeamDate.now,
                                            deletedAt: nil,
                                            title: title1)
                object2 = MyRemoteObject(beamObjectId: uuid2,
                                            createdAt: BeamDate.now,
                                            updatedAt: BeamDate.now,
                                            deletedAt: nil,
                                            title: title2)

                _ = beamObjectHelper.saveOnAPI(object1)
                _ = beamObjectHelper.saveOnAPI(object2)

                Persistence.Sync.BeamObjects.last_received_at = nil
                try? BeamObjectChecksum.deletePreviousChecksums(type: .myRemoteObject)
            }

            afterEach {
                let semaphore = DispatchSemaphore(value: 0)
                _ = try? sut.delete(object: object1) { _ in
                    semaphore.signal()
                }

                _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))

                _ = try? sut.delete(object: object2) { _ in
                    semaphore.signal()
                }

                _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))
                Configuration.setChecksumsChunkSize(checksumsChunkSize)
            }

            it("fetches all objects") {
                waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                    do {
                        try sut.fetchAllFromAPI { result in
                            done()
                        }
                    } catch {
                        fail(error.localizedDescription)
                        done()
                    }
                }

                expect(Persistence.Sync.BeamObjects.last_received_at).toNot(beNil())
                expect(MyRemoteObjectManager.receivedMyRemoteObjects).to(haveCount(2))
            }
        }


        describe("saveAllToAPI()") {
            afterEach {
                let semaphore = DispatchSemaphore(value: 0)

                _ = try? BeamObjectRequest().deleteAll { _ in
                    semaphore.signal()
                }

                _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))
            }

            context("without content") {
                asyncIt("calls managers but no network calls as it's all empty") {
                    let networkCalls = APIRequest.callsCount

                    do {
                        try sut.saveAllToAPI()
                    } catch {
                        fail(error.localizedDescription)
                    }

                    expect(APIRequest.callsCount - networkCalls) == 0

                    do {
                        try await sut.asyncSaveAllToAPI()
                    } catch {
                        fail(error.localizedDescription)
                    }

                    expect(APIRequest.callsCount - networkCalls) == 0
                }
            }
        }

        describe("delete()") {
            let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd18".uuid ?? UUID()
            let title = "my title"
            context("with Foundation") {
                let object = MyRemoteObject(beamObjectId: uuid,
                                            createdAt: BeamDate.now,
                                            updatedAt: BeamDate.now,
                                            deletedAt: nil,
                                            title: title)
                context("with non-existing object") {
                    it("returns 404") {
                        waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                            do {
                                try sut.delete(object: object, raise404: true) { result in
                                    expect { try result.get() }.to(throwError { (error: APIRequestError) in
                                        expect(error).to(matchError(APIRequestError.notFound))
                                    })
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                                done()
                            }
                        }
                    }
                }

                context("with existing object") {
                    beforeEach {
                        _ = beamObjectHelper.saveOnAPI(object)
                    }

                    it("returns object") {
                        var beamObject: BeamObject?
                        waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                            do {
                                try sut.delete(object: object) { result in
                                    expect { beamObject = try result.get() }.toNot(throwError())

                                    expect(beamObject?.id) == uuid
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                                done()
                            }
                        }
                    }
                }
            }

            context("with async") {
                let object = MyRemoteObject(beamObjectId: uuid,
                                            createdAt: BeamDate.now,
                                            updatedAt: BeamDate.now,
                                            deletedAt: nil,
                                            title: title)
                context("with non-existing object") {
                    asyncIt("returns 404") {
                        do {
                            try await sut.delete(object: object, raise404: true)
                        } catch {
                            expect(error).to(matchError(APIRequestError.notFound))
                        }
                    }
                }

                context("with existing object") {
                    beforeEach {
                        _ = beamObjectHelper.saveOnAPI(object)
                    }

                    asyncIt("returns object") {
                        do {
                            let beamObject = try await sut.delete(object: object)
                            expect(beamObject?.id) == uuid
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }
            }
         }

        describe("saveToAPI(beamObjects)") {
            var object: MyRemoteObject!
            var object2: MyRemoteObject!
            var objects: [MyRemoteObject] = []
            let title = "This is my title"
            let title2 = "This is my other title"
            let newTitle = "This is a new title"
            let newTitle2 = "This is a new title for other title"
            let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd38".uuid!
            let uuid2 = "995d94e1-e0df-4eca-93e6-8778984bcd39".uuid!

            beforeEach {
                Configuration.beamObjectOnRest = false

                object = MyRemoteObject(beamObjectId: uuid,
                                        createdAt: BeamDate.now,
                                        updatedAt: BeamDate.now,
                                        deletedAt: nil,
                                        title: title)
                object2 = MyRemoteObject(beamObjectId: uuid2,
                                        createdAt: BeamDate.now,
                                        updatedAt: BeamDate.now,
                                        deletedAt: nil,
                                        title: title2)
                objects.append(object)
            }

            afterEach {
                let semaphore = DispatchSemaphore(value: 0)
                _ = try? sut.delete(object: object) { _ in
                    semaphore.signal()
                }

                _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))

                _ = try? sut.delete(object: object2) { _ in
                    semaphore.signal()
                }

                _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))
            }

            context("with Foundation") {
                context("with new object") {
                    it("saves new object") {
                        let networkCalls = APIRequest.callsCount

                        let objects: [MyRemoteObject] = [object, object2]

                        var returnedObjects: [MyRemoteObject] = []

                        waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                            do {
                                _ = try sut.saveToAPI(objects) { result in
                                    expect { returnedObjects = try result.get() }.toNot(throwError())
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        expect(object) == (try beamObjectHelper.fetchOnAPI(object))
                        expect(object2) == (try beamObjectHelper.fetchOnAPI(object2))

                        // `previousChecksum` should be set on returned objects
                        let beamObject = try BeamObject(object)
                        expect(returnedObjects.first?.previousChecksum) == beamObject.dataChecksum

                        let beamObject2 = try BeamObject(object2)
                        expect(returnedObjects.last?.previousChecksum) == beamObject2.dataChecksum
                    }

                    it("saves new beam object") {
                        let networkCalls = APIRequest.callsCount

                        let beamObjects: [BeamObject] = [try BeamObject(object),  try BeamObject(object2)]

                        waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                            do {
                                _ = try sut.saveToAPI(beamObjects) { result in
                                    expect { try result.get() }.toNot(throwError())
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        expect(object) == (try beamObjectHelper.fetchOnAPI(object))
                        expect(object2) == (try beamObjectHelper.fetchOnAPI(object2))
                    }
                }

                context("with persisted object") {
                    beforeEach {
                        beamObjectHelper.saveOnAPIAndSaveChecksum(object)
                        beamObjectHelper.saveOnAPIAndSaveChecksum(object2)
                    }

                    context("with good previousChecksum") {
                        it("saves existing object") {
                            let networkCalls = APIRequest.callsCount
                            object.title = newTitle
                            object2.title = newTitle2

                            let objects: [MyRemoteObject] = [object, object2]
                            var returnedObjects: [MyRemoteObject] = []

                            waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                do {
                                    _ = try sut.saveToAPI(objects) { result in
                                        expect { returnedObjects = try result.get() }.toNot(throwError())
                                        done()
                                    }
                                } catch {
                                    fail(error.localizedDescription)
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 1

                            expect(object) == (try beamObjectHelper.fetchOnAPI(object))
                            expect(object2) == (try beamObjectHelper.fetchOnAPI(object2))

                            let beamObject = try? BeamObject(object)
                            expect(returnedObjects.first?.previousChecksum) == beamObject?.dataChecksum

                            let beamObject2 = try? BeamObject(object2)
                            expect(returnedObjects.last?.previousChecksum) == beamObject2?.dataChecksum
                        }

                        it("saves existing beam object") {
                            let networkCalls = APIRequest.callsCount
                            object.title = newTitle
                            object2.title = newTitle2

                            let beamObject = try BeamObject(object)
                            let beamObject2 = try BeamObject(object2)
                            let beamObjects: [BeamObject] = [beamObject, beamObject2]

                            waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                do {
                                    _ = try sut.saveToAPI(beamObjects) { result in
                                        expect { try result.get() }.toNot(throwError())
                                        done()
                                    }
                                } catch {
                                    fail(error.localizedDescription)
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 1

                            expect(object) == (try beamObjectHelper.fetchOnAPI(object))
                            expect(object2) == (try beamObjectHelper.fetchOnAPI(object2))
                        }
                    }

                    context("with empty previousChecksum") {
                        beforeEach {
                            try? BeamObjectChecksum.deletePreviousChecksum(object: object)
                            try? BeamObjectChecksum.deletePreviousChecksum(object: object2)
                        }

                        context("with automatic conflict management") {
                            beforeEach {
                                BeamDate.travel(2)

                                object.title = newTitle
                                object2.title = newTitle2
                                object.updatedAt = BeamDate.now
                                object2.updatedAt = BeamDate.now
                            }

                            it("updates object") {
                                let networkCalls = APIRequest.callsCount

                                let objects: [MyRemoteObject] = [object, object2]
                                var returnedObjects: [MyRemoteObject] = []

                                waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                    do {
                                        _ = try sut.saveToAPI(objects) { result in
                                            expect { returnedObjects = try result.get() }.toNot(throwError())
                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                let expectedNetworkCalls = ["update_beam_objects",
                                                            Beam.Configuration.beamObjectDataOnSeparateCall ? "paginated_beam_objects_data_url" : "paginated_beam_objects",
                                                            "update_beam_objects"]

                                expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                expect(object) == (try beamObjectHelper.fetchOnAPI(object))
                                expect(object2) == (try beamObjectHelper.fetchOnAPI(object2))

                                let remoteObject = returnedObjects.first(where: { $0.beamObjectId == object.beamObjectId })
                                let remoteObject2 = returnedObjects.first(where: { $0.beamObjectId == object2.beamObjectId })

                                // `previousChecksum` should be set on returned objects
                                let beamObject = try BeamObject(object)
                                let beamObject2 = try BeamObject(object2)

                                expect(remoteObject?.previousChecksum) == beamObject.dataChecksum
                                expect(remoteObject2?.previousChecksum) == beamObject2.dataChecksum
                            }

                            it("updates object") {
                                expect(BeamObjectChecksum.previousChecksum(object: object)).to(beNil())
                                expect(BeamObjectChecksum.previousChecksum(object: object2)).to(beNil())

                                let networkCalls = APIRequest.callsCount

                                let beamObjects: [BeamObject] = [try BeamObject(object),
                                                                 try BeamObject(object2)]

                                waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObjects) { result in
                                            expect { try result.get() }.toNot(throwError())
                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 3

                                let remoteBeamObject = try beamObjectHelper.fetchOnAPI(object)
                                let remoteBeamObject2 = try beamObjectHelper.fetchOnAPI(object2)

                                expect(object) == remoteBeamObject
                                expect(object2) == remoteBeamObject2

                                expect(try BeamObject(object).dataChecksum) == BeamObjectChecksum.previousChecksum(object: object)
                                expect(try BeamObject(object2).dataChecksum) == BeamObjectChecksum.previousChecksum(object: object2)
                            }
                        }

                        context("with manual conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .fetchRemoteAndError }

                            it("raise error and return remote object") {
                                let networkCalls = APIRequest.callsCount

                                object.title = newTitle
                                object2.title = newTitle2

                                let beamObjects: [MyRemoteObject] = [object, object2]

                                waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObjects) { result in
                                            expect { try result.get() }.to(throwError { (error: BeamObjectManagerObjectError<MyRemoteObject>) in
                                                switch error {
                                                case .invalidChecksum(_, _, let remoteObjects):
                                                    expect(remoteObjects).to(haveCount(2))
                                                }
                                            })

                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                let expectedNetworkCalls = ["update_beam_objects",
                                                            Beam.Configuration.beamObjectDataOnSeparateCall ? "paginated_beam_objects_data_url" : "paginated_beam_objects"]

                                expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                let remoteObject = (try beamObjectHelper.fetchOnAPI(object))!
                                let remoteObject2 = (try beamObjectHelper.fetchOnAPI(object2))!

                                expect(remoteObject) != object
                                expect(remoteObject2) != object2

                                expect(remoteObject.beamObjectId) == object.beamObjectId
                                expect(remoteObject.title) == title

                                expect(remoteObject2.beamObjectId) == object2.beamObjectId
                                expect(remoteObject2.title) == title2
                            }

                            it("raise error and return remote beam object") {
                                let networkCalls = APIRequest.callsCount

                                object.title = newTitle
                                try BeamObjectChecksum.savePreviousChecksum(object: object)
                                object2.title = newTitle2
                                try BeamObjectChecksum.savePreviousChecksum(object: object2)

                                let beamObjects: [BeamObject] = [try BeamObject(object),
                                                                 try BeamObject(object2)]
                                var remoteBeamObjects: [BeamObject] = []

                                waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObjects) { result in
                                            expect { try result.get() }.to(throwError { (error: BeamObjectManagerError) in
                                                switch error {
                                                case .multipleErrors(let errors):
                                                    expect(errors).to(haveCount(2))

                                                    guard let error1 = errors.first,
                                                          case BeamObjectManagerError.invalidChecksum(let remoteBeamObject) = error1,
                                                          let error2 = errors.last,
                                                          case BeamObjectManagerError.invalidChecksum(let remoteBeamObject2) = error2
                                                          else {
                                                        fail("Failed for error type")
                                                        return
                                                    }

                                                    remoteBeamObjects.append(remoteBeamObject)
                                                    remoteBeamObjects.append(remoteBeamObject2)
                                                default:
                                                    fail("Expecting invalidChecksum error")
                                                }
                                            })

                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_objects
                                expect(APIRequest.callsCount - networkCalls) == 2

//                                let remoteBeamObject = remoteBeamObjects.first(where: { $0.id == object.beamObjectId })!
//                                let remoteBeamObject2 = remoteBeamObjects.first(where: { $0.id == object2.beamObjectId })!
//
//                                expect(remoteBeamObject.id) == object.beamObjectId
//                                expect(remoteBeamObject.dataChecksum) == BeamObjectChecksum.previousChecksum(object: object)
//
//                                let remoteObject: MyRemoteObject? = try remoteBeamObject.decodeBeamObject()
//                                expect(remoteObject?.title) == title
//
//                                expect(remoteBeamObject2.id) == object2.beamObjectId
//                                expect(remoteBeamObject2.dataChecksum) == BeamObjectChecksum.previousChecksum(object: object2)
//
//                                let remoteObject2: MyRemoteObject? = try remoteBeamObject2.decodeBeamObject()
//                                expect(remoteObject2?.title) == title2
                            }
                        }
                    }

                    context("with incorrect previousChecksum") {
                        beforeEach {
                            BeamDate.travel(2)

                            object.title = "f"
                            object2.title = "f"

                            object.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now

                            try? BeamObjectChecksum.savePreviousChecksum(object: object)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object2)

                            object.title = newTitle
                            object2.title = newTitle2
                        }

                        context("with automatic conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .replace }

                            it("updates object") {

                                let networkCalls = APIRequest.callsCount

                                let objects: [MyRemoteObject] = [object, object2]

                                waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                    do {
                                        _ = try sut.saveToAPI(objects) { result in
                                            expect { try result.get() }.toNot(throwError())
                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                let expectedNetworkCalls = ["update_beam_objects",
                                                            Beam.Configuration.beamObjectDataOnSeparateCall ? "paginated_beam_objects_data_url" : "paginated_beam_objects",
                                                            "update_beam_objects"]

                                expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                let remoteObject = (try beamObjectHelper.fetchOnAPI(object))!
                                let remoteObject2 = (try beamObjectHelper.fetchOnAPI(object2))!

                                expect(object) == remoteObject
                                expect(object2) == remoteObject2

                                expect((try BeamObject(remoteObject)).dataChecksum) == BeamObjectChecksum.previousChecksum(object: remoteObject)
                                expect((try BeamObject(remoteObject2)).dataChecksum) == BeamObjectChecksum.previousChecksum(object: remoteObject2)
                            }

                            it("updates beam object") {
                                let networkCalls = APIRequest.callsCount

                                let beamObject = try BeamObject(object)
                                let beamObject2 = try BeamObject(object2)
                                let beamObjects: [BeamObject] = [beamObject, beamObject2]

                                waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObjects) { result in
                                            expect { try result.get() }.toNot(throwError())
                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_objects + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 3

                                let remoteObject = (try beamObjectHelper.fetchOnAPI(object))!
                                let remoteObject2 = (try beamObjectHelper.fetchOnAPI(object2))!

                                expect(object) == remoteObject
                                expect(object2) == remoteObject2

                                expect((try BeamObject(remoteObject)).dataChecksum) == BeamObjectChecksum.previousChecksum(object: remoteObject)
                                expect((try BeamObject(remoteObject2)).dataChecksum) == BeamObjectChecksum.previousChecksum(object: remoteObject2)
                            }
                        }

                        context("with manual conflict management") {
                            beforeEach {
                                sut.conflictPolicyForSave = .fetchRemoteAndError

                                object.title = "fake"
                                object2.title = "fake"

                                try? BeamObjectChecksum.savePreviousChecksum(object: object)
                                try? BeamObjectChecksum.savePreviousChecksum(object: object2)

                                object.title = newTitle
                                object2.title = newTitle2
                            }

                            it("raise error and return remote object for MyRemoteObjects") {
                                let networkCalls = APIRequest.callsCount

                                let beamObjects: [MyRemoteObject] = [object, object2]

                                waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObjects) { result in
                                            expect { try result.get() }.to(throwError { (error: BeamObjectManagerObjectError<MyRemoteObject>) in
                                                switch error {
                                                case .invalidChecksum(_, _, let remoteObjects):
                                                    expect(remoteObjects).to(haveCount(2))
                                                }
                                            })

                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                let expectedNetworkCalls = ["update_beam_objects",
                                                            Beam.Configuration.beamObjectDataOnSeparateCall ? "paginated_beam_objects_data_url" : "paginated_beam_objects"]

                                expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                let remoteObject = (try beamObjectHelper.fetchOnAPI(object))!
                                let remoteObject2 = (try beamObjectHelper.fetchOnAPI(object2))!

                                expect(remoteObject) != object
                                expect(remoteObject2) != object2

                                expect(remoteObject.beamObjectId) == object.beamObjectId
                                expect(remoteObject.title) == title

                                expect(remoteObject2.beamObjectId) == object2.beamObjectId
                                expect(remoteObject2.title) == title2

                                expect((try BeamObject(remoteObject)).dataChecksum) != BeamObjectChecksum.previousChecksum(object: remoteObject)
                                expect((try BeamObject(remoteObject2)).dataChecksum) != BeamObjectChecksum.previousChecksum(object: remoteObject2)
                            }

                            it("raise error and return remote beam object for BeamObjects") {
                                let networkCalls = APIRequest.callsCount

                                let beamObjects: [BeamObject] = [try BeamObject(object), try BeamObject(object2)]
                                var remoteBeamObjects: [BeamObject] = []

                                waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObjects) { result in
                                            expect { try result.get() }.to(throwError { (error: BeamObjectManagerError) in
                                                switch error {
                                                case .multipleErrors(let errors):
                                                    expect(errors).to(haveCount(2))

                                                    guard let error1 = errors.first,
                                                          case BeamObjectManagerError.invalidChecksum(let remoteBeamObject) = error1,
                                                          let error2 = errors.last,
                                                          case BeamObjectManagerError.invalidChecksum(let remoteBeamObject2) = error2
                                                          else {
                                                        fail("Failed for error type")
                                                        return
                                                    }

                                                    remoteBeamObjects.append(remoteBeamObject)
                                                    remoteBeamObjects.append(remoteBeamObject2)
                                                default:
                                                    fail("Expecting invalidChecksum error")
                                                }
                                            })

                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_objects
                                expect(APIRequest.callsCount - networkCalls) == 2

                                let remoteBeamObject = remoteBeamObjects.first(where: { $0.id == object.beamObjectId })!
                                let remoteBeamObject2 = remoteBeamObjects.first(where: { $0.id == object2.beamObjectId })!

                                expect(remoteBeamObject.id) == object.beamObjectId
                                expect(remoteBeamObject2.id) == object2.beamObjectId

                                let remoteObject: MyRemoteObject = try remoteBeamObject.decodeBeamObject()
                                expect(remoteObject.title) == title

                                let remoteObject2: MyRemoteObject = try remoteBeamObject2.decodeBeamObject()
                                expect(remoteObject2.title) == title2

                                expect(remoteBeamObject.dataChecksum) != BeamObjectChecksum.previousChecksum(object: object)
                                expect(remoteBeamObject2.dataChecksum) != BeamObjectChecksum.previousChecksum(object: object2)
                            }
                        }
                    }
                }
            }

            context("with async") {
                context("with new object") {
                    asyncIt("saves new object") {
                        let networkCalls = APIRequest.callsCount

                        let objects: [MyRemoteObject] = [object, object2]

                        var returnedObjects: [MyRemoteObject] = []

                        do {
                            returnedObjects = try await sut.saveToAPI(objects)
                        } catch {
                            fail(error.localizedDescription)
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        expect(object) == (try beamObjectHelper.fetchOnAPI(object))
                        expect(object2) == (try beamObjectHelper.fetchOnAPI(object2))

                        // `previousChecksum` should be set on returned objects
                        let beamObject = try BeamObject(object)
                        expect(returnedObjects.first?.previousChecksum) == beamObject.dataChecksum

                        let beamObject2 = try BeamObject(object2)
                        expect(returnedObjects.last?.previousChecksum) == beamObject2.dataChecksum
                    }

                    asyncIt("saves new beam object") {
                        let networkCalls = APIRequest.callsCount

                        let beamObjects: [BeamObject] = [try BeamObject(object),  try BeamObject(object2)]

                        do {
                            _ = try await sut.saveToAPI(beamObjects)
                        } catch {
                            fail(error.localizedDescription)
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        expect(object) == (try beamObjectHelper.fetchOnAPI(object))
                        expect(object2) == (try beamObjectHelper.fetchOnAPI(object2))
                    }
                }

                context("with persisted object") {
                    beforeEach {
                        beamObjectHelper.saveOnAPIAndSaveChecksum(object)
                        beamObjectHelper.saveOnAPIAndSaveChecksum(object2)
                    }

                    context("with good previousChecksum") {
                        asyncIt("saves existing object") {
                            let networkCalls = APIRequest.callsCount
                            object.title = newTitle
                            object2.title = newTitle2

                            let objects: [MyRemoteObject] = [object, object2]
                            var returnedObjects: [MyRemoteObject] = []

                            do {
                                returnedObjects = try await sut.saveToAPI(objects)
                            } catch {
                                fail(error.localizedDescription)
                            }

                            expect(APIRequest.callsCount - networkCalls) == 1

                            expect(object) == (try beamObjectHelper.fetchOnAPI(object))
                            expect(object2) == (try beamObjectHelper.fetchOnAPI(object2))

                            let beamObject = try? BeamObject(object)
                            expect(returnedObjects.first?.previousChecksum) == beamObject?.dataChecksum

                            let beamObject2 = try? BeamObject(object2)
                            expect(returnedObjects.last?.previousChecksum) == beamObject2?.dataChecksum
                        }

                        asyncIt("saves existing beam object") {
                            let networkCalls = APIRequest.callsCount
                            object.title = newTitle
                            object2.title = newTitle2

                            let beamObject = try BeamObject(object)
                            let beamObject2 = try BeamObject(object2)
                            let beamObjects: [BeamObject] = [beamObject, beamObject2]

                            do {
                                try await sut.saveToAPI(beamObjects)
                            } catch {
                                fail(error.localizedDescription)
                            }

                            expect(APIRequest.callsCount - networkCalls) == 1

                            expect(object) == (try beamObjectHelper.fetchOnAPI(object))
                            expect(object2) == (try beamObjectHelper.fetchOnAPI(object2))
                        }
                    }

                    context("with empty previousChecksum") {
                        beforeEach {
                            try? BeamObjectChecksum.deletePreviousChecksum(object: object)
                            try? BeamObjectChecksum.deletePreviousChecksum(object: object2)
                        }

                        context("with automatic conflict management") {
                            beforeEach {
                                BeamDate.travel(2)

                                object.title = newTitle
                                object2.title = newTitle2
                                object.updatedAt = BeamDate.now
                                object2.updatedAt = BeamDate.now
                            }

                            asyncIt("updates object") {
                                let networkCalls = APIRequest.callsCount

                                let objects: [MyRemoteObject] = [object, object2]
                                var returnedObjects: [MyRemoteObject] = []

                                do {
                                    returnedObjects = try await sut.saveToAPI(objects)
                                } catch {
                                    fail(error.localizedDescription)
                                }

                                let expectedNetworkCalls = ["update_beam_objects",
                                                            Beam.Configuration.beamObjectDataOnSeparateCall ? "paginated_beam_objects_data_url" : "paginated_beam_objects",
                                                            "update_beam_objects"]

                                expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                expect(object) == (try beamObjectHelper.fetchOnAPI(object))
                                expect(object2) == (try beamObjectHelper.fetchOnAPI(object2))

                                let remoteObject = returnedObjects.first(where: { $0.beamObjectId == object.beamObjectId })
                                let remoteObject2 = returnedObjects.first(where: { $0.beamObjectId == object2.beamObjectId })

                                // `previousChecksum` should be set on returned objects
                                let beamObject = try BeamObject(object)
                                let beamObject2 = try BeamObject(object2)

                                expect(remoteObject?.previousChecksum) == beamObject.dataChecksum
                                expect(remoteObject2?.previousChecksum) == beamObject2.dataChecksum
                            }

                            asyncIt("updates object") {
                                expect(BeamObjectChecksum.previousChecksum(object: object)).to(beNil())
                                expect(BeamObjectChecksum.previousChecksum(object: object2)).to(beNil())

                                let networkCalls = APIRequest.callsCount

                                let beamObjects: [BeamObject] = [try BeamObject(object),
                                                                 try BeamObject(object2)]

                                do {
                                    try await sut.saveToAPI(beamObjects)
                                } catch {
                                    fail(error.localizedDescription)
                                }

                                // update_beam_object + beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 3

                                let remoteBeamObject = try beamObjectHelper.fetchOnAPI(object)
                                let remoteBeamObject2 = try beamObjectHelper.fetchOnAPI(object2)

                                expect(object) == remoteBeamObject
                                expect(object2) == remoteBeamObject2

                                expect(try BeamObject(object).dataChecksum) == BeamObjectChecksum.previousChecksum(object: object)
                                expect(try BeamObject(object2).dataChecksum) == BeamObjectChecksum.previousChecksum(object: object2)
                            }
                        }

                        context("with manual conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .fetchRemoteAndError }

                            asyncIt("raise error and return remote object") {
                                let networkCalls = APIRequest.callsCount

                                object.title = newTitle
                                object2.title = newTitle2

                                let beamObjects: [MyRemoteObject] = [object, object2]

                                do {
                                    try await sut.saveToAPI(beamObjects)
                                } catch {
                                    switch error as! BeamObjectManagerObjectError<MyRemoteObject> {
                                    case .invalidChecksum(_, _, let remoteObjects):
                                        expect(remoteObjects).to(haveCount(2))
                                    }

                                    let expectedNetworkCalls = ["update_beam_objects",
                                                                Beam.Configuration.beamObjectDataOnSeparateCall ? "paginated_beam_objects_data_url" : "paginated_beam_objects"]

                                    expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                    expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                    let remoteObject = (try beamObjectHelper.fetchOnAPI(object))!
                                    let remoteObject2 = (try beamObjectHelper.fetchOnAPI(object2))!

                                    expect(remoteObject) != object
                                    expect(remoteObject2) != object2

                                    expect(remoteObject.beamObjectId) == object.beamObjectId
                                    expect(remoteObject.title) == title

                                    expect(remoteObject2.beamObjectId) == object2.beamObjectId
                                    expect(remoteObject2.title) == title2
                                }
                            }

                            asyncIt("raise error and return remote beam object") {
                                let networkCalls = APIRequest.callsCount

                                object.title = newTitle
                                try BeamObjectChecksum.savePreviousChecksum(object: object)
                                object2.title = newTitle2
                                try BeamObjectChecksum.savePreviousChecksum(object: object2)

                                let beamObjects: [BeamObject] = [try BeamObject(object),
                                                                 try BeamObject(object2)]
                                var remoteBeamObjects: [BeamObject] = []

                                do {
                                    try await sut.saveToAPI(beamObjects)
                                } catch {
                                    switch error as! BeamObjectManagerError {
                                    case .multipleErrors(let errors):
                                        expect(errors).to(haveCount(2))

                                        guard let error1 = errors.first,
                                              case BeamObjectManagerError.invalidChecksum(let remoteBeamObject) = error1,
                                              let error2 = errors.last,
                                              case BeamObjectManagerError.invalidChecksum(let remoteBeamObject2) = error2
                                        else {
                                            fail("Failed for error type")
                                            return
                                        }

                                        remoteBeamObjects.append(remoteBeamObject)
                                        remoteBeamObjects.append(remoteBeamObject2)
                                    default:
                                        fail("Expecting invalidChecksum error")
                                    }
                                }

                                // update_beam_object + beam_objects
                                expect(APIRequest.callsCount - networkCalls) == 2
                            }
                        }

                        context("with incorrect previousChecksum") {
                            beforeEach {
                                BeamDate.travel(2)

                                object.title = "f"
                                object2.title = "f"

                                object.updatedAt = BeamDate.now
                                object2.updatedAt = BeamDate.now

                                try? BeamObjectChecksum.savePreviousChecksum(object: object)
                                try? BeamObjectChecksum.savePreviousChecksum(object: object2)

                                object.title = newTitle
                                object2.title = newTitle2
                            }

                            context("with automatic conflict management") {
                                beforeEach { sut.conflictPolicyForSave = .replace }

                                asyncIt("updates object") {

                                    let networkCalls = APIRequest.callsCount

                                    let objects: [MyRemoteObject] = [object, object2]

                                    do {
                                        try await sut.saveToAPI(objects)
                                    } catch {
                                        fail(error.localizedDescription)
                                    }

                                    let expectedNetworkCalls = ["update_beam_objects",
                                                                Beam.Configuration.beamObjectDataOnSeparateCall ? "paginated_beam_objects_data_url" : "paginated_beam_objects",
                                                                "update_beam_objects"]

                                    expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                    expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                    let remoteObject = (try beamObjectHelper.fetchOnAPI(object))!
                                    let remoteObject2 = (try beamObjectHelper.fetchOnAPI(object2))!

                                    expect(object) == remoteObject
                                    expect(object2) == remoteObject2

                                    expect((try BeamObject(remoteObject)).dataChecksum) == BeamObjectChecksum.previousChecksum(object: remoteObject)
                                    expect((try BeamObject(remoteObject2)).dataChecksum) == BeamObjectChecksum.previousChecksum(object: remoteObject2)
                                }

                                asyncIt("updates beam object") {
                                    let networkCalls = APIRequest.callsCount

                                    let beamObject = try BeamObject(object)
                                    let beamObject2 = try BeamObject(object2)
                                    let beamObjects: [BeamObject] = [beamObject, beamObject2]

                                    do {
                                        try await sut.saveToAPI(beamObjects)
                                    } catch {
                                        fail(error.localizedDescription)
                                    }

                                    // update_beam_object + beam_objects + update_beam_object
                                    expect(APIRequest.callsCount - networkCalls) == 3

                                    let remoteObject = (try beamObjectHelper.fetchOnAPI(object))!
                                    let remoteObject2 = (try beamObjectHelper.fetchOnAPI(object2))!

                                    expect(object) == remoteObject
                                    expect(object2) == remoteObject2

                                    expect((try BeamObject(remoteObject)).dataChecksum) == BeamObjectChecksum.previousChecksum(object: remoteObject)
                                    expect((try BeamObject(remoteObject2)).dataChecksum) == BeamObjectChecksum.previousChecksum(object: remoteObject2)
                                }
                            }

                            context("with manual conflict management") {
                                beforeEach {
                                    sut.conflictPolicyForSave = .fetchRemoteAndError

                                    object.title = "fake"
                                    object2.title = "fake"

                                    try? BeamObjectChecksum.savePreviousChecksum(object: object)
                                    try? BeamObjectChecksum.savePreviousChecksum(object: object2)

                                    object.title = newTitle
                                    object2.title = newTitle2
                                }

                                asyncIt("raise error and return remote object for MyRemoteObjects") {
                                    let networkCalls = APIRequest.callsCount

                                    let beamObjects: [MyRemoteObject] = [object, object2]

                                    do {
                                        try await sut.saveToAPI(beamObjects)
                                    } catch {
                                        switch error as! BeamObjectManagerObjectError<MyRemoteObject> {
                                        case .invalidChecksum(_, _, let remoteObjects):
                                            expect(remoteObjects).to(haveCount(2))
                                        }

                                        let expectedNetworkCalls = ["update_beam_objects",
                                                                    Beam.Configuration.beamObjectDataOnSeparateCall ? "paginated_beam_objects_data_url" : "paginated_beam_objects"]

                                        expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                        expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                        let remoteObject = (try beamObjectHelper.fetchOnAPI(object))!
                                        let remoteObject2 = (try beamObjectHelper.fetchOnAPI(object2))!

                                        expect(remoteObject) != object
                                        expect(remoteObject2) != object2

                                        expect(remoteObject.beamObjectId) == object.beamObjectId
                                        expect(remoteObject.title) == title

                                        expect(remoteObject2.beamObjectId) == object2.beamObjectId
                                        expect(remoteObject2.title) == title2

                                        expect((try BeamObject(remoteObject)).dataChecksum) != BeamObjectChecksum.previousChecksum(object: remoteObject)
                                        expect((try BeamObject(remoteObject2)).dataChecksum) != BeamObjectChecksum.previousChecksum(object: remoteObject2)
                                    }
                                }

                                asyncIt("raise error and return remote beam object for BeamObjects") {
                                    let networkCalls = APIRequest.callsCount

                                    let beamObjects: [BeamObject] = [try BeamObject(object), try BeamObject(object2)]
                                    var remoteBeamObjects: [BeamObject] = []

                                    do {
                                        try await sut.saveToAPI(beamObjects)
                                    } catch {
                                        switch error as! BeamObjectManagerError {
                                        case .multipleErrors(let errors):
                                            expect(errors).to(haveCount(2))

                                            guard let error1 = errors.first,
                                                  case BeamObjectManagerError.invalidChecksum(let remoteBeamObject) = error1,
                                                  let error2 = errors.last,
                                                  case BeamObjectManagerError.invalidChecksum(let remoteBeamObject2) = error2
                                            else {
                                                fail("Failed for error type")
                                                return
                                            }

                                            remoteBeamObjects.append(remoteBeamObject)
                                            remoteBeamObjects.append(remoteBeamObject2)
                                        default:
                                            fail("Expecting invalidChecksum error")
                                        }
                                    }

                                    // update_beam_object + beam_objects
                                    expect(APIRequest.callsCount - networkCalls) == 2

                                    let remoteBeamObject = remoteBeamObjects.first(where: { $0.id == object.beamObjectId })!
                                    let remoteBeamObject2 = remoteBeamObjects.first(where: { $0.id == object2.beamObjectId })!

                                    expect(remoteBeamObject.id) == object.beamObjectId
                                    expect(remoteBeamObject2.id) == object2.beamObjectId

                                    let remoteObject: MyRemoteObject = try remoteBeamObject.decodeBeamObject()
                                    expect(remoteObject.title) == title

                                    let remoteObject2: MyRemoteObject = try remoteBeamObject2.decodeBeamObject()
                                    expect(remoteObject2.title) == title2

                                    expect(remoteBeamObject.dataChecksum) != BeamObjectChecksum.previousChecksum(object: object)
                                    expect(remoteBeamObject2.dataChecksum) != BeamObjectChecksum.previousChecksum(object: object2)
                                }
                            }
                        }
                    }
                }
            }
        }

        describe("saveToAPI(beamObject)") {
            var object: MyRemoteObject!
            let title = "This is my title"
            let newTitle = "This is a new title"
            let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd28".uuid ?? UUID()

            beforeEach {
                object = MyRemoteObject(beamObjectId: uuid,
                                        createdAt: BeamDate.now,
                                        updatedAt: BeamDate.now,
                                        deletedAt: nil,
                                        title: title)
            }

            afterEach {
                let semaphore = DispatchSemaphore(value: 0)
                _ = try? sut.delete(object: object) { _ in
                    semaphore.signal()
                }

                _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))
            }

            context("with Foundation") {
                context("with new object") {
                    it("saves new object") {
                        let networkCalls = APIRequest.callsCount
                        var returnedObject: MyRemoteObject?

                        waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                            do {
                                _ = try sut.saveToAPI(object) { result in
                                    expect { returnedObject = try result.get() }.toNot(throwError())
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        expect(object) == (try beamObjectHelper.fetchOnAPI(object))

                        // `previousChecksum` should be set on returned object
                        let beamObject = try BeamObject(object)
                        expect(returnedObject?.previousChecksum) == beamObject.dataChecksum
                    }

                    it("saves new beam object") {
                        let networkCalls = APIRequest.callsCount

                        let beamObject = try BeamObject(object)

                        waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                            do {
                                _ = try sut.saveToAPI(beamObject) { result in
                                    expect { try result.get() }.toNot(throwError())
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        expect(object) == (try beamObjectHelper.fetchOnAPI(object))

                        // `previousChecksum` should be set on returned object
                        expect(beamObject.dataChecksum) == BeamObjectChecksum.previousChecksum(object: object)
                    }
                }

                context("with persisted object") {
                    var previousChecksum: String?

                    beforeEach {
                        let beamObject = beamObjectHelper.saveOnAPI(object)
                        previousChecksum = beamObject?.dataChecksum
                    }

                    context("with good previousChecksum") {
                        beforeEach {
                            object.title = newTitle
                        }

                        it("saves existing object") {
                            let networkCalls = APIRequest.callsCount

                            var returnedObject: MyRemoteObject?

                            waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                do {
                                    _ = try sut.saveToAPI(object) { result in
                                        expect { returnedObject = try result.get() }.toNot(throwError())
                                        done()
                                    }
                                } catch {
                                    fail(error.localizedDescription)
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 1

                            expect(try beamObjectHelper.fetchOnAPI(object)) == object

                            // `previousChecksum` should be set on returned object
                            let beamObject = try BeamObject(object)
                            expect(returnedObject?.previousChecksum) == beamObject.dataChecksum
                        }

                        it("saves existing object") {
                            let networkCalls = APIRequest.callsCount

                            let beamObject = try BeamObject(object)

                            waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                do {
                                    _ = try sut.saveToAPI(beamObject) { result in
                                        expect { try result.get() }.toNot(throwError())
                                        done()
                                    }
                                } catch {
                                    fail(error.localizedDescription)
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 1

                            expect(object) == (try beamObjectHelper.fetchOnAPI(object))
                            expect(beamObject.dataChecksum) == BeamObjectChecksum.previousChecksum(beamObject: beamObject)
                        }
                    }

                    context("with empty previousChecksum") {
                        beforeEach {
                            BeamDate.travel(2)

                            object.title = newTitle
                            object.updatedAt = BeamDate.now
                            try? BeamObjectChecksum.deletePreviousChecksum(object: object)
                        }

                        context("with automatic conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .replace }

                            it("updates object") {
                                let networkCalls = APIRequest.callsCount
                                var returnedObject: MyRemoteObject?

                                waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                    do {
                                        _ = try sut.saveToAPI(object) { result in
                                            expect { returnedObject = try result.get() }.toNot(throwError())
                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 3

                                expect(object) == (try beamObjectHelper.fetchOnAPI(object))

                                // `previousChecksum` should be set on returned object
                                let beamObject = try BeamObject(object)
                                expect(returnedObject?.previousChecksum) == beamObject.dataChecksum
                            }

                            it("updates beam object") {
                                let networkCalls = APIRequest.callsCount

                                let beamObject = try BeamObject(object)

                                waitUntil(timeout: .seconds(1000)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObject) { result in
                                            expect { try result.get() }.toNot(throwError())
                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 3
                                expect(APIRequest.networkCallFiles) == ["sign_in",
                                                                        "update_beam_object", "update_beam_object",
                                                                        Beam.Configuration.beamObjectDataOnSeparateCall ? "beam_object_data_url" : "beam_object",
                                                                        "update_beam_object"]

                                expect(object) == (try beamObjectHelper.fetchOnAPI(object))
                            }
                        }

                        context("with manual conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .fetchRemoteAndError }

                            it("raise error and return remote object") {
                                let networkCalls = APIRequest.callsCount

                                object.title = newTitle

                                var remoteObject: MyRemoteObject?

                                waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                    do {
                                        _ = try sut.saveToAPI(object) { result in
                                            expect { try result.get() }.to(throwError { (error: BeamObjectManagerObjectError<MyRemoteObject>) in
                                                switch error {
                                                case .invalidChecksum(_, _, let remoteOldObjects):
                                                    remoteObject = remoteOldObjects.first
                                                }
                                            })

                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_object
                                expect(APIRequest.callsCount - networkCalls) == 2

                                expect(remoteObject) != object

                                expect(remoteObject?.beamObjectId) == object.beamObjectId
                                expect(remoteObject?.title) == title
                            }

                            it("raise error and return remote object") {
                                let networkCalls = APIRequest.callsCount

                                object.title = newTitle
                                try BeamObjectChecksum.savePreviousChecksum(object: object)

                                let beamObject = try BeamObject(object)
                                var remoteBeamObject: BeamObject?

                                waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObject) { result in
                                            expect { try result.get() }.to(throwError { (error: BeamObjectManagerError) in
                                                switch error {
                                                case .invalidChecksum(let remoteBeamOldObject):
                                                    remoteBeamObject = remoteBeamOldObject
                                                default:
                                                    fail("Expecting invalidChecksum error")
                                                }
                                            })

                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_object
                                expect(APIRequest.callsCount - networkCalls) == 2

                                expect(remoteBeamObject?.id) == object.beamObjectId
                                expect(remoteBeamObject?.dataChecksum) == previousChecksum

                                let remoteObject: MyRemoteObject? = try remoteBeamObject?.decodeBeamObject()
                                expect(remoteObject?.title) == title
                            }
                        }
                    }

                    context("with incorrect previousChecksum") {
                        beforeEach {
                            BeamDate.travel(2)

                            object.title = "fake"
                            object.updatedAt = BeamDate.now
                            try? BeamObjectChecksum.savePreviousChecksum(object: object)
                            object.title = newTitle
                        }

                        context("with automatic conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .replace }

                            it("updates object") {
                                let networkCalls = APIRequest.callsCount

                                waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                    do {
                                        _ = try sut.saveToAPI(object) { result in
                                            expect { try result.get() }.toNot(throwError())
                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 3

                                expect(object) == (try beamObjectHelper.fetchOnAPI(object))

                                // `previousChecksum` should be set on returned object
                                let beamObject = try BeamObject(object)
                                expect(beamObject.dataChecksum) == BeamObjectChecksum.previousChecksum(beamObject: beamObject)
                            }

                            it("updates beam object") {
                                let networkCalls = APIRequest.callsCount

                                let beamObject = try BeamObject(object)

                                waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObject) { result in
                                            expect { try result.get() }.toNot(throwError())
                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 3

                                expect(object) == (try beamObjectHelper.fetchOnAPI(object))
                                expect(beamObject.dataChecksum) == BeamObjectChecksum.previousChecksum(beamObject: beamObject)
                            }
                        }

                        context("with manual conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .fetchRemoteAndError }

                            it("raise error and return remote object") {
                                let networkCalls = APIRequest.callsCount

                                object.title = newTitle

                                var remoteObject: MyRemoteObject?

                                waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                    do {
                                        _ = try sut.saveToAPI(object) { result in
                                            expect { try result.get() }.to(throwError { (error: BeamObjectManagerObjectError<MyRemoteObject>) in
                                                switch error {
                                                case .invalidChecksum(_, _, let remoteOldObjects):
                                                    remoteObject = remoteOldObjects.first
                                                }
                                            })

                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_object
                                expect(APIRequest.callsCount - networkCalls) == 2

                                expect(remoteObject) != object

                                expect(remoteObject?.beamObjectId) == object.beamObjectId
                                expect(remoteObject?.title) == title
                            }

                            it("raise error and return remote object") {
                                let networkCalls = APIRequest.callsCount

                                object.title = newTitle
                                try BeamObjectChecksum.savePreviousChecksum(object: object)

                                let beamObject = try BeamObject(object)
                                var remoteBeamObject: BeamObject?

                                waitUntil(timeout: .seconds(Self.networkTimeout)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObject) { result in
                                            expect { try result.get() }.to(throwError { (error: BeamObjectManagerError) in
                                                switch error {
                                                case .invalidChecksum(let remoteBeamOldObject):
                                                    remoteBeamObject = remoteBeamOldObject
                                                default:
                                                    fail("Expecting invalidChecksum error")
                                                }
                                            })

                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_object
                                expect(APIRequest.callsCount - networkCalls) == 2

                                expect(remoteBeamObject?.id) == object.beamObjectId
                                expect(remoteBeamObject?.dataChecksum) == previousChecksum

                                let remoteObject: MyRemoteObject? = try remoteBeamObject?.decodeBeamObject()
                                expect(remoteObject?.title) == title
                            }
                        }
                    }
                }
            }

            context("with async") {
                context("with new object") {
                    asyncIt("saves new object") {
                        let networkCalls = APIRequest.callsCount
                        var returnedObject: MyRemoteObject?

                        do {
                            returnedObject = try await sut.saveToAPI(object)
                        } catch {
                            fail(error.localizedDescription)
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        expect(object) == (try beamObjectHelper.fetchOnAPI(object))

                        // `previousChecksum` should be set on returned object
                        let beamObject = try BeamObject(object)
                        expect(returnedObject?.previousChecksum) == beamObject.dataChecksum
                    }

                    asyncIt("saves new beam object") {
                        let networkCalls = APIRequest.callsCount

                        let beamObject = try BeamObject(object)

                        do {
                            _ = try await sut.saveToAPI(beamObject)
                        } catch {
                            fail(error.localizedDescription)
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        expect(object) == (try beamObjectHelper.fetchOnAPI(object))

                        // `previousChecksum` should be set on returned object
                        expect(beamObject.dataChecksum) == BeamObjectChecksum.previousChecksum(object: object)
                    }
                }

                context("with persisted object") {
                    var previousChecksum: String?

                    beforeEach {
                        let beamObject = beamObjectHelper.saveOnAPI(object)
                        previousChecksum = beamObject?.dataChecksum
                    }

                    context("with good previousChecksum") {
                        beforeEach {
                            object.title = newTitle
                        }

                        asyncIt("saves existing object") {
                            let networkCalls = APIRequest.callsCount

                            var returnedObject: MyRemoteObject?

                            do {
                                returnedObject = try await sut.saveToAPI(object)
                            } catch {
                                fail(error.localizedDescription)
                            }

                            expect(APIRequest.callsCount - networkCalls) == 1

                            expect(try beamObjectHelper.fetchOnAPI(object)) == object

                            // `previousChecksum` should be set on returned object
                            let beamObject = try BeamObject(object)
                            expect(returnedObject?.previousChecksum) == beamObject.dataChecksum
                        }

                        asyncIt("saves existing object") {
                            let networkCalls = APIRequest.callsCount

                            let beamObject = try BeamObject(object)

                            do {
                                _ = try await sut.saveToAPI(beamObject)
                            } catch {
                                fail(error.localizedDescription)
                            }

                            expect(APIRequest.callsCount - networkCalls) == 1

                            expect(object) == (try beamObjectHelper.fetchOnAPI(object))
                            expect(beamObject.dataChecksum) == BeamObjectChecksum.previousChecksum(beamObject: beamObject)
                        }
                    }

                    context("with empty previousChecksum") {
                        beforeEach {
                            BeamDate.travel(2)

                            object.title = newTitle
                            object.updatedAt = BeamDate.now
                            try? BeamObjectChecksum.deletePreviousChecksum(object: object)
                        }

                        context("with automatic conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .replace }

                            asyncIt("updates object") {
                                let networkCalls = APIRequest.callsCount
                                var returnedObject: MyRemoteObject?

                                do {
                                    returnedObject = try await sut.saveToAPI(object)
                                } catch {
                                    fail(error.localizedDescription)
                                }

                                // update_beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 3

                                expect(object) == (try beamObjectHelper.fetchOnAPI(object))

                                // `previousChecksum` should be set on returned object
                                let beamObject = try BeamObject(object)
                                expect(returnedObject?.previousChecksum) == beamObject.dataChecksum
                            }

                            asyncIt("updates beam object") {
                                let networkCalls = APIRequest.callsCount

                                let beamObject = try BeamObject(object)

                                do {
                                    _ = try await sut.saveToAPI(beamObject)
                                } catch {
                                    fail(error.localizedDescription)
                                }

                                // update_beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 3
                                expect(APIRequest.networkCallFiles) == ["sign_in",
                                                                        "update_beam_object", "update_beam_object",
                                                                        Beam.Configuration.beamObjectDataOnSeparateCall ? "beam_object_data_url" : "beam_object",
                                                                        "update_beam_object"]

                                expect(object) == (try beamObjectHelper.fetchOnAPI(object))
                            }
                        }

                        context("with manual conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .fetchRemoteAndError }

                            asyncIt("raise error and return remote object") {
                                let networkCalls = APIRequest.callsCount

                                object.title = newTitle

                                var remoteObject: MyRemoteObject?

                                do {
                                    _ = try await sut.saveToAPI(object)
                                } catch {
                                    switch error as! BeamObjectManagerObjectError<MyRemoteObject> {
                                    case .invalidChecksum(_, _, let remoteOldObjects):
                                        remoteObject = remoteOldObjects.first
                                    }
                                }

                                // update_beam_object + beam_object
                                expect(APIRequest.callsCount - networkCalls) == 2

                                expect(remoteObject) != object

                                expect(remoteObject?.beamObjectId) == object.beamObjectId
                                expect(remoteObject?.title) == title
                            }

                            asyncIt("raise error and return remote object") {
                                let networkCalls = APIRequest.callsCount

                                object.title = newTitle
                                try BeamObjectChecksum.savePreviousChecksum(object: object)

                                let beamObject = try BeamObject(object)
                                var remoteBeamObject: BeamObject?

                                do {
                                    _ = try await sut.saveToAPI(beamObject)
                                } catch {
                                    switch error as! BeamObjectManagerError {
                                    case .invalidChecksum(let remoteBeamOldObject):
                                        remoteBeamObject = remoteBeamOldObject
                                    default:
                                        fail("Expecting invalidChecksum error")
                                    }
                                }

                                // update_beam_object + beam_object
                                expect(APIRequest.callsCount - networkCalls) == 2

                                expect(remoteBeamObject?.id) == object.beamObjectId
                                expect(remoteBeamObject?.dataChecksum) == previousChecksum

                                let remoteObject: MyRemoteObject? = try remoteBeamObject?.decodeBeamObject()
                                expect(remoteObject?.title) == title
                            }
                        }
                    }

                    context("with incorrect previousChecksum") {
                        beforeEach {
                            BeamDate.travel(2)

                            object.title = "fake"
                            object.updatedAt = BeamDate.now
                            try? BeamObjectChecksum.savePreviousChecksum(object: object)
                            object.title = newTitle
                        }

                        context("with automatic conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .replace }

                            asyncIt("updates object") {
                                let networkCalls = APIRequest.callsCount

                                do {
                                    _ = try await sut.saveToAPI(object)
                                } catch {
                                    fail(error.localizedDescription)
                                }

                                // update_beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 3

                                expect(object) == (try beamObjectHelper.fetchOnAPI(object))

                                // `previousChecksum` should be set on returned object
                                let beamObject = try BeamObject(object)
                                expect(beamObject.dataChecksum) == BeamObjectChecksum.previousChecksum(beamObject: beamObject)
                            }

                            asyncIt("updates beam object") {
                                let networkCalls = APIRequest.callsCount

                                let beamObject = try BeamObject(object)

                                do {
                                    _ = try await sut.saveToAPI(beamObject)
                                } catch {
                                    fail(error.localizedDescription)
                                }

                                // update_beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 3

                                expect(object) == (try beamObjectHelper.fetchOnAPI(object))
                                expect(beamObject.dataChecksum) == BeamObjectChecksum.previousChecksum(beamObject: beamObject)
                            }
                        }

                        context("with manual conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .fetchRemoteAndError }

                            asyncIt("raise error and return remote object") {
                                let networkCalls = APIRequest.callsCount

                                object.title = newTitle

                                var remoteObject: MyRemoteObject?

                                do {
                                    _ = try await sut.saveToAPI(object)
                                } catch {
                                    switch error as! BeamObjectManagerObjectError<MyRemoteObject> {
                                    case .invalidChecksum(_, _, let remoteOldObjects):
                                        remoteObject = remoteOldObjects.first
                                    }
                                }

                                // update_beam_object + beam_object
                                expect(APIRequest.callsCount - networkCalls) == 2

                                expect(remoteObject) != object

                                expect(remoteObject?.beamObjectId) == object.beamObjectId
                                expect(remoteObject?.title) == title
                            }

                            asyncIt("raise error and return remote object") {
                                let networkCalls = APIRequest.callsCount

                                object.title = newTitle
                                try BeamObjectChecksum.savePreviousChecksum(object: object)

                                let beamObject = try BeamObject(object)
                                var remoteBeamObject: BeamObject?

                                do {
                                    _ = try await sut.saveToAPI(beamObject)
                                } catch {
                                    switch error as! BeamObjectManagerError {
                                    case .invalidChecksum(let remoteBeamOldObject):
                                        remoteBeamObject = remoteBeamOldObject
                                    default:
                                        fail("Expecting invalidChecksum error")
                                    }
                                }

                                // update_beam_object + beam_object
                                expect(APIRequest.callsCount - networkCalls) == 2

                                expect(remoteBeamObject?.id) == object.beamObjectId
                                expect(remoteBeamObject?.dataChecksum) == previousChecksum

                                let remoteObject: MyRemoteObject? = try remoteBeamObject?.decodeBeamObject()
                                expect(remoteObject?.title) == title
                            }
                        }
                    }
                }
            }
        }

        describe("saveToAPI(beamObject) without email") {
            var object: MyRemoteObject!
            let title = "This is my title"
            let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd28".uuid ?? UUID()
            let previousEmail = Persistence.Authentication.email
            beforeEach {
                Persistence.Authentication.email = nil
                object = MyRemoteObject(beamObjectId: uuid,
                                        createdAt: BeamDate.now,
                                        updatedAt: BeamDate.now,
                                        deletedAt: nil,
                                        title: title)
            }

            afterEach {
                Persistence.Authentication.email = previousEmail
            }

            context("with Foundation") {
                context("with new object") {
                    it("does not saves new object and throw error") {
                        waitUntil(timeout: .seconds(1)) { done in
                            do {
                                try sut.saveToAPI(object) { _ in }
                            } catch {
                                expect(error).to(matchError(BeamObject.BeamObjectError.noEmail))
                                done()
                            }
                        }
                    }
                }
            }

            context("with async") {
                context("with new object") {
                    asyncIt("does not saves new object and throw error") {
                        do {
                            let _ = try await sut.saveToAPI(object)
                        } catch {
                            expect(error).to(matchError(BeamObject.BeamObjectError.noEmail))
                        }
                    }
                }
            }
        }

    }
}
