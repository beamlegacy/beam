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
//            self.deleteAll()
        }

        afterEach {
            beamHelper.endNetworkRecording()

            Configuration.beamObjectAPIEnabled = EnvironmentVariables.beamObjectAPIEnabled
        }

        describe("saveAllOnBeamObjectApi()") {
            beforeEach {
                self.createObjects()
//                APIRequest.networkCallFiles = []
            }

            afterEach {
                self.deleteAll()
            }

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

                for (key, object) in MyRemoteObjectManager.store {
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

        describe("saveOnBeamObjectsAPI()") {
            var object1: MyRemoteObject!
            var object2: MyRemoteObject!
            var title1: String!
            var title2: String!

            beforeEach {
                self.createObjects()

                let values = Array(MyRemoteObjectManager.store.values)

                object1 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "195d94e1-e0df-4eca-93e6-8778984bcd58" })
                title1 = object1.title!
                object2 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "295d94e1-e0df-4eca-93e6-8778984bcd58" })
                title2 = object2.title!

//                APIRequest.networkCallFiles = []
            }

            afterEach {
                self.deleteAll()
            }

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

                let values = Array(MyRemoteObjectManager.store.values)
                let newObject1 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "195d94e1-e0df-4eca-93e6-8778984bcd58" })
                let newObject2 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "295d94e1-e0df-4eca-93e6-8778984bcd58" })

                expect(newObject1) == remoteObject1
                expect(newObject2) == remoteObject2

                expect(remoteObject1?.checksum) == (try self.checksum(object1))
                expect(remoteObject2?.checksum) == (try self.checksum(object2))
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

                expect(newObject1?.previousChecksum) == (try self.checksum(object1))
                expect(newObject2?.previousChecksum) == (try self.checksum(object2))

                expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
            }

            context("with 1 conflicted object") {
                let newTitle1 = "new Title1"

                beforeEach {
                    MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum = beamObjectHelper.saveOnAPI(object1)?.dataChecksum

                    // Create 1 conflicted object
                    object1.title = newTitle1
                    object1.previousChecksum = "00a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"
                }

                context("with replace policy") {
                    it("saves objects") {
                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2]) { result in
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
                                                                "update_beam_objects",
                                                                "beam_object",
                                                                "update_beam_object"]

                        let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1.beamObjectId)
                        expect(object1) == remoteObject1

                        let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                        expect(object2) == remoteObject2

                        expect(remoteObject1?.checksum) == (try self.checksum(object1))
                        expect(remoteObject2?.checksum) == (try self.checksum(object2))
                    }

                    it("stores previousChecksum") {
                        waitUntil(timeout: .seconds(1800)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2]) { result in
                                    expect { try result.get() }.toNot(throwError())

                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                        expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                    }
                }

                context("with fetch and raise error policy") {
                    it("saves objects") {
                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(1800)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2], .fetchRemoteAndError) { result in
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
                                                                "update_beam_objects",
                                                                "beam_object",
                                                                "update_beam_objects"]

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
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2], .fetchRemoteAndError) { result in
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

            context("with multiple conflicted object") {
                let newTitle1 = "new Title1"
                let newTitle2 = "new Title2"
                var object3: MyRemoteObject!

                beforeEach {
                    let values = Array(MyRemoteObjectManager.store.values)

                    object3 = values.first(where: { $0.beamObjectId.uuidString.lowercased() == "395d94e1-e0df-4eca-93e6-8778984bcd58" })

                    MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum = beamObjectHelper.saveOnAPI(object1)?.dataChecksum

                    // Create 1 conflicted object
                    object1.title = newTitle1
                    object1.previousChecksum = "00a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"

                    MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum = beamObjectHelper.saveOnAPI(object2)?.dataChecksum

                    // Create 1 conflicted object
                    object2.title = newTitle2
                    object2.previousChecksum = "11a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb11"
                }

                context("with replace policy") {
                    fit("saves objects") {
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

                    fit("stores previousChecksum") {
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
                    fit("saves objects") {
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

                    fit("stores previousChecksum") {
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

                        var expectedResult2 = object2.copy()
                        expectedResult2.title = "merged: \(newTitle2)\(title2!)"

                        expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(expectedResult1))
                        expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(expectedResult2))
                        expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                    }
                }
            }

            context("with all objects in conflict") {
                let newTitle1 = "new Title1"
                let newTitle2 = "new Title2"

                beforeEach {
                    MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum = beamObjectHelper.saveOnAPI(object1)?.dataChecksum
                    MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum = beamObjectHelper.saveOnAPI(object2)?.dataChecksum
                }

                context("with replace policy") {
                    it("saves objects") {
                        object1.title = newTitle1
                        object2.title = newTitle2

                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2]) { result in
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
                                                                "update_beam_objects",
                                                                "beam_object",
                                                                "beam_object",
                                                                "update_beam_objects"]

                        let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1.beamObjectId)
                        expect(object1) == remoteObject1

                        let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                        expect(object2) == remoteObject2

                        expect(remoteObject1?.checksum) == (try self.checksum(object1))
                        expect(remoteObject2?.checksum) == (try self.checksum(object2))
                    }

                    it("stores previousChecksum") {
                        object1.title = newTitle1
                        object2.title = newTitle2

                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2]) { result in
                                    expect { try result.get() }.toNot(throwError())

                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                        expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                    }
                }

                context("with fetch and raise error policy") {
                    it("saves objects") {
                        object1.title = newTitle1
                        object2.title = newTitle2

                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2], .fetchRemoteAndError) { result in
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

                        expect(remoteObject1?.checksum) == (try self.checksum(expectedResult1))
                        expect(remoteObject2?.checksum) == (try self.checksum(expectedResult2))

                        expect(MyRemoteObjectManager.store[object1.beamObjectId]) == expectedResult1
                        expect(MyRemoteObjectManager.store[object2.beamObjectId]) == expectedResult2
                    }

                    it("stores previousChecksum") {
                        expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))

                        object1.title = newTitle1
                        object2.title = newTitle2

                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.saveOnBeamObjectsAPI([object1, object2], .fetchRemoteAndError) { result in
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
//                APIRequest.networkCallFiles = []
            }

            afterEach {
                self.deleteAll()
            }

            it("saves object") {
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

            context("with conflict") {
                let newTitle = "new Title"

                beforeEach {
                    MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum = beamObjectHelper.saveOnAPI(object)?.dataChecksum
//                    APIRequest.networkCallFiles = []

                    // Create 1 conflicted object
//                    object.title = newTitle
                    object.previousChecksum = "00a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"
                }

                context("with replace policy") {
                    it("saves object") {
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

                    it("stores previousChecksum") {
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
                    it("saves object") {
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

                    it("stores previousChecksum") {
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

    func createObjects() {
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
    }

    func checksum(_ object: MyRemoteObject) throws -> String {
        let jsonData = try BeamObject.encoder.encode(object)
        let result = jsonData.SHA256

        if let string = jsonData.asString {
            Logger.shared.logDebug("🍀 SHA checksum on \(string): \(result)", category: .beamObjectDebug)
        }

        return result
    }

    func deleteAll() {
        let semaphore = DispatchSemaphore(value: 0)

        _ = try? BeamObjectRequest().deleteAll { _ in
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))
        MyRemoteObjectManager.store.removeAll()
    }
}
