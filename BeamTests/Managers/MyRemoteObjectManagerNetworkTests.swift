import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine
import BeamCore

@testable import Beam

class MyRemoteObjectManagerNetworkTests: QuickSpec {
    override func spec() {
        var sut: MyRemoteObjectManager!
        let beamObjectHelper = BeamObjectTestsHelper()
        let fixedDate = "2021-03-19T12:21:03Z"
        let beamHelper = BeamTestsHelper()

        beforeEach {
            BeamDate.freeze(fixedDate)

            sut = MyRemoteObjectManager()
            BeamTestsHelper.logout()

            APIRequest.networkCallFiles = []
            beamHelper.beginNetworkRecording()

            BeamTestsHelper.login()

            Configuration.beamObjectAPIEnabled = true

            BeamObjectManager.unRegisterAll()
            sut.registerOnBeamObjectManager()

            MyRemoteObjectManager.store.removeAll()

            try? EncryptionManager.shared.replacePrivateKey("j6tifPZTjUtGoz+1RJkO8dOMlu48MUUSlwACw/fCBw0=")
        }

        afterEach {
            beamHelper.endNetworkRecording()

            Configuration.beamObjectAPIEnabled = EnvironmentVariables.beamObjectAPIEnabled
        }

        describe("saveAllOnBeamObjectApi()") {
            beforeEach {
                self.createObjects()
            }

            afterEach {
                self.deleteAll()
            }

            context("when objects don't exist on the API") {
                it("saves all objects") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        do {
                            _ = try sut.saveAllOnBeamObjectApi { result in
                                expect { try result.get() }.toNot(throwError())

                                done()
                            }
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }

                    expect(APIRequest.callsCount - networkCalls) == 1
                    expect(APIRequest.networkCallFiles) == ["sign_in", "update_beam_objects"]

                    for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                        let object = MyRemoteObjectManager.store[key]
                        expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                    }
                }

                it("stores previousChecksum") {
                    for (_, object) in MyRemoteObjectManager.store {
                        expect(object.previousChecksum).to(beNil())
                    }

                    waitUntil(timeout: .seconds(10)) { done in
                        do {
                            _ = try sut.saveOnBeamObjectsAPI(Array(MyRemoteObjectManager.store.values)) { result in
                                expect { try result.get() }.toNot(throwError())

                                done()
                            }
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }

                    for (_, object) in MyRemoteObjectManager.store {
                        expect(object.previousChecksum).toNot(beNil())
                    }
                }
            }

            context("when objects already exist on the API") {
                beforeEach {
                    self.saveAllObjectsAndSaveChecksum()
                }

                // TODO add tests
            }
        }

        describe("saveOnBeamObjectsAPI()") {
            var object1: MyRemoteObject!
            var object2: MyRemoteObject!
            var object3: MyRemoteObject!

            var title1: String!
            var title2: String!
            var title3: String!

            beforeEach {
                self.createObjects()

                let values = Array(MyRemoteObjectManager.store.values)

                object1 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "195d94e1-e0df-4eca-93e6-8778984bcd58" })
                title1 = object1.title!
                object2 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "295d94e1-e0df-4eca-93e6-8778984bcd58" })
                title2 = object2.title!
                object3 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "395d94e1-e0df-4eca-93e6-8778984bcd58" })
                title3 = object3.title!
            }

            afterEach {
                self.deleteAll()
            }

            context("when objects don't exist on the API") {
                it("saves all objects") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        do {
                            _ = try sut.saveOnBeamObjectsAPI(Array(MyRemoteObjectManager.store.values)) { result in
                                expect { try result.get() }.toNot(throwError())

                                done()
                            }
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }

                    expect(APIRequest.callsCount - networkCalls) == 1
                    expect(APIRequest.networkCallFiles) == ["sign_in", "update_beam_objects"]

                    let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1.beamObjectId)
                    let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                    let remoteObject3: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object3.beamObjectId)

                    let values = Array(MyRemoteObjectManager.store.values)
                    let newObject1 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "195d94e1-e0df-4eca-93e6-8778984bcd58" })
                    let newObject2 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "295d94e1-e0df-4eca-93e6-8778984bcd58" })
                    let newObject3 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "395d94e1-e0df-4eca-93e6-8778984bcd58" })

                    expect(newObject1) == remoteObject1
                    expect(newObject2) == remoteObject2
                    expect(newObject3) == remoteObject3

                    expect(remoteObject1?.checksum) == (try self.checksum(object1))
                    expect(remoteObject2?.checksum) == (try self.checksum(object2))
                    expect(remoteObject3?.checksum) == (try self.checksum(object3))
                }

                it("stores previousChecksum") {
                    for (_, object) in MyRemoteObjectManager.store {
                        expect(object.previousChecksum).to(beNil())
                    }

                    waitUntil(timeout: .seconds(10)) { done in
                        do {
                            _ = try sut.saveOnBeamObjectsAPI(Array(MyRemoteObjectManager.store.values)) { result in
                                expect { try result.get() }.toNot(throwError())

                                done()
                            }
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }

                    let values = Array(MyRemoteObjectManager.store.values)
                    let newObject1 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "195d94e1-e0df-4eca-93e6-8778984bcd58" })
                    let newObject2 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "295d94e1-e0df-4eca-93e6-8778984bcd58" })
                    let newObject3 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "395d94e1-e0df-4eca-93e6-8778984bcd58" })

                    expect(newObject1?.previousChecksum) == (try self.checksum(object1))
                    expect(newObject2?.previousChecksum) == (try self.checksum(object2))
                    expect(newObject3?.previousChecksum) == (try self.checksum(object3))

                    expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                    expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                    expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                }
            }

            context("when all objects already exist, and we save all with 1 conflicted object") {
                let newTitle1 = "new Title1"

                beforeEach {
                    self.saveAllObjectsAndSaveChecksum()

                    let values = Array(MyRemoteObjectManager.store.values)
                    object1 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "195d94e1-e0df-4eca-93e6-8778984bcd58" })
                    title1 = object1.title!
                    object2 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "295d94e1-e0df-4eca-93e6-8778984bcd58" })
                    title2 = object2.title!
                    object3 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "395d94e1-e0df-4eca-93e6-8778984bcd58" })
                    title3 = object3.title!

                    // Create 1 conflicted object
                    object1.previousChecksum = "00a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"

                    object1.title = newTitle1
                }

                context("with replace policy") {
                    it("saves all objects with their new content") {
                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(1800)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3]) { result in
                                    expect { try result.get() }.toNot(throwError())

                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        let expectedNetworkCalls = ["update_beam_objects",
                                                    "beam_object",
                                                    "update_beam_object"]

                        expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count
                        expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                        let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1.beamObjectId)
                        expect(object1) == remoteObject1

                        let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                        expect(object2) == remoteObject2

                        let remoteObject3: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object3.beamObjectId)
                        expect(object3) == remoteObject3

                        expect(remoteObject1?.checksum) == (try self.checksum(object1))
                        expect(remoteObject2?.checksum) == (try self.checksum(object2))
                        expect(remoteObject3?.checksum) == (try self.checksum(object3))
                    }

                    it("stores all objects previousChecksum with their new content") {
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3]) { result in
                                    expect { try result.get() }.toNot(throwError())

                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                        expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                        expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                    }
                }

                context("with fetch and raise error policy") {
                    it("saves objects") {
                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3], .fetchRemoteAndError) { result in
                                    expect { try result.get() }.toNot(throwError())

                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        let expectedNetworkCalls = ["update_beam_objects",
                                                    "beam_object",
                                                    "update_beam_objects"]

                        expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count
                        expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                        var expectedResult1 = object1.copy()
                        expectedResult1.title = "merged: \(newTitle1)\(title1!)"

                        let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1.beamObjectId)
                        expect(expectedResult1) == remoteObject1

                        let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                        expect(object2) == remoteObject2

                        expect(remoteObject1?.checksum) == (try self.checksum(expectedResult1))
                        expect(remoteObject2?.checksum) == (try self.checksum(object2))
                    }

                    it("stores previousChecksum") {
                        waitUntil(timeout: .seconds(1800)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3], .fetchRemoteAndError) { result in
                                    expect { try result.get() }.toNot(throwError())

                                    if let objects = try? result.get() {
                                        Logger.shared.logDebug("⚠️ received objects:", category: .beamObjectNetwork)
                                        dump(objects)
                                    }
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        var expectedResult1 = object1.copy()
                        expectedResult1.title = "merged: \(newTitle1)\(title1!)"

                        expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(expectedResult1))
                        expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                    }
                }
            }

            context("when all objects exist, and with save with multiple conflicted object") {
                let newTitle1 = "new Title1"
                let newTitle2 = "new Title2"

                beforeEach {
                    self.saveAllObjectsAndSaveChecksum()

                    let values = Array(MyRemoteObjectManager.store.values)
                    object1 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "195d94e1-e0df-4eca-93e6-8778984bcd58" })
                    title1 = object1.title!
                    object2 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "295d94e1-e0df-4eca-93e6-8778984bcd58" })
                    title2 = object2.title!
                    object3 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "395d94e1-e0df-4eca-93e6-8778984bcd58" })
                    title3 = object3.title!

                    // Create 2 conflicted objects
                    object1.previousChecksum = "00a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"
                    object2.previousChecksum = "11a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb11"

                    object1.title = newTitle1
                    object2.title = newTitle2
                }

                context("with replace policy") {
                    it("saves objects with their new content") {
                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3]) { result in
                                    expect { try result.get() }.toNot(throwError())

                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 4
                        expect(APIRequest.networkCallFiles) == ["sign_in",
                                                                "update_beam_object",
                                                                "update_beam_object",
                                                                "update_beam_object",
                                                                "update_beam_objects",
                                                                "beam_object",
                                                                "beam_object",
                                                                "update_beam_objects"]

                        let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1.beamObjectId)
                        expect(object1) == remoteObject1

                        let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                        expect(object2) == remoteObject2

                        let remoteObject3: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object3.beamObjectId)
                        expect(object3) == remoteObject3

                        expect(remoteObject1?.checksum) == (try self.checksum(object1))
                        expect(remoteObject2?.checksum) == (try self.checksum(object2))
                        expect(remoteObject3?.checksum) == (try self.checksum(object3))
                    }

                    it("stores all objects previousChecksum with their new content") {
                        waitUntil(timeout: .seconds(1800)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3]) { result in
                                    expect { try result.get() }.toNot(throwError())

                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                        expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                        expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                    }
                }

                context("with fetch and raise error policy") {
                    it("saves all objects with merged content") {
                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(1800)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3], .fetchRemoteAndError) { result in
                                    expect { try result.get() }.toNot(throwError())

                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 4
                        expect(APIRequest.networkCallFiles) == ["sign_in",
                                                                "update_beam_object",
                                                                "update_beam_object",
                                                                "update_beam_object",
                                                                "update_beam_objects",
                                                                "beam_object",
                                                                "beam_object",
                                                                "update_beam_objects"]

                        var expectedResult1 = object1.copy()
                        expectedResult1.title = "merged: \(newTitle1)\(title1!)"

                        var expectedResult2 = object2.copy()
                        expectedResult2.title = "merged: \(newTitle2)\(title2!)"

                        let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1.beamObjectId)
                        expect(expectedResult1) == remoteObject1

                        let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                        expect(expectedResult2) == remoteObject2

                        let remoteObject3: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object3.beamObjectId)
                        expect(object3) == remoteObject3

                        expect(remoteObject1?.checksum) == (try self.checksum(expectedResult1))
                        expect(remoteObject2?.checksum) == (try self.checksum(expectedResult2))
                        expect(remoteObject3?.checksum) == (try self.checksum(object3))
                    }

                    it("stores all objects previousChecksum with merged content") {
                        waitUntil(timeout: .seconds(1800)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3], .fetchRemoteAndError) { result in
                                    expect { try result.get() }.toNot(throwError())
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        var expectedResult1 = object1.copy()
                        expectedResult1.title = "merged: \(newTitle1)\(title1!)"

                        var expectedResult2 = object2.copy()
                        expectedResult2.title = "merged: \(newTitle2)\(title2!)"

                        expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(expectedResult1))
                        expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(expectedResult2))
                        expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                    }
                }
            }

            context("when all objects exist, and we save with all objects in conflict") {
                let newTitle1 = "new Title1"
                let newTitle2 = "new Title2"
                let newTitle3 = "new Title3"

                beforeEach {
                    self.saveAllObjectsAndSaveChecksum()

                    let values = Array(MyRemoteObjectManager.store.values)
                    object1 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "195d94e1-e0df-4eca-93e6-8778984bcd58" })
                    title1 = object1.title!
                    object2 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "295d94e1-e0df-4eca-93e6-8778984bcd58" })
                    title2 = object2.title!
                    object3 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "395d94e1-e0df-4eca-93e6-8778984bcd58" })
                    title3 = object3.title!

                    object1.previousChecksum = "11a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"
                    object2.previousChecksum = "22a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"
                    object3.previousChecksum = "33a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"
                }

                context("with replace policy") {
                    it("saves all objects with their new content") {
                        object1.title = newTitle1
                        object2.title = newTitle2
                        object3.title = newTitle3

                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3]) { result in
                                    expect { try result.get() }.toNot(throwError())

                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 5
                        expect(APIRequest.networkCallFiles) == ["sign_in",
                                                                "update_beam_object",
                                                                "update_beam_object",
                                                                "update_beam_object",
                                                                "update_beam_objects",
                                                                "beam_object",
                                                                "beam_object",
                                                                "beam_object",
                                                                "update_beam_objects"]

                        let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1.beamObjectId)
                        expect(object1) == remoteObject1

                        let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                        expect(object2) == remoteObject2

                        let remoteObject3: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object3.beamObjectId)
                        expect(object3) == remoteObject3

                        expect(remoteObject1?.checksum) == (try self.checksum(object1))
                        expect(remoteObject2?.checksum) == (try self.checksum(object2))
                        expect(remoteObject3?.checksum) == (try self.checksum(object3))
                    }

                    it("stores all objects previousChecksum with their new content") {
                        object1.title = newTitle1
                        object2.title = newTitle2
                        object3.title = newTitle3

                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3]) { result in
                                    expect { try result.get() }.toNot(throwError())

                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                        expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                        expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                    }
                }

                context("with fetch and raise error policy") {
                    it("saves all objects with merged content") {
                        object1.title = newTitle1
                        object2.title = newTitle2
                        object3.title = newTitle3

                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3], .fetchRemoteAndError) { result in
                                    expect { try result.get() }.toNot(throwError())

                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 5
                        expect(APIRequest.networkCallFiles) == ["sign_in",
                                                                "update_beam_object",
                                                                "update_beam_object",
                                                                "update_beam_object",
                                                                "update_beam_objects",
                                                                "beam_object",
                                                                "beam_object",
                                                                "beam_object",
                                                                "update_beam_objects"]

                        var expectedResult1 = object1.copy()
                        expectedResult1.title = "merged: \(newTitle1)\(title1!)"

                        var expectedResult2 = object2.copy()
                        expectedResult2.title = "merged: \(newTitle2)\(title2!)"

                        var expectedResult3 = object3.copy()
                        expectedResult3.title = "merged: \(newTitle3)\(title3!)"

                        let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1.beamObjectId)
                        expect(expectedResult1) == remoteObject1

                        let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                        expect(expectedResult2) == remoteObject2

                        let remoteObject3: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object3.beamObjectId)
                        expect(expectedResult3) == remoteObject3

                        expect(remoteObject1?.checksum) == (try self.checksum(expectedResult1))
                        expect(remoteObject2?.checksum) == (try self.checksum(expectedResult2))
                        expect(remoteObject3?.checksum) == (try self.checksum(expectedResult3))

                        expect(MyRemoteObjectManager.store[object1.beamObjectId]) == expectedResult1
                        expect(MyRemoteObjectManager.store[object2.beamObjectId]) == expectedResult2
                        expect(MyRemoteObjectManager.store[object3.beamObjectId]) == expectedResult3
                    }

                    it("stores all objects previousChecksum with merged content") {
                        expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                        expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                        expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))

                        object1.title = newTitle1
                        object2.title = newTitle2
                        object3.title = newTitle3

                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3], .fetchRemoteAndError) { result in
                                    expect { try result.get() }.toNot(throwError())

                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        var expectedResult1 = object1.copy()
                        expectedResult1.title = "merged: \(newTitle1)\(title1!)"

                        var expectedResult2 = object2.copy()
                        expectedResult2.title = "merged: \(newTitle2)\(title2!)"

                        var expectedResult3 = object3.copy()
                        expectedResult3.title = "merged: \(newTitle3)\(title3!)"

                        expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(expectedResult1))
                        expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(expectedResult2))
                        expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(expectedResult3))
                    }
                }
            }
        }

        describe("saveOnBeamObjectAPI()") {
            var object: MyRemoteObject!
            let title = "Object 1"

            beforeEach {
                object = MyRemoteObject(beamObjectId: "195d94e1-e0df-4eca-93e6-8778984bcd58".uuid ?? UUID(),
                                        createdAt: BeamDate.now,
                                        updatedAt: BeamDate.now,
                                        deletedAt: nil,
                                        previousChecksum: nil,
                                        checksum: nil,
                                        title: title)
                MyRemoteObjectManager.store[object.beamObjectId] = object
            }

            afterEach {
                self.deleteAll()
            }

            context("when object doesn't exist on the API") {
                it("saves new object") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        do {
                            _ = try sut.saveOnBeamObjectAPI(object) { result in
                                expect { try result.get() }.toNot(throwError())

                                done()
                            }
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }

                    expect(APIRequest.callsCount - networkCalls) == 1
                    expect(APIRequest.networkCallFiles) == ["sign_in", "update_beam_object"]

                    let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)
                    expect(object) == remoteObject

                    expect(remoteObject?.checksum) == (try self.checksum(object))
                    expect(MyRemoteObjectManager.store[object.beamObjectId]) == object
                }

                it("stores previousChecksum") {
                    expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum).to(beNil())

                    waitUntil(timeout: .seconds(10)) { done in
                        do {
                            _ = try sut.saveOnBeamObjectsAPI(Array(MyRemoteObjectManager.store.values)) { result in
                                expect { try result.get() }.toNot(throwError())

                                done()
                            }
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }

                    expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try self.checksum(object))
                }
            }

            context("when object already exist on the API") {
                beforeEach {
                    self.saveObjectAndSaveChecksum(object)
                }

                context("with conflict") {
                    let newTitle = "new Title"

                    beforeEach {
                        // Create 1 conflicted object
                        object.previousChecksum = "00a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"
                    }

                    context("with replace policy") {
                        it("saves object overwriting content") {
                            object.title = newTitle
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                do {
                                    _ = try sut.saveOnBeamObjectAPI(object) { result in
                                        expect { try result.get() }.toNot(throwError())

                                        done()
                                    }
                                } catch {
                                    fail(error.localizedDescription)
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 3
                            expect(APIRequest.networkCallFiles) == ["sign_in",
                                                                    "update_beam_object",
                                                                    "update_beam_object",
                                                                    "beam_object",
                                                                    "update_beam_object"]

                            let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)
                            expect(object) == remoteObject

                            expect(remoteObject?.checksum) == (try self.checksum(object))
                        }

                        it("stores previousChecksum with overwritten content") {
                            expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try self.checksum(object))

                            object.title = newTitle

                            waitUntil(timeout: .seconds(10)) { done in
                                do {
                                    _ = try sut.saveOnBeamObjectAPI(object) { result in
                                        expect { try result.get() }.toNot(throwError())

                                        done()
                                    }
                                } catch {
                                    fail(error.localizedDescription)
                                }
                            }

                            expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try self.checksum(object))
                        }
                    }

                    context("with fetch and raise error policy") {
                        it("saves object with merged content") {
                            object.title = newTitle
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                do {
                                    _ = try sut.saveOnBeamObjectAPI(object, .fetchRemoteAndError) { result in
                                        expect { try result.get() }.toNot(throwError())

                                        done()
                                    }
                                } catch {
                                    fail(error.localizedDescription)
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 3
                            expect(APIRequest.networkCallFiles) == ["sign_in",
                                                                    "update_beam_object",
                                                                    "update_beam_object",
                                                                    "beam_object",
                                                                    "update_beam_objects"]

                            var expectedResult = object.copy()
                            expectedResult.title = "merged: \(newTitle)\(title)"

                            let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)
                            expect(expectedResult) == remoteObject

                            expect(remoteObject?.checksum) == (try self.checksum(expectedResult))

                            expect(MyRemoteObjectManager.store[object.beamObjectId]) == expectedResult
                        }

                        it("stores previousChecksum based on merged content") {
                            expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try self.checksum(object))

                            object.title = newTitle

                            waitUntil(timeout: .seconds(10)) { done in
                                do {
                                    _ = try sut.saveOnBeamObjectAPI(object, .fetchRemoteAndError) { result in
                                        expect { try result.get() }.toNot(throwError())

                                        done()
                                    }
                                } catch {
                                    fail(error.localizedDescription)
                                }
                            }

                            var expectedResult = object.copy()
                            expectedResult.title = "merged: \(newTitle)\(title)"

                            expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try self.checksum(expectedResult))
                        }
                    }
                }
            }
        }
    }

    /// Create all objects and persist them locally
    @discardableResult
    private func createObjects() -> [MyRemoteObject] {
        let object1 = MyRemoteObject(beamObjectId: "195d94e1-e0df-4eca-93e6-8778984bcd58".uuid ?? UUID(),
                                     createdAt: BeamDate.now,
                                     updatedAt: BeamDate.now,
                                     deletedAt: nil,
                                     previousChecksum: nil,
                                     checksum: nil,
                                     title: "Object 1")

        let object2 = MyRemoteObject(beamObjectId: "295d94e1-e0df-4eca-93e6-8778984bcd58".uuid ?? UUID(),
                                     createdAt: BeamDate.now,
                                     updatedAt: BeamDate.now,
                                     deletedAt: nil,
                                     previousChecksum: nil,
                                     checksum: nil,
                                     title: "Object 2")

        let object3 = MyRemoteObject(beamObjectId: "395d94e1-e0df-4eca-93e6-8778984bcd58".uuid ?? UUID(),
                                     createdAt: BeamDate.now,
                                     updatedAt: BeamDate.now,
                                     deletedAt: nil,
                                     previousChecksum: nil,
                                     checksum: nil,
                                     title: "Object 3")

        MyRemoteObjectManager.store[object1.beamObjectId] = object1
        MyRemoteObjectManager.store[object2.beamObjectId] = object2
        MyRemoteObjectManager.store[object3.beamObjectId] = object3

        return [object1, object2, object3]
    }

    /// Returns the object's checksum
    private func checksum(_ object: MyRemoteObject) throws -> String {
        let jsonData = try BeamObject.encoder.encode(object)
        let result = jsonData.SHA256

        // Used when going deep in debug
//        if let string = jsonData.asString {
//            Logger.shared.logDebug("🍀 SHA checksum on \(string): \(result)", category: .beamObjectDebug)
//        }

        return result
    }

    /// Save objects on the API, and store its checksum
    private func saveObjectAndSaveChecksum(_ object: MyRemoteObject) {
        MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum = BeamObjectTestsHelper().saveOnAPI(object)?.dataChecksum
    }

    /// Save all objects on the API, and store their checksum
    private func saveAllObjectsAndSaveChecksum() {
        // Can't do `forEach` or vinyl and save will break it

        saveObjectAndSaveChecksum(MyRemoteObjectManager.store["195d94e1-e0df-4eca-93e6-8778984bcd58".uuid!]!)
        saveObjectAndSaveChecksum(MyRemoteObjectManager.store["295d94e1-e0df-4eca-93e6-8778984bcd58".uuid!]!)
        saveObjectAndSaveChecksum(MyRemoteObjectManager.store["395d94e1-e0df-4eca-93e6-8778984bcd58".uuid!]!)
    }

    /// Delete all beam objects
    private func deleteAll() {
        let semaphore = DispatchSemaphore(value: 0)

        _ = try? BeamObjectRequest().deleteAll { _ in
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))
        MyRemoteObjectManager.store.removeAll()
    }
}
