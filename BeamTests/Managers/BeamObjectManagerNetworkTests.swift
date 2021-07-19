import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine
import BeamCore

@testable import Beam

class BeamObjectManagerNetworkTests: QuickSpec {
    struct MyRemoteObject: BeamObjectProtocol {
        static var beamObjectTypeName = "my_remote_object"

        var beamObjectId = UUID()
        var createdAt = BeamDate.now
        var updatedAt = BeamDate.now
        var deletedAt: Date?
        var previousChecksum: String?
        var checksum: String?

        var title: String?
    }

    override func spec() {
        var sut: BeamObjectManager!
//        var helper: DocumentManagerTestsHelper!
        var beamObjectHelper: BeamObjectTestsHelper!
        let beamHelper = BeamTestsHelper()
        let beforeConfigApiHostname = Configuration.apiHostname

        beforeEach {
            Configuration.apiHostname = "http://api.beam.lvh.me:5000"

            sut = BeamObjectManager()
            beamObjectHelper = BeamObjectTestsHelper()

            sut.clearNetworkCalls()

//            beamHelper.beginNetworkRecording()

            BeamTestsHelper.login()

            Configuration.beamObjectAPIEnabled = true
        }

        afterEach {
//            beamHelper.endNetworkRecording()

            sut.clearNetworkCalls()

            Configuration.beamObjectAPIEnabled = EnvironmentVariables.beamObjectAPIEnabled
            Configuration.apiHostname = beforeConfigApiHostname
        }

        describe("syncAllFromAPI()") {
        }

        describe("fetchAllFromAPI()") {
            let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd58".uuid ?? UUID()
            let title = "my title"

            beforeEach {
                let object = MyRemoteObject(beamObjectId: uuid,
                                            createdAt: BeamDate.now,
                                            updatedAt: BeamDate.now,
                                            deletedAt: nil,
                                            previousChecksum: nil,
                                            checksum: nil,
                                            title: title)
                _ = beamObjectHelper.saveOnAPI(object)
                sleep(1)
            }

            afterEach {
                let semaphore = DispatchSemaphore(value: 0)
                try? sut.delete(uuid) { _ in
                    semaphore.signal()
                }

                _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))
                sleep(1)
            }

            context("without previous updated_at") {
                beforeEach {
                    Persistence.Sync.BeamObjects.updated_at = nil
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
                    expect(Persistence.Sync.BeamObjects.updated_at).toNot(beNil())
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
                sleep(1)
            }

            context("without content") {
                beforeEach {
                    try? Document.deleteWithPredicate(CoreDataManager.shared.mainContext)
                    try? Database.deleteWithPredicate(CoreDataManager.shared.mainContext)
                    try? PasswordsDB(path: BeamData.dataFolder(fileName: "passwords.db")).deleteAll()
                }

                it("calls managers but no network calls") {
                    let networkCalls = APIRequest.callsCount

                    try sut.saveAllToAPI()

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
                                try sut.delete(uuid) { result in
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
                        sleep(1)
                    }

                    it("returns object") {
                        var beamObject: BeamObject?
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                try sut.delete(uuid) { result in
                                    expect { beamObject = try result.get() }.toNot(throwError())

                                    expect(beamObject?.beamObjectId) == uuid
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
                try? sut.delete(object.beamObjectId) { _ in
                    semaphore.signal()
                }

                _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))

                try? sut.delete(object2.beamObjectId) { _ in
                    semaphore.signal()
                }

                _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))
                sleep(1)
            }

            context("with Foundation") {
                context("with new object") {
                    it("saves new object") {
                        let networkCalls = APIRequest.callsCount

                        let objects: [MyRemoteObject] = [object, object2]

                        waitUntil(timeout: .seconds(10)) { done in
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

                        expect(APIRequest.callsCount - networkCalls) == 1

                        var remoteObject: MyRemoteObject? = try? beamObjectHelper.fetchOnAPI(object.beamObjectId)

                        expect(remoteObject?.beamObjectId) == object.beamObjectId
                        expect(remoteObject?.title) == title

                        remoteObject = try? beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                        expect(remoteObject?.beamObjectId) == object2.beamObjectId
                        expect(remoteObject?.title) == title2
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

                    it("saves existing object with right checksum") {
                        let networkCalls = APIRequest.callsCount
                        object.previousChecksum = previousChecksum
                        object.title = newTitle

                        object2.previousChecksum = previousChecksum2
                        object2.title = newTitle2

                        let objects: [MyRemoteObject] = [object, object2]

                        waitUntil(timeout: .seconds(10)) { done in
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

                        expect(APIRequest.callsCount - networkCalls) == 1

                        var remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)

                        expect(remoteObject?.beamObjectId) == object.beamObjectId
                        expect(remoteObject?.title) == newTitle

                        var foo = try? BeamObject(object, MyRemoteObject.beamObjectTypeName)
                        try? foo?.encrypt()
                        expect(remoteObject?.checksum) == foo?.dataChecksum

                        remoteObject = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)

                        expect(remoteObject?.beamObjectId) == object2.beamObjectId
                        expect(remoteObject?.title) == newTitle2

                        foo = try? BeamObject(object2, MyRemoteObject.beamObjectTypeName)
                        try? foo?.encrypt()
                        expect(remoteObject?.checksum) == foo?.dataChecksum
                    }

                    context("with incorrect checksum") {
                        context("with automatic conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .replace }

                            fit("updates object with incorrect checksum") {
                                let networkCalls = APIRequest.callsCount
                                object.previousChecksum = try "wrong checksum".SHA256()
                                object.title = newTitle

                                object2.previousChecksum = try "wrong checksum".SHA256()
                                object2.title = newTitle2

                                let objects: [MyRemoteObject] = [object, object2]

                                waitUntil(timeout: .seconds(10)) { done in
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

                                // update_beam_object + beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 4

                                var remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)

                                expect(remoteObject?.beamObjectId) == object.beamObjectId
                                expect(remoteObject?.title) == newTitle

//                                var foo = try? BeamObject(object, MyRemoteObject.beamObjectTypeName)
//                                try? foo?.encrypt()
//                                expect(remoteObject?.checksum) == foo?.dataChecksum

                                remoteObject = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)

                                expect(remoteObject?.beamObjectId) == object2.beamObjectId
                                expect(remoteObject?.title) == newTitle2

//                                foo = try? BeamObject(object2, MyRemoteObject.beamObjectTypeName)
//                                try? foo?.encrypt()
//                                expect(remoteObject?.checksum) == foo?.dataChecksum
                            }

                            it("updates object with incorrect checksum") {
                                let networkCalls = APIRequest.callsCount
                                object.previousChecksum = try "wrong checksum".SHA256()
                                object.title = newTitle

                                object2.previousChecksum = try "wrong checksum".SHA256()
                                object2.title = newTitle2

                                var beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                                var beamObject2 = try BeamObject(object2, MyRemoteObject.beamObjectTypeName)
                                var beamObjects: [BeamObject] = [beamObject, beamObject2]

                                waitUntil(timeout: .seconds(10)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObjects) { result in
                                            expect { beamObjects = try result.get() }.toNot(throwError())
                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                beamObject = beamObjects.first ?? beamObject
                                beamObject2 = beamObjects.last ?? beamObject2

                                // update_beam_object + beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 4

                                var remoteBeamObject = beamObjectHelper.fetchOnAPI(object.beamObjectId)
                                var remoteObject: MyRemoteObject? = try remoteBeamObject?.decodeBeamObject()

                                expect(remoteObject?.beamObjectId) == object.beamObjectId
                                expect(remoteObject?.title) == newTitle
                                expect(remoteObject?.checksum) == beamObject.dataChecksum

                                remoteBeamObject = beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                                remoteObject = try remoteBeamObject?.decodeBeamObject()

                                expect(remoteObject?.beamObjectId) == object2.beamObjectId
                                expect(remoteObject?.title) == newTitle2
                                expect(remoteObject?.checksum) == beamObject2.dataChecksum
                            }

                            fit("updates object with empty checksum") {
                                let networkCalls = APIRequest.callsCount
                                object.title = newTitle
                                object2.title = newTitle2

                                let objects: [MyRemoteObject] = [object, object2]

                                waitUntil(timeout: .seconds(10)) { done in
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

                                // update_beam_object + beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 4

                                var remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)

                                expect(remoteObject?.beamObjectId) == object.beamObjectId
                                expect(remoteObject?.title) == newTitle
//                                expect(remoteObject?.checksum) == beamObject.dataChecksum

                                remoteObject = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)

                                expect(remoteObject?.beamObjectId) == object2.beamObjectId
                                expect(remoteObject?.title) == newTitle2
//                                expect(remoteObject?.checksum) == beamObject2.dataChecksum
                            }

                            it("updates object with empty checksum") {
                                let networkCalls = APIRequest.callsCount
                                object.title = newTitle
                                object2.title = newTitle2

                                var beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)
                                var beamObject2 = try BeamObject(object2, MyRemoteObject.beamObjectTypeName)
                                var beamObjects: [BeamObject] = [beamObject, beamObject2]

                                waitUntil(timeout: .seconds(10)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObjects) { result in
                                            expect { beamObjects = try result.get() }.toNot(throwError())
                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                beamObject = beamObjects.first ?? beamObject
                                beamObject2 = beamObjects.last ?? beamObject2

                                // update_beam_object + beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 4

                                var remoteBeamObject = beamObjectHelper.fetchOnAPI(object.beamObjectId)
                                var remoteObject: MyRemoteObject? = try remoteBeamObject?.decodeBeamObject()

                                expect(remoteObject?.beamObjectId) == object.beamObjectId
                                expect(remoteObject?.title) == newTitle
                                expect(remoteObject?.checksum) == beamObject.dataChecksum

                                remoteBeamObject = beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                                remoteObject = try remoteBeamObject?.decodeBeamObject()

                                expect(remoteObject?.beamObjectId) == object2.beamObjectId
                                expect(remoteObject?.title) == newTitle2
                                expect(remoteObject?.checksum) == beamObject2.dataChecksum
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
                                var remoteBeamObject: MyRemoteObject?
                                var remoteBeamObject2: MyRemoteObject?

                                waitUntil(timeout: .seconds(10)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObjects) { result in
                                            expect { try result.get() }.to(throwError { (error: BeamObjectManagerError) in
                                                switch error {
                                                case .multipleErrors(let errors):
                                                    expect(errors).to(haveCount(2))

                                                    guard let error1 = errors.first,
                                                          case BeamObjectManagerObjectError<MyRemoteObject>.beamObjectInvalidChecksum(let remoteObject) = error1,
                                                          let error2 = errors.last,
                                                          case BeamObjectManagerObjectError<MyRemoteObject>.beamObjectInvalidChecksum(let remoteObject2) = error2
                                                          else {
                                                        fail("Failed for error type")
                                                        return
                                                    }

                                                    remoteBeamObject = remoteObject
                                                    remoteBeamObject2 = remoteObject2
                                                default:
                                                    fail("Expecting beamObjectInvalidChecksum error")
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

                                expect(remoteBeamObject?.beamObjectId) == object.beamObjectId
                                expect(remoteBeamObject?.checksum) == previousChecksum
                                expect(remoteBeamObject?.title) == title

                                expect(remoteBeamObject2?.beamObjectId) == object2.beamObjectId
                                expect(remoteBeamObject2?.title) == title2
                                expect(remoteBeamObject2?.checksum) == previousChecksum2
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
                try? sut.delete(object.beamObjectId) { _ in
                    semaphore.signal()
                }

                _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))
                sleep(1)
            }

            context("with Foundation") {
                context("with new object") {
                    it("saves new object") {
                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(10)) { done in
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

                        expect(APIRequest.callsCount - networkCalls) == 1

                        let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)
                        expect(remoteObject?.beamObjectId) == object.beamObjectId
                        expect(remoteObject?.title) == title
                    }
                }

                context("with persisted object") {
                    var previousChecksum: String?

                    beforeEach {
                        let beamObject = beamObjectHelper.saveOnAPI(object)
                        previousChecksum = beamObject?.dataChecksum
                    }

                    it("saves existing object with right checksum") {
                        let networkCalls = APIRequest.callsCount
                        object.previousChecksum = previousChecksum
                        object.title = newTitle

                        let beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)

                        waitUntil(timeout: .seconds(10)) { done in
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

                        let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)

                        expect(remoteObject?.beamObjectId) == object.beamObjectId
                        expect(remoteObject?.title) == newTitle
                        expect(remoteObject?.checksum) == beamObject.dataChecksum
                    }

                    context("with incorrect checksum") {
                        context("with automatic conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .replace }

                            it("updates object with incorrect checksum") {
                                let networkCalls = APIRequest.callsCount
                                object.previousChecksum = try "wrong checksum".SHA256()
                                object.title = newTitle

                                var beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)

                                waitUntil(timeout: .seconds(10)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObject) { result in
                                            expect { beamObject = try result.get() }.toNot(throwError())
                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 3

                                let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)

                                expect(remoteObject?.beamObjectId) == object.beamObjectId
                                expect(remoteObject?.title) == newTitle
                                expect(remoteObject?.checksum) == beamObject.dataChecksum
                            }

                            it("updates object with empty checksum") {
                                let networkCalls = APIRequest.callsCount
                                object.title = newTitle

                                var beamObject = try BeamObject(object, MyRemoteObject.beamObjectTypeName)

                                waitUntil(timeout: .seconds(10)) { done in
                                    do {
                                        _ = try sut.saveToAPI(beamObject) { result in
                                            expect { beamObject = try result.get() }.toNot(throwError())
                                            done()
                                        }
                                    } catch {
                                        fail(error.localizedDescription)
                                        done()
                                    }
                                }

                                // update_beam_object + beam_object + update_beam_object
                                expect(APIRequest.callsCount - networkCalls) == 3

                                let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)

                                expect(remoteObject?.beamObjectId) == object.beamObjectId
                                expect(remoteObject?.title) == newTitle
                                expect(remoteObject?.checksum) == beamObject.dataChecksum
                            }
                        }

                        context("with manual conflict management") {
                            beforeEach { sut.conflictPolicyForSave = .fetchRemoteAndError }

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
                                                case .beamObjectInvalidChecksum(let remoteObject):
                                                    remoteBeamObject = remoteObject
                                                default:
                                                    fail("Expecting beamObjectInvalidChecksum error")
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

                                expect(remoteBeamObject?.beamObjectId) == object.beamObjectId
                                expect(remoteBeamObject?.dataChecksum) == previousChecksum

                                let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)
                                expect(remoteObject?.beamObjectId) == object.beamObjectId
                                expect(remoteObject?.title) == title
                                expect(remoteObject?.checksum) == previousChecksum
                            }
                        }
                    }
                }
            }
        }
    }
}
