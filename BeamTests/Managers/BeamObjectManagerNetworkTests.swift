import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam
@testable import BeamCore

class BeamObjectManagerNetworkTests: QuickSpec {
    override func spec() {
        var sut: BeamObjectManager!
        let beamObjectHelper = BeamObjectTestsHelper()
        let beamHelper = BeamTestsHelper()

        beforeEach {
            // Need to freeze date to compare objects, as `createdAt` would be different from the network stubs we get
            // back from Vinyl
            BeamDate.freeze("2021-03-19T12:21:03Z")

            APIRequest.networkCallFiles = []

            sut = BeamObjectManager()
            BeamObjectManager.clearNetworkCalls()
            BeamTestsHelper.logout()

            beamHelper.beginNetworkRecording()

            BeamTestsHelper.login()

            BeamObjectManager.unregisterAll()
            MyRemoteObjectManager().registerOnBeamObjectManager()

            MyRemoteObjectManager.store.removeAll()

            try? EncryptionManager.shared.replacePrivateKey(Configuration.testPrivateKey)
        }

        afterEach {
            beamHelper.endNetworkRecording()

            BeamObjectManager.clearNetworkCalls()

            BeamDate.reset()
            // Sad: this is broken when using Vinyl
//            if !sut.isAllNetworkCallsCompleted() {
//                fail("not all network calls are completed")
//            }
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
                                            previousChecksum: nil,
                                            checksum: nil,
                                            title: title)

                _ = beamObjectHelper.saveOnAPI(object)
            }

            afterEach {
                let semaphore = DispatchSemaphore(value: 0)
                _ = try? sut.delete(uuid) { _ in
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
                }

                it("fetches all objects") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
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

        describe("saveAllToAPI()") {
            afterEach {
                let semaphore = DispatchSemaphore(value: 0)

                _ = try? BeamObjectRequest().deleteAll { _ in
                    semaphore.signal()
                }

                _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))
            }

            context("without content") {
                it("calls managers but no network calls as it's all empty") {
                    let networkCalls = APIRequest.callsCount

                    do {
                        try sut.saveAllToAPI()
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
                context("with non-existing object") {
                    it("returns 404") {
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                try sut.delete(uuid, raise404: true) { result in
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
                        let object = MyRemoteObject(beamObjectId: uuid,
                                                    createdAt: BeamDate.now,
                                                    updatedAt: BeamDate.now,
                                                    deletedAt: nil,
                                                    previousChecksum: nil,
                                                    checksum: nil,
                                                    title: title)
                        _ = beamObjectHelper.saveOnAPI(object)
                    }

                    it("returns object") {
                        var beamObject: BeamObject?
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                try sut.delete(uuid) { result in
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
        }

        describe("saveToAPI(beamObjects)") {
            var object: MyRemoteObject!
            var object2: MyRemoteObject!
            var objects: [MyRemoteObject] = []
            let title = "This is my title"
            let title2 = "This is my other title"
            let newTitle = "This is a new title"
            let newTitle2 = "This is a new title for other title"
            let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd38".uuid ?? UUID()
            let uuid2 = "995d94e1-e0df-4eca-93e6-8778984bcd39".uuid ?? UUID()

            beforeEach {
                object = MyRemoteObject(beamObjectId: uuid,
                                        createdAt: BeamDate.now,
                                        updatedAt: BeamDate.now,
                                        deletedAt: nil,
                                        previousChecksum: nil,
                                        checksum: nil,
                                        title: title)
                object2 = MyRemoteObject(beamObjectId: uuid2,
                                        createdAt: BeamDate.now,
                                        updatedAt: BeamDate.now,
                                        deletedAt: nil,
                                        previousChecksum: nil,
                                        checksum: nil,
                                        title: title2)
                objects.append(object)
            }

            afterEach {
                let semaphore = DispatchSemaphore(value: 0)
                _ = try? sut.delete(object.beamObjectId) { _ in
                    semaphore.signal()
                }

                _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))

                _ = try? sut.delete(object2.beamObjectId) { _ in
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

                        waitUntil(timeout: .seconds(10)) { done in
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

                        let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)
                        let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)

                        expect(object) == remoteObject1
                        expect(object2) == remoteObject2

                        // `previousChecksum` should be set on returned objects
                        let beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                        expect(returnedObjects.first?.previousChecksum) == beamObject.dataChecksum

                        let beamObject2 = try BeamObject(object2, MyRemoteObject.beamObjectTypeName)
                        expect(returnedObjects.last?.previousChecksum) == beamObject2.dataChecksum
                    }

                    it("saves new beam object") {
                        let networkCalls = APIRequest.callsCount

                        let beamObjects: [BeamObject] = [try BeamObject(object, MyRemoteObject.beamObjectTypeName),
                                                     try BeamObject(object2, MyRemoteObject.beamObjectTypeName)]

                        var returnedBeamObjects: [BeamObject] = []

                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.saveToAPI(beamObjects) { result in
                                    expect { returnedBeamObjects = try result.get() }.toNot(throwError())
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        expect(object) == (try beamObjectHelper.fetchOnAPI(object.beamObjectId))
                        expect(object2) == (try beamObjectHelper.fetchOnAPI(object2.beamObjectId))

                        // `previousChecksum` should be set on returned objects
                        expect(returnedBeamObjects.first?.previousChecksum) == beamObjects.first?.dataChecksum
                        expect(returnedBeamObjects.last?.previousChecksum) == beamObjects.last?.dataChecksum
                    }
                }

                context("with persisted object") {
                    var previousChecksum: String?
                    var previousChecksum2: String?

                    beforeEach {
                        let beamObject = beamObjectHelper.saveOnAPI(object)
                        previousChecksum = beamObject?.dataChecksum

                        let beamObject2 = beamObjectHelper.saveOnAPI(object2)
                        previousChecksum2 = beamObject2?.dataChecksum
                    }

                    context("with good previousChecksum") {
                        it("saves existing object") {
                            let networkCalls = APIRequest.callsCount
                            object.previousChecksum = previousChecksum
                            object.title = newTitle

                            object2.previousChecksum = previousChecksum2
                            object2.title = newTitle2

                            let objects: [MyRemoteObject] = [object, object2]
                            var returnedObjects: [MyRemoteObject] = []

                            waitUntil(timeout: .seconds(10)) { done in
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

                            expect(object) == (try beamObjectHelper.fetchOnAPI(object.beamObjectId))
                            expect(object2) == (try beamObjectHelper.fetchOnAPI(object2.beamObjectId))

                            let beamObject = try? BeamObject(object, MyRemoteObject.beamObjectTypeName)
                            expect(returnedObjects.first?.previousChecksum) == beamObject?.dataChecksum

                            let beamObject2 = try? BeamObject(object2, MyRemoteObject.beamObjectTypeName)
                            expect(returnedObjects.last?.previousChecksum) == beamObject2?.dataChecksum
                        }

                        it("saves existing beam object") {
                            let networkCalls = APIRequest.callsCount
                            object.previousChecksum = previousChecksum
                            object.title = newTitle

                            object2.previousChecksum = previousChecksum2
                            object2.title = newTitle2

                            let beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                            let beamObject2 = try BeamObject(object2, MyRemoteObject.beamObjectTypeName)
                            let beamObjects: [BeamObject] = [beamObject, beamObject2]
                            var returnedBeamObjects: [BeamObject] = []

                            waitUntil(timeout: .seconds(10)) { done in
                                do {
                                    _ = try sut.saveToAPI(beamObjects) { result in
                                        expect { returnedBeamObjects = try result.get() }.toNot(throwError())
                                        done()
                                    }
                                } catch {
                                    fail(error.localizedDescription)
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 1

                            expect(object) == (try beamObjectHelper.fetchOnAPI(object.beamObjectId))
                            expect(object2) == (try beamObjectHelper.fetchOnAPI(object2.beamObjectId))

                            // `previousChecksum` should be set on returned objects
                            expect(returnedBeamObjects.first?.previousChecksum) == beamObjects.first?.dataChecksum
                            expect(returnedBeamObjects.last?.previousChecksum) == beamObjects.last?.dataChecksum
                        }

                    }

                    context("with empty previousChecksum") {
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

                                waitUntil(timeout: .seconds(10)) { done in
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
                                                            Beam.Configuration.beamObjectDataOnSeparateCall ? "beam_objects_data_url" : "beam_objects",
                                                            "update_beam_objects"]

                                expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                expect(object) == (try beamObjectHelper.fetchOnAPI(object.beamObjectId))
                                expect(object2) == (try beamObjectHelper.fetchOnAPI(object2.beamObjectId))

                                let remoteObject = returnedObjects.first(where: { $0.beamObjectId == object.beamObjectId })
                                let remoteObject2 = returnedObjects.first(where: { $0.beamObjectId == object2.beamObjectId })

                                // `previousChecksum` should be set on returned objects
                                let beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                                let beamObject2 = try BeamObject(object2, MyRemoteObject.beamObjectTypeName)

                                expect(remoteObject?.previousChecksum) == beamObject.dataChecksum
                                expect(remoteObject2?.previousChecksum) == beamObject2.dataChecksum
                            }

                            it("updates object") {
                                let networkCalls = APIRequest.callsCount

                                let beamObjects: [BeamObject] = [try BeamObject(object, MyRemoteObject.beamObjectTypeName),
                                                                 try BeamObject(object2, MyRemoteObject.beamObjectTypeName)]
                                var returnedBeamObjects: [BeamObject] = []

                                waitUntil(timeout: .seconds(10)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObjects) { result in
                                            expect { returnedBeamObjects = try result.get() }.toNot(throwError())
                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 4

                                let fetchedObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)
                                let fetchedObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)

                                expect(object) == fetchedObject1
                                expect(object2) == fetchedObject2

                                let remoteBeamObject = returnedBeamObjects.first(where: { $0.id == object.beamObjectId })
                                let remoteBeamObject2 = returnedBeamObjects.first(where: { $0.id == object2.beamObjectId })

                                // `previousChecksum` should be set on returned objects
                                expect(remoteBeamObject?.previousChecksum) == beamObjects.first?.dataChecksum
                                expect(remoteBeamObject2?.previousChecksum) == beamObjects.last?.dataChecksum
                            }
                        }

                        context("with manual conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .fetchRemoteAndError }

                            it("raise error and return remote object") {
                                let networkCalls = APIRequest.callsCount

                                object.previousChecksum = try "wrong checksum".SHA256()
                                object.title = newTitle

                                object2.previousChecksum = try "wrong checksum".SHA256()
                                object2.title = newTitle2

                                let beamObjects: [MyRemoteObject] = [object, object2]
                                var remoteObjects: [MyRemoteObject] = []

                                waitUntil(timeout: .seconds(10)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObjects) { result in
                                            expect { try result.get() }.to(throwError { (error: BeamObjectManagerObjectError<MyRemoteObject>) in
                                                switch error {
                                                case .invalidChecksum(_, _, let remoteObjects1):
                                                    expect(remoteObjects1).to(haveCount(2))
                                                    remoteObjects = remoteObjects1
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
                                                            Beam.Configuration.beamObjectDataOnSeparateCall ? "beam_objects_data_url" : "beam_objects"]

                                expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                let remoteObject = remoteObjects.first(where: { $0.beamObjectId == object.beamObjectId })
                                let remoteObject2 = remoteObjects.first(where: { $0.beamObjectId == object2.beamObjectId })

                                expect(remoteObject) != object
                                expect(remoteObject2) != object2

                                expect(remoteObject?.beamObjectId) == object.beamObjectId
                                expect(remoteObject?.checksum) == previousChecksum
                                expect(remoteObject?.title) == title

                                expect(remoteObject2?.beamObjectId) == object2.beamObjectId
                                expect(remoteObject2?.title) == title2
                                expect(remoteObject2?.checksum) == previousChecksum2
                            }

                            it("raise error and return remote beam object") {
                                let networkCalls = APIRequest.callsCount

                                object.previousChecksum = try "wrong checksum".SHA256()
                                object.title = newTitle

                                object2.previousChecksum = try "wrong checksum".SHA256()
                                object2.title = newTitle2

                                let beamObjects: [BeamObject] = [try BeamObject(object, MyRemoteObject.beamObjectTypeName),
                                                                 try BeamObject(object2, MyRemoteObject.beamObjectTypeName)]
                                var remoteBeamObjects: [BeamObject] = []

                                waitUntil(timeout: .seconds(10)) { done in
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

                                // update_beam_object + beam_object + beam_object
                                expect(APIRequest.callsCount - networkCalls) == 3

                                let remoteBeamObject = remoteBeamObjects.first(where: { $0.id == object.beamObjectId })!
                                let remoteBeamObject2 = remoteBeamObjects.first(where: { $0.id == object2.beamObjectId })!

                                expect(remoteBeamObject.id) == object.beamObjectId
                                expect(remoteBeamObject.dataChecksum) == previousChecksum

                                let remoteObject: MyRemoteObject? = try remoteBeamObject.decodeBeamObject()
                                expect(remoteObject?.title) == title

                                expect(remoteBeamObject2.id) == object2.beamObjectId
                                expect(remoteBeamObject2.dataChecksum) == previousChecksum2

                                let remoteObject2: MyRemoteObject? = try remoteBeamObject2.decodeBeamObject()
                                expect(remoteObject2?.title) == title2
                            }
                        }
                    }

                    context("with incorrect previousChecksum") {
                        beforeEach {
                            BeamDate.travel(2)

                            object.previousChecksum = try? "wrong checksum".SHA256()
                            object2.previousChecksum = try? "wrong checksum".SHA256()

                            object.title = newTitle
                            object2.title = newTitle2

                            object.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now
                        }

                        context("with automatic conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .replace }

                            it("updates object") {

                                let networkCalls = APIRequest.callsCount

                                let objects: [MyRemoteObject] = [object, object2]
                                var returnedObjects: [MyRemoteObject] = []

                                waitUntil(timeout: .seconds(10)) { done in
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
                                                            Beam.Configuration.beamObjectDataOnSeparateCall ? "beam_objects_data_url" : "beam_objects",
                                                            "update_beam_objects"]

                                expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                expect(object) == (try beamObjectHelper.fetchOnAPI(object.beamObjectId))
                                expect(object2) == (try beamObjectHelper.fetchOnAPI(object2.beamObjectId))

                                let remoteObject = returnedObjects.first(where: { $0.beamObjectId == object.beamObjectId })
                                let remoteObject2 = returnedObjects.first(where: { $0.beamObjectId == object2.beamObjectId })

                                // `previousChecksum` should be set on returned objects
                                let beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                                let beamObject2 = try BeamObject(object2, MyRemoteObject.beamObjectTypeName)
                                expect(remoteObject?.previousChecksum) == beamObject.dataChecksum
                                expect(remoteObject2?.previousChecksum) == beamObject2.dataChecksum
                                
                            }

                            it("updates beam object") {
                                let networkCalls = APIRequest.callsCount

                                let beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                                let beamObject2 = try BeamObject(object2, MyRemoteObject.beamObjectTypeName)
                                let beamObjects: [BeamObject] = [beamObject, beamObject2]
                                var returnedBeamObjects: [BeamObject] = []

                                waitUntil(timeout: .seconds(10)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObjects) { result in
                                            expect { returnedBeamObjects = try result.get() }.toNot(throwError())
                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 4

                                expect(object) == (try beamObjectHelper.fetchOnAPI(object.beamObjectId))
                                expect(object2) == (try beamObjectHelper.fetchOnAPI(object2.beamObjectId))

                                let remoteBeamObject = returnedBeamObjects.first(where: { $0.id == object.beamObjectId })
                                let remoteBeamObject2 = returnedBeamObjects.first(where: { $0.id == object2.beamObjectId })

                                // `previousChecksum` should be set on returned objects
                                expect(remoteBeamObject?.previousChecksum) == beamObject.dataChecksum
                                expect(remoteBeamObject2?.previousChecksum) == beamObject2.dataChecksum
                            }

                        }

                        context("with manual conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .fetchRemoteAndError }

                            it("raise error and return remote object") {
                                let networkCalls = APIRequest.callsCount

                                object.previousChecksum = try "wrong checksum".SHA256()
                                object.title = newTitle

                                object2.previousChecksum = try "wrong checksum".SHA256()
                                object2.title = newTitle2

                                let beamObjects: [MyRemoteObject] = [object, object2]
                                var remoteObjects: [MyRemoteObject] = []

                                waitUntil(timeout: .seconds(10)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObjects) { result in
                                            expect { try result.get() }.to(throwError { (error: BeamObjectManagerObjectError<MyRemoteObject>) in
                                                switch error {
                                                case .invalidChecksum(_, _, let remoteObjects1):
                                                    expect(remoteObjects1).to(haveCount(2))
                                                    remoteObjects = remoteObjects1
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
                                                            Beam.Configuration.beamObjectDataOnSeparateCall ? "beam_objects_data_url" : "beam_objects"]

                                expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                let remoteObject = remoteObjects.first(where: { $0.beamObjectId == object.beamObjectId })
                                let remoteObject2 = remoteObjects.first(where: { $0.beamObjectId == object2.beamObjectId })

                                expect(remoteObject) != object
                                expect(remoteObject2) != object2

                                expect(remoteObject?.beamObjectId) == object.beamObjectId
                                expect(remoteObject?.checksum) == previousChecksum
                                expect(remoteObject?.title) == title

                                expect(remoteObject2?.beamObjectId) == object2.beamObjectId
                                expect(remoteObject2?.title) == title2
                                expect(remoteObject2?.checksum) == previousChecksum2
                            }

                            it("raise error and return remote beam object") {
                                let networkCalls = APIRequest.callsCount

                                object.previousChecksum = try "wrong checksum".SHA256()
                                object.title = newTitle

                                object2.previousChecksum = try "wrong checksum".SHA256()
                                object2.title = newTitle2

                                let beamObjects: [BeamObject] = [try BeamObject(object, MyRemoteObject.beamObjectTypeName),
                                                                 try BeamObject(object2, MyRemoteObject.beamObjectTypeName)]
                                var remoteBeamObjects: [BeamObject] = []

                                waitUntil(timeout: .seconds(10)) { done in
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

                                // update_beam_object + beam_object + beam_object
                                expect(APIRequest.callsCount - networkCalls) == 3

                                let remoteBeamObject = remoteBeamObjects.first(where: { $0.id == object.beamObjectId })!
                                let remoteBeamObject2 = remoteBeamObjects.first(where: { $0.id == object2.beamObjectId })!

                                expect(remoteBeamObject.id) == object.beamObjectId
                                expect(remoteBeamObject.dataChecksum) == previousChecksum

                                let remoteObject: MyRemoteObject? = try remoteBeamObject.decodeBeamObject()
                                expect(remoteObject?.title) == title

                                expect(remoteBeamObject2.id) == object2.beamObjectId
                                expect(remoteBeamObject2.dataChecksum) == previousChecksum2

                                let remoteObject2: MyRemoteObject? = try remoteBeamObject2.decodeBeamObject()
                                expect(remoteObject2?.title) == title2
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
                                        previousChecksum: nil,
                                        checksum: nil,
                                        title: title)
            }

            afterEach {
                let semaphore = DispatchSemaphore(value: 0)
                _ = try? sut.delete(object.beamObjectId) { _ in
                    semaphore.signal()
                }

                _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))
            }

            context("with Foundation") {
                context("with new object") {
                    it("saves new object") {
                        let networkCalls = APIRequest.callsCount
                        var returnedObject: MyRemoteObject?

                        waitUntil(timeout: .seconds(10)) { done in
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

                        expect(object) == (try beamObjectHelper.fetchOnAPI(object.beamObjectId))

                        // `previousChecksum` should be set on returned object
                        let beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                        expect(returnedObject?.previousChecksum) == beamObject.dataChecksum
                    }

                    it("saves new beam object") {
                        let networkCalls = APIRequest.callsCount

                        let beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                        var returnedBeamObject: BeamObject?

                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.saveToAPI(beamObject) { result in
                                    expect { returnedBeamObject = try result.get() }.toNot(throwError())
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        expect(object) == (try beamObjectHelper.fetchOnAPI(object.beamObjectId))

                        // `previousChecksum` should be set on returned object
                        expect(returnedBeamObject?.previousChecksum) == beamObject.dataChecksum
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
                            object.previousChecksum = previousChecksum
                            object.title = newTitle
                        }

                        it("saves existing object") {
                            let networkCalls = APIRequest.callsCount

                            var returnedObject: MyRemoteObject?

                            waitUntil(timeout: .seconds(10)) { done in
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

                            expect(try beamObjectHelper.fetchOnAPI(object.beamObjectId)) == object

                            // `previousChecksum` should be set on returned object
                            let beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                            expect(returnedObject?.previousChecksum) == beamObject.dataChecksum
                        }

                        it("saves existing object") {
                            let networkCalls = APIRequest.callsCount

                            let beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                            var returnedBeamObject: BeamObject?

                            waitUntil(timeout: .seconds(10)) { done in
                                do {
                                    _ = try sut.saveToAPI(beamObject) { result in
                                        expect { returnedBeamObject = try result.get() }.toNot(throwError())
                                        done()
                                    }
                                } catch {
                                    fail(error.localizedDescription)
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 1

                            expect(object) == (try beamObjectHelper.fetchOnAPI(object.beamObjectId))

                            // `previousChecksum` should be set on returned object
                            expect(returnedBeamObject?.previousChecksum) == beamObject.dataChecksum
                        }
                    }

                    context("with empty previousChecksum") {
                        beforeEach {
                            BeamDate.travel(2)

                            object.title = newTitle
                            object.updatedAt = BeamDate.now
                        }

                        context("with automatic conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .replace }

                            it("updates object") {
                                let networkCalls = APIRequest.callsCount
                                var returnedObject: MyRemoteObject?

                                waitUntil(timeout: .seconds(10)) { done in
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

                                expect(object) == (try beamObjectHelper.fetchOnAPI(object.beamObjectId))

                                // `previousChecksum` should be set on returned object
                                let beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                                expect(returnedObject?.previousChecksum) == beamObject.dataChecksum
                            }

                            it("updates beam object") {
                                let networkCalls = APIRequest.callsCount

                                let beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                                var returnedBeamObject: BeamObject?

                                waitUntil(timeout: .seconds(10)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObject) { result in
                                            expect { returnedBeamObject = try result.get() }.toNot(throwError())
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
                                                                        "beam_object", "update_beam_object"]

                                expect(object) == (try beamObjectHelper.fetchOnAPI(object.beamObjectId))

                                // `previousChecksum` should be set on returned object
                                expect(returnedBeamObject?.previousChecksum) == beamObject.dataChecksum
                            }
                        }

                        context("with manual conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .fetchRemoteAndError }

                            it("raise error and return remote object") {
                                let networkCalls = APIRequest.callsCount

                                object.previousChecksum = try "wrong checksum".SHA256()
                                object.title = newTitle

                                var remoteObject: MyRemoteObject?

                                waitUntil(timeout: .seconds(10)) { done in
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
                                expect(remoteObject?.checksum) == previousChecksum
                                expect(remoteObject?.title) == title
                            }

                            it("raise error and return remote object") {
                                let networkCalls = APIRequest.callsCount

                                object.previousChecksum = try "wrong checksum".SHA256()
                                object.title = newTitle

                                let beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                                var remoteBeamObject: BeamObject?

                                waitUntil(timeout: .seconds(10)) { done in
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

                            object.previousChecksum = try? "wrong checksum".SHA256()
                            object.title = newTitle
                            object.updatedAt = BeamDate.now
                        }

                        context("with automatic conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .replace }

                            it("updates object") {
                                let networkCalls = APIRequest.callsCount

                                var returnedObject: MyRemoteObject?

                                waitUntil(timeout: .seconds(10)) { done in
                                    do {
                                        _ = try sut.saveToAPI(object) { result in
                                            expect { try returnedObject = result.get() }.toNot(throwError())
                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 3

                                expect(object) == (try beamObjectHelper.fetchOnAPI(object.beamObjectId))

                                // `previousChecksum` should be set on returned object
                                let beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                                expect(returnedObject?.previousChecksum) == beamObject.dataChecksum
                            }

                            it("updates beam object") {
                                let networkCalls = APIRequest.callsCount

                                let beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                                var returnedBeamObject: BeamObject?

                                waitUntil(timeout: .seconds(10)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObject) { result in
                                            expect { returnedBeamObject = try result.get() }.toNot(throwError())
                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 3

                                expect(object) == (try beamObjectHelper.fetchOnAPI(object.beamObjectId))

                                // `previousChecksum` should be set on returned object
                                expect(returnedBeamObject?.previousChecksum) == beamObject.dataChecksum
                            }
                        }

                        context("with manual conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .fetchRemoteAndError }

                            it("raise error and return remote object") {
                                let networkCalls = APIRequest.callsCount

                                object.previousChecksum = try "wrong checksum".SHA256()
                                object.title = newTitle

                                var remoteObject: MyRemoteObject?

                                waitUntil(timeout: .seconds(10)) { done in
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
                                expect(remoteObject?.checksum) == previousChecksum
                                expect(remoteObject?.title) == title
                            }

                            it("raise error and return remote object") {
                                let networkCalls = APIRequest.callsCount

                                object.previousChecksum = try "wrong checksum".SHA256()
                                object.title = newTitle

                                let beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                                var remoteBeamObject: BeamObject?

                                waitUntil(timeout: .seconds(10)) { done in
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
        }
    }
}
