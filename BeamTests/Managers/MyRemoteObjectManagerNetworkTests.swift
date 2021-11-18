import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine
import PromiseKit
import Promises

@testable import Beam
@testable import BeamCore

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

            BeamObjectManager.unregisterAll()
            sut.registerOnBeamObjectManager()

            MyRemoteObjectManager.store.removeAll()

            try? EncryptionManager.shared.replacePrivateKey(Configuration.testPrivateKey)
        }

        afterEach {
            BeamObjectManager.clearNetworkCalls()
            beamHelper.endNetworkRecording()

            BeamDate.reset()
        }

        describe("refreshFromBeamObjectAPI()") {
            var object1: MyRemoteObject!

            beforeEach {
                self.createObjects()
                object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
            }

            afterEach {
                beamObjectHelper.deleteAll()
                MyRemoteObjectManager.store.removeAll()
            }

            context("when objects exist on the API side") {
                beforeEach {
                    self.saveAllObjectsAndSaveChecksum()
                }

                context("when remote updatedAt is more recent") {
                    beforeEach {
                        // to fetch previousChecksum
                        object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")

                        var object = object1.copy()
                        BeamDate.travel(10)
                        object.updatedAt = BeamDate.now
                        _ = BeamObjectTestsHelper().saveOnAPI(object)
                    }

                    context("Foundation") {
                        it("fetches object") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                _ = try? sut.refreshFromBeamObjectAPI(object1) { result in
                                    expect { try result.get() }.toNot(throwError())

                                    let remoteObject = try? result.get()

                                    let dateFormatter = ISO8601DateFormatter()
                                    let date = dateFormatter.date(from: "2021-03-19T12:21:13Z")

                                    expect(remoteObject?.updatedAt) == date
                                    expect(object1.updatedAt) == dateFormatter.date(from: fixedDate)

                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 2

                            let expectedNetworkCalls = ["beam_object_updated_at",
                                                        "beam_object"]

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                        }
                    }

                    context("with PromiseKit") {
                        it("fetches object") {
                            let networkCalls = APIRequest.callsCount
                            let promise: PromiseKit.Promise<MyRemoteObject?> = sut.refreshFromBeamObjectAPI(object1)

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    let dateFormatter = ISO8601DateFormatter()
                                    let date = dateFormatter.date(from: "2021-03-19T12:21:13Z")

                                    expect(remoteObject?.updatedAt) == date
                                    expect(object1.updatedAt) == dateFormatter.date(from: fixedDate)
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 2

                            let expectedNetworkCalls = ["beam_object_updated_at",
                                                        "beam_object"]

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                        }
                    }

                    context("with Promises") {
                        it("fetches object") {
                            let networkCalls = APIRequest.callsCount
                            let promise: Promises.Promise<MyRemoteObject?> = sut.refreshFromBeamObjectAPI(object1)

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    let dateFormatter = ISO8601DateFormatter()
                                    let date = dateFormatter.date(from: "2021-03-19T12:21:13Z")

                                    expect(remoteObject?.updatedAt) == date
                                    expect(object1.updatedAt) == dateFormatter.date(from: fixedDate)
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 2

                            let expectedNetworkCalls = ["beam_object_updated_at",
                                                        "beam_object"]

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                        }
                    }
                }

                context("when remote updatedAt is older") {
                    context("when forcing update") {
                        context("Foundation") {
                            it("fetches object") {
                                let networkCalls = APIRequest.callsCount

                                waitUntil(timeout: .seconds(10)) { done in
                                    _ = try? sut.refreshFromBeamObjectAPI(object1, true) { result in
                                        expect { try result.get() }.toNot(throwError())

                                        let remoteObject = try? result.get()

                                        let dateFormatter = ISO8601DateFormatter()

                                        expect(remoteObject?.updatedAt) == dateFormatter.date(from: fixedDate)
                                        expect(object1.updatedAt) == dateFormatter.date(from: fixedDate)

                                        done()
                                    }
                                }

                                expect(APIRequest.callsCount - networkCalls) == 1

                                let expectedNetworkCalls = ["beam_object"]

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                            }
                        }
                        context("with PromiseKit") {
                            it("fetches object") {
                                let networkCalls = APIRequest.callsCount
                                let promise: PromiseKit.Promise<MyRemoteObject?> = sut.refreshFromBeamObjectAPI(object1, true)

                                waitUntil(timeout: .seconds(10)) { done in
                                    promise.done { remoteObject in
                                        let dateFormatter = ISO8601DateFormatter()
                                        expect(remoteObject?.updatedAt) == dateFormatter.date(from: fixedDate)
                                        expect(object1.updatedAt) == dateFormatter.date(from: fixedDate)
                                        done()
                                    }.catch { error in
                                        fail("Should not happen: \(error)")
                                        done()
                                    }
                                }

                                expect(APIRequest.callsCount - networkCalls) == 1

                                let expectedNetworkCalls = ["beam_object"]

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                            }
                        }
                        context("with Promises") {
                            it("fetches object") {
                                let networkCalls = APIRequest.callsCount
                                let promise: Promises.Promise<MyRemoteObject?> = sut.refreshFromBeamObjectAPI(object1, true)

                                waitUntil(timeout: .seconds(10)) { done in
                                    promise.then { remoteObject in
                                        let dateFormatter = ISO8601DateFormatter()
                                        expect(remoteObject?.updatedAt) == dateFormatter.date(from: fixedDate)
                                        expect(object1.updatedAt) == dateFormatter.date(from: fixedDate)
                                        done()
                                    }.catch { error in
                                        fail("Should not happen: \(error)")
                                        done()
                                    }
                                }

                                expect(APIRequest.callsCount - networkCalls) == 1

                                let expectedNetworkCalls = ["beam_object"]

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                            }
                        }
                    }

                    context("when not forcing update") {
                        context("Foundation") {
                            it("doesnt't fetch object") {
                                let networkCalls = APIRequest.callsCount

                                waitUntil(timeout: .seconds(10)) { done in
                                    _ = try? sut.refreshFromBeamObjectAPI(object1) { result in
                                        expect {
                                            let remoteObject = try result.get()
                                            expect(remoteObject).to(beNil())
                                        }.toNot(throwError())

                                        done()
                                    }
                                }

                                expect(APIRequest.callsCount - networkCalls) == 1

                                let expectedNetworkCalls = ["beam_object_updated_at"]

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                            }
                        }
                        context("with PromiseKit") {
                            it("doesnt't fetch object") {
                                let networkCalls = APIRequest.callsCount
                                let promise: PromiseKit.Promise<MyRemoteObject?> = sut.refreshFromBeamObjectAPI(object1)

                                waitUntil(timeout: .seconds(10)) { done in
                                    promise.done { remoteObject in
                                        expect(remoteObject).to(beNil())
                                        done()
                                    }.catch { error in
                                        fail("Should not happen: \(error)")
                                        done()
                                    }
                                }

                                expect(APIRequest.callsCount - networkCalls) == 1

                                let expectedNetworkCalls = ["beam_object_updated_at"]

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                            }
                        }
                        context("with Promises") {
                            it("doesnt't fetch object") {
                                let networkCalls = APIRequest.callsCount
                                let promise: Promises.Promise<MyRemoteObject?> = sut.refreshFromBeamObjectAPI(object1)

                                waitUntil(timeout: .seconds(10)) { done in
                                    promise.then { remoteObject in
                                        expect(remoteObject).to(beNil())
                                        done()
                                    }.catch { error in
                                        fail("Should not happen: \(error)")
                                        done()
                                    }
                                }
                                expect(APIRequest.callsCount - networkCalls) == 1

                                let expectedNetworkCalls = ["beam_object_updated_at"]

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                            }
                        }
                    }
                }
            }

            context("when objects don't exist on the API side") {
                context("Foundation") {
                    it("doesn't return error") {
                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(10)) { done in
                            _ = try? sut.refreshFromBeamObjectAPI(object1) { result in
                                expect {
                                    let remoteObject = try result.get()
                                    expect(remoteObject).to(beNil())
                                }.toNot(throwError())

                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        let expectedNetworkCalls = ["beam_object_updated_at"]

                        expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                    }
                }
                context("PromiseKit") {
                    it("doesn't return error") {
                        let networkCalls = APIRequest.callsCount
                        let promise: PromiseKit.Promise<MyRemoteObject?> = sut.refreshFromBeamObjectAPI(object1)

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.done { remoteObject in
                                expect(remoteObject).to(beNil())
                                done()
                            }.catch { error in
                                fail("Should not happen: \(error)")
                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        let expectedNetworkCalls = ["beam_object_updated_at"]

                        expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                    }
                }
                context("Promises") {
                    it("doesn't return error") {
                        let networkCalls = APIRequest.callsCount
                        let promise: Promises.Promise<MyRemoteObject?> = sut.refreshFromBeamObjectAPI(object1)

                        waitUntil(timeout: .seconds(10)) { done in
                            promise.then { remoteObject in
                                expect(remoteObject).to(beNil())
                                done()
                            }.catch { error in
                                fail("Should not happen: \(error)")
                                done()
                            }
                        }

                        expect(APIRequest.callsCount - networkCalls) == 1

                        let expectedNetworkCalls = ["beam_object_updated_at"]

                        expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                    }
                }
            }
        }

        describe("saveAllOnBeamObjectApi()") {
            var object1: MyRemoteObject!
            var object2: MyRemoteObject!
            var object3: MyRemoteObject!

            var title1: String!
            var title2: String!
            var title3: String!

            beforeEach {
                self.createObjects()
            }

            afterEach {
                beamObjectHelper.deleteAll()
                MyRemoteObjectManager.store.removeAll()
            }

            context("when objects don't exist on the API") {
                context("when we don't send previousChecksum") {
                    context("Foundation") {
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
                    }
                    context("with PromiseKit") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount
                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { success in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
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
                    }
                    context("with Promises") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount
                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { success in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
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
                    }

                    context("Foundation") {
                        it("stores previousChecksum") {
                            for (_, object) in MyRemoteObjectManager.store {
                                expect(object.previousChecksum).to(beNil())
                            }

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

                            for (_, object) in MyRemoteObjectManager.store {
                                expect(object.previousChecksum).toNot(beNil())
                            }
                        }
                    }
                    context("PromiseKit") {
                        it("stores previousChecksum") {
                            for (_, object) in MyRemoteObjectManager.store {
                                expect(object.previousChecksum).to(beNil())
                            }

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            for (_, object) in MyRemoteObjectManager.store {
                                expect(object.previousChecksum).toNot(beNil())
                            }
                        }
                    }
                    context("Promises") {
                        it("stores previousChecksum") {
                            for (_, object) in MyRemoteObjectManager.store {
                                expect(object.previousChecksum).to(beNil())
                            }

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            for (_, object) in MyRemoteObjectManager.store {
                                expect(object.previousChecksum).toNot(beNil())
                            }
                        }
                    }
                }

                context("when we send a previousChecksum") {
                    beforeEach {
                        for (key, var object) in MyRemoteObjectManager.store {
                            object.previousChecksum = try? "foobar".SHA256()
                            MyRemoteObjectManager.store[key] = object
                        }
                    }

                    context("Foundation") {
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

                            let expectedNetworkCalls = ["update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                    context("PromiseKit") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { success in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                    context("Promises") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { success in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }

                    context("Foundation") {
                        it("stores previousChecksum") {
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

                            for (_, object) in MyRemoteObjectManager.store {
                                expect(object.previousChecksum).toNot(beNil())
                            }
                        }
                    }
                    context("with PromiseKit") {
                        it("stores previousChecksum") {
                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { success in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            for (_, object) in MyRemoteObjectManager.store {
                                expect(object.previousChecksum).toNot(beNil())
                            }
                        }
                    }
                    context("with Promises") {
                        it("stores previousChecksum") {
                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { success in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            for (_, object) in MyRemoteObjectManager.store {
                                expect(object.previousChecksum).toNot(beNil())
                            }
                        }
                    }
                }
            }

            context("when all objects already exist, and we save all with 1 conflicted object") {
                let newTitle1 = "new Title1"

                beforeEach {
                    self.saveAllObjectsAndSaveChecksum()

                    object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                    object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                    object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                    title1 = object1.title!
                    title2 = object2.title!
                    title3 = object3.title!

                    BeamDate.travel(2)

                    // Create 1 conflicted object
                    object1.previousChecksum = "00a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"
                    object1.title = newTitle1
                    object1.updatedAt = BeamDate.now
                    MyRemoteObjectManager.store[object1.beamObjectId] = object1
                }

                context("with replace policy") {
                    context("Foundation") {
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

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_object",
                                                        "update_beam_object"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                    context("with PromiseKit") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { success in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_object",
                                                        "update_beam_object"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                    context("with Promises") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { success in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_object",
                                                        "update_beam_object"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                }

                context("with fetch and raise error policy") {
                    beforeEach {
                        MyRemoteObjectManager.conflictPolicy = .fetchRemoteAndError
                    }
                    afterEach {
                        MyRemoteObjectManager.conflictPolicy = .replace
                    }
                    context("Foundation") {
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

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_object",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            var expectedResult1 = object1.copy()
                            expectedResult1.title = "merged: \(newTitle1)\(title1!)"

                            let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1.beamObjectId)
                            expect(expectedResult1) == remoteObject1

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                    context("with PromiseKit") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { success in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
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

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                    context("with Promises") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { success in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
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

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                }
            }

            context("when all objects exist, and with save with multiple conflicted object") {
                let newTitle1 = "new Title1"
                let newTitle2 = "new Title2"

                beforeEach {
                    self.saveAllObjectsAndSaveChecksum()

                    object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                    object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                    object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                    title1 = object1.title!
                    title2 = object2.title!
                    title3 = object3.title!

                    BeamDate.travel(2)

                    // Create 2 conflicted objects
                    object1.previousChecksum = "00a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"
                    object2.previousChecksum = "11a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb11"

                    object1.title = newTitle1
                    object2.title = newTitle2

                    object1.updatedAt = BeamDate.now
                    object2.updatedAt = BeamDate.now

                    MyRemoteObjectManager.store[object1.beamObjectId] = object1
                    MyRemoteObjectManager.store[object2.beamObjectId] = object2
                }

                context("with replace policy") {
                    context("Foundation") {
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

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                    context("PromiseKit") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                    context("Promises") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                }

                context("with fetch and raise error policy") {
                    beforeEach {
                        MyRemoteObjectManager.conflictPolicy = .fetchRemoteAndError
                    }
                    afterEach {
                        MyRemoteObjectManager.conflictPolicy = .replace
                    }
                    context("Foundation") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                do {
                                    _ = try sut.saveAllOnBeamObjectApi() { result in
                                        expect { try result.get() }.toNot(throwError())

                                        done()
                                    }
                                } catch {
                                    fail(error.localizedDescription)
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            var expectedResult1 = object1.copy()
                            expectedResult1.title = "merged: \(newTitle1)\(title1!)"

                            var expectedResult2 = object2.copy()
                            expectedResult2.title = "merged: \(newTitle2)\(title2!)"

                            let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1.beamObjectId)
                            expect(expectedResult1) == remoteObject1

                            let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                            expect(expectedResult2) == remoteObject2

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                    context("PromiseKit") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            var expectedResult1 = object1.copy()
                            expectedResult1.title = "merged: \(newTitle1)\(title1!)"

                            var expectedResult2 = object2.copy()
                            expectedResult2.title = "merged: \(newTitle2)\(title2!)"

                            let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1.beamObjectId)
                            expect(expectedResult1) == remoteObject1

                            let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                            expect(expectedResult2) == remoteObject2

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                    context("Promises") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            var expectedResult1 = object1.copy()
                            expectedResult1.title = "merged: \(newTitle1)\(title1!)"

                            var expectedResult2 = object2.copy()
                            expectedResult2.title = "merged: \(newTitle2)\(title2!)"

                            let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1.beamObjectId)
                            expect(expectedResult1) == remoteObject1

                            let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                            expect(expectedResult2) == remoteObject2

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                }
            }

            context("when all objects exist, and we save with all objects in conflict") {
                let newTitle1 = "new Title1"
                let newTitle2 = "new Title2"
                let newTitle3 = "new Title3"

                beforeEach {
                    self.saveAllObjectsAndSaveChecksum()

                    object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                    object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                    object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                    title1 = object1.title!
                    title2 = object2.title!
                    title3 = object3.title!

                    object1.previousChecksum = "11a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"
                    object2.previousChecksum = "22a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"
                    object3.previousChecksum = "33a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"

                    BeamDate.travel(2)

                    object1.title = newTitle1
                    object2.title = newTitle2
                    object3.title = newTitle3

                    object1.updatedAt = BeamDate.now
                    object2.updatedAt = BeamDate.now
                    object3.updatedAt = BeamDate.now

                    MyRemoteObjectManager.store[object1.beamObjectId] = object1
                    MyRemoteObjectManager.store[object2.beamObjectId] = object2
                    MyRemoteObjectManager.store[object3.beamObjectId] = object3
                }

                context("with replace policy") {
                    context("Foundation") {
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

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                    context("PromiseKit") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                    context("Promises") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                }

                context("with fetch and raise error policy") {
                    beforeEach {
                        MyRemoteObjectManager.conflictPolicy = .fetchRemoteAndError
                    }
                    afterEach {
                        MyRemoteObjectManager.conflictPolicy = .replace
                    }
                    context("Foundation") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                do {
                                    _ = try sut.saveAllOnBeamObjectApi() { result in
                                        expect { try result.get() }.toNot(throwError())

                                        done()
                                    }
                                } catch {
                                    fail(error.localizedDescription)
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

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

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                    context("PromiseKit") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

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

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                    context("Promises") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveAllOnBeamObjectApi()

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

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

                            for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                                        UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                                let object = MyRemoteObjectManager.store[key]
                                expect(object) == (try beamObjectHelper.fetchOnAPI(key))
                            }
                        }
                    }
                }
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

                object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                title1 = object1.title!
                title2 = object2.title!
                title3 = object3.title!
            }

            afterEach {
                beamObjectHelper.deleteAll()
                MyRemoteObjectManager.store.removeAll()
            }

            context("when objects don't exist on the API") {
                context("when we don't send previousChecksum") {
                    context("Foundation") {
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

                            let newObject1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            expect(newObject1) == remoteObject1
                            expect(newObject2) == remoteObject2
                            expect(newObject3) == remoteObject3

                            expect(remoteObject1?.checksum) == (try self.checksum(object1))
                            expect(remoteObject2?.checksum) == (try self.checksum(object2))
                            expect(remoteObject3?.checksum) == (try self.checksum(object3))
                        }
                    }
                    context("PromiseKit") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI(Array(MyRemoteObjectManager.store.values))

                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 1
                            expect(APIRequest.networkCallFiles) == ["sign_in", "update_beam_objects"]

                            let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1.beamObjectId)
                            let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                            let remoteObject3: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object3.beamObjectId)

                            let newObject1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            expect(newObject1) == remoteObject1
                            expect(newObject2) == remoteObject2
                            expect(newObject3) == remoteObject3

                            expect(remoteObject1?.checksum) == (try self.checksum(object1))
                            expect(remoteObject2?.checksum) == (try self.checksum(object2))
                            expect(remoteObject3?.checksum) == (try self.checksum(object3))
                        }
                    }
                    context("Promises") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI(Array(MyRemoteObjectManager.store.values))
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 1
                            expect(APIRequest.networkCallFiles) == ["sign_in", "update_beam_objects"]

                            let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1.beamObjectId)
                            let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                            let remoteObject3: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object3.beamObjectId)

                            let newObject1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            expect(newObject1) == remoteObject1
                            expect(newObject2) == remoteObject2
                            expect(newObject3) == remoteObject3

                            expect(remoteObject1?.checksum) == (try self.checksum(object1))
                            expect(remoteObject2?.checksum) == (try self.checksum(object2))
                            expect(remoteObject3?.checksum) == (try self.checksum(object3))
                        }
                    }
                    context("Foundation") {
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

                            let newObject1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            expect(newObject1?.previousChecksum) == (try self.checksum(object1))
                            expect(newObject2?.previousChecksum) == (try self.checksum(object2))
                            expect(newObject3?.previousChecksum) == (try self.checksum(object3))

                            expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                            expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                            expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                        }
                    }
                    context("PromiseKit") {
                        it("stores previousChecksum") {
                            for (_, object) in MyRemoteObjectManager.store {
                                expect(object.previousChecksum).to(beNil())
                            }

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI(Array(MyRemoteObjectManager.store.values))
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let newObject1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            expect(newObject1?.previousChecksum) == (try self.checksum(object1))
                            expect(newObject2?.previousChecksum) == (try self.checksum(object2))
                            expect(newObject3?.previousChecksum) == (try self.checksum(object3))

                            expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                            expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                            expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                        }
                    }
                    context("Promises") {
                        it("stores previousChecksum") {
                            for (_, object) in MyRemoteObjectManager.store {
                                expect(object.previousChecksum).to(beNil())
                            }

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI(Array(MyRemoteObjectManager.store.values))
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let newObject1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            expect(newObject1?.previousChecksum) == (try self.checksum(object1))
                            expect(newObject2?.previousChecksum) == (try self.checksum(object2))
                            expect(newObject3?.previousChecksum) == (try self.checksum(object3))

                            expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                            expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                            expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                        }
                    }
                }

                context("when we send a previousChecksum") {
                    beforeEach {
                        for var object in MyRemoteObjectManager.store.values {
                            object.previousChecksum = try? "foobar".SHA256()
                        }
                    }
                    context("Foundation") {
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

                            let newObject1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            expect(newObject1) == remoteObject1
                            expect(newObject2) == remoteObject2
                            expect(newObject3) == remoteObject3

                            expect(remoteObject1?.checksum) == (try self.checksum(object1))
                            expect(remoteObject2?.checksum) == (try self.checksum(object2))
                            expect(remoteObject3?.checksum) == (try self.checksum(object3))
                        }
                    }
                    context("PromiseKit") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI(Array(MyRemoteObjectManager.store.values))
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 1
                            expect(APIRequest.networkCallFiles) == ["sign_in", "update_beam_objects"]

                            let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1.beamObjectId)
                            let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                            let remoteObject3: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object3.beamObjectId)

                            let newObject1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            expect(newObject1) == remoteObject1
                            expect(newObject2) == remoteObject2
                            expect(newObject3) == remoteObject3

                            expect(remoteObject1?.checksum) == (try self.checksum(object1))
                            expect(remoteObject2?.checksum) == (try self.checksum(object2))
                            expect(remoteObject3?.checksum) == (try self.checksum(object3))
                        }
                    }
                    context("Promises") {
                        it("saves all objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI(Array(MyRemoteObjectManager.store.values))
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 1
                            expect(APIRequest.networkCallFiles) == ["sign_in", "update_beam_objects"]

                            let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1.beamObjectId)
                            let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2.beamObjectId)
                            let remoteObject3: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object3.beamObjectId)

                            let newObject1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            expect(newObject1) == remoteObject1
                            expect(newObject2) == remoteObject2
                            expect(newObject3) == remoteObject3

                            expect(remoteObject1?.checksum) == (try self.checksum(object1))
                            expect(remoteObject2?.checksum) == (try self.checksum(object2))
                            expect(remoteObject3?.checksum) == (try self.checksum(object3))
                        }
                    }

                    context("Foundation") {
                        it("stores previousChecksum") {
                            for (_, object) in MyRemoteObjectManager.store {
                                expect(object.previousChecksum).to(beNil())
                            }

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI(Array(MyRemoteObjectManager.store.values))
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let newObject1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            expect(newObject1?.previousChecksum) == (try self.checksum(object1))
                            expect(newObject2?.previousChecksum) == (try self.checksum(object2))
                            expect(newObject3?.previousChecksum) == (try self.checksum(object3))

                            expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                            expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                            expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                        }
                    }
                    context("PromiseKit") {
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

                            let newObject1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            expect(newObject1?.previousChecksum) == (try self.checksum(object1))
                            expect(newObject2?.previousChecksum) == (try self.checksum(object2))
                            expect(newObject3?.previousChecksum) == (try self.checksum(object3))

                            expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                            expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                            expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                        }
                    }
                    context("Promises") {
                        it("stores previousChecksum") {
                            for (_, object) in MyRemoteObjectManager.store {
                                expect(object.previousChecksum).to(beNil())
                            }

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI(Array(MyRemoteObjectManager.store.values))
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let newObject1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            let newObject3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            expect(newObject1?.previousChecksum) == (try self.checksum(object1))
                            expect(newObject2?.previousChecksum) == (try self.checksum(object2))
                            expect(newObject3?.previousChecksum) == (try self.checksum(object3))

                            expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                            expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                            expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                        }
                    }
                }
            }

            context("When called twice") {
                let newTitle1 = "new Title1"

                beforeEach {
                    self.saveAllObjectsAndSaveChecksum()

                    object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                    object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                    object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                    title1 = object1.title!
                    title2 = object2.title!
                    title3 = object3.title!

                    BeamDate.travel(2)

                    object1.title = newTitle1
                    object1.updatedAt = BeamDate.now
                }

                it("doesn't generate conflicts") {
                    let networkCalls = APIRequest.callsCount

                    waitUntil(timeout: .seconds(10)) { done in
                        do {
                            let group = DispatchGroup()

                            group.enter()
                            _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3]) { _ in group.leave() }

                            group.enter()
                            _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3]) { result in
                                expect { try result.get() }.toNot(throwError())

                                group.leave()
                            }

                            group.wait()
                            done()

                        } catch {
                            fail(error.localizedDescription)
                        }
                    }

                    let expectedNetworkCalls = ["update_beam_objects", "update_beam_objects"]

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
            }

            context("when all objects already exist, and we save all with 1 conflicted object") {
                let newTitle1 = "new Title1"

                beforeEach {
                    self.saveAllObjectsAndSaveChecksum()

                    object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                    object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                    object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                    title1 = object1.title!
                    title2 = object2.title!
                    title3 = object3.title!

                    BeamDate.travel(2)

                    // Create 1 conflicted object
                    MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum = "00a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"
                    object1.title = newTitle1
                    object1.updatedAt = BeamDate.now
                }

                context("with replace policy") {
                    context("Foundation") {
                        it("saves all objects with their new content") {
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
                    context("PromiseKit") {
                        it("saves all objects with their new content") {
                            let networkCalls = APIRequest.callsCount

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
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
                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                            expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                            expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                        }
                    }
                    context("Promises") {
                        it("saves all objects with their new content") {
                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
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
                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                            expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                            expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                        }
                    }
                }

                context("with fetch and raise error policy") {
                    beforeEach {
                        MyRemoteObjectManager.conflictPolicy = .fetchRemoteAndError
                    }
                    afterEach {
                        MyRemoteObjectManager.conflictPolicy = .replace
                    }
                    context("Foundation") {
                        it("saves objects") {
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
                            waitUntil(timeout: .seconds(10)) { done in
                                do {
                                    _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3]) { result in
                                        expect { try result.get() }.toNot(throwError())

                                        if let objects = try? result.get() {
                                            Logger.shared.logWarning("Received objects:", category: .beamObjectNetwork)
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
                    context("PromiseKit") {
                        it("saves objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
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
                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            var expectedResult1 = object1.copy()
                            expectedResult1.title = "merged: \(newTitle1)\(title1!)"

                            expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(expectedResult1))
                            expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                        }
                    }
                    context("Promises") {
                        it("saves objects") {
                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
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
                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            var expectedResult1 = object1.copy()
                            expectedResult1.title = "merged: \(newTitle1)\(title1!)"

                            expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(expectedResult1))
                            expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                        }
                    }
                }
            }

            context("when all objects exist, and with save with multiple conflicted object") {
                let newTitle1 = "new Title1"
                let newTitle2 = "new Title2"

                beforeEach {
                    self.saveAllObjectsAndSaveChecksum()

                    object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                    object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                    object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                    title1 = object1.title!
                    title2 = object2.title!
                    title3 = object3.title!

                    // Create 2 conflicted objects
                    BeamDate.travel(2)

                    MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum = "00a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"
                    MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum = "11a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb11"

                    object1.title = newTitle1
                    object2.title = newTitle2

                    object1.updatedAt = BeamDate.now
                    object2.updatedAt = BeamDate.now
                }

                context("with replace policy") {
                    context("Foundation") {
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

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

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
                    context("PromiseKit") {
                        it("saves objects with their new content") {
                            let networkCalls = APIRequest.callsCount

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

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
                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                            expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                            expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                        }
                    }
                    context("Promises") {
                        it("saves objects with their new content") {
                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

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
                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                            expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                            expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                        }
                    }
                }

                context("with fetch and raise error policy") {
                    beforeEach {
                        MyRemoteObjectManager.conflictPolicy = .fetchRemoteAndError
                    }
                    afterEach {
                        MyRemoteObjectManager.conflictPolicy = .replace
                    }
                    context("Foundation") {
                        it("saves all objects with merged content") {
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

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

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

                            var expectedResult1 = object1.copy()
                            expectedResult1.title = "merged: \(newTitle1)\(title1!)"

                            var expectedResult2 = object2.copy()
                            expectedResult2.title = "merged: \(newTitle2)\(title2!)"

                            expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(expectedResult1))
                            expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(expectedResult2))
                            expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                        }
                    }
                    context("PromiseKit") {
                        it("saves all objects with merged content") {
                            let networkCalls = APIRequest.callsCount

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

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
                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
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
                    context("Promises") {
                        it("saves all objects with merged content") {
                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

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
                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
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
            }

            context("when all objects exist, and we save with all objects in conflict") {
                let newTitle1 = "new Title1"
                let newTitle2 = "new Title2"
                let newTitle3 = "new Title3"

                beforeEach {
                    self.saveAllObjectsAndSaveChecksum()

                    object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                    object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                    object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                    title1 = object1.title!
                    title2 = object2.title!
                    title3 = object3.title!

                    BeamDate.travel(2)

                    MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum = "11a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"
                    MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum = "22a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"
                    MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum = "33a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"

                    object1.title = newTitle1
                    object2.title = newTitle2
                    object3.title = newTitle3

                    object1.updatedAt = BeamDate.now
                    object2.updatedAt = BeamDate.now
                    object3.updatedAt = BeamDate.now
                }

                context("with replace policy") {
                    context("Foundation") {
                        it("saves all objects with their new content") {
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

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

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
                    context("PromiseKit") {
                        it("saves all objects with their new content") {
                            let networkCalls = APIRequest.callsCount

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

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
                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                            expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                            expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                        }
                    }
                    context("Promises") {
                        it("saves all objects with their new content") {
                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

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
                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            expect(MyRemoteObjectManager.store[object1.beamObjectId]?.previousChecksum) == (try self.checksum(object1))
                            expect(MyRemoteObjectManager.store[object2.beamObjectId]?.previousChecksum) == (try self.checksum(object2))
                            expect(MyRemoteObjectManager.store[object3.beamObjectId]?.previousChecksum) == (try self.checksum(object3))
                        }
                    }
                }

                context("with fetch and raise error policy") {
                    beforeEach {
                        MyRemoteObjectManager.conflictPolicy = .fetchRemoteAndError
                    }
                    afterEach {
                        MyRemoteObjectManager.conflictPolicy = .replace
                    }
                    context("Foundation") {
                        it("saves all objects with merged content") {
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

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

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
                    context("PromiseKit") {
                        it("saves all objects with merged content") {
                            object1.title = newTitle1
                            object2.title = newTitle2
                            object3.title = newTitle3

                            let networkCalls = APIRequest.callsCount

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

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
                            object1.title = newTitle1
                            object2.title = newTitle2
                            object3.title = newTitle3

                            let promise: PromiseKit.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
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
                    context("Promises") {
                        it("saves all objects with merged content") {
                            object1.title = newTitle1
                            object2.title = newTitle2
                            object3.title = newTitle3

                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            let expectedNetworkCalls = ["update_beam_objects",
                                                        "beam_objects",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

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
                            object1.title = newTitle1
                            object2.title = newTitle2
                            object3.title = newTitle3

                            let promise: Promises.Promise<[MyRemoteObject]> = sut.saveOnBeamObjectsAPI([object1, object2, object3])
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
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
                beamObjectHelper.deleteAll()
                MyRemoteObjectManager.store.removeAll()
            }

            context("when object doesn't exist on the API") {
                context("when we don't send previousChecksum") {
                    context("Foundation") {
                        fit("saves new object") {
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
                    context("PromiseKit") {
                        it("saves new object") {
                            let networkCalls = APIRequest.callsCount

                            let promise: PromiseKit.Promise<MyRemoteObject> = sut.saveOnBeamObjectAPI(object)
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
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

                            let promise: PromiseKit.Promise<MyRemoteObject> = sut.saveOnBeamObjectAPI(object)
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try self.checksum(object))
                        }
                    }
                    context("Promises") {
                        it("saves new object") {
                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<MyRemoteObject> = sut.saveOnBeamObjectAPI(object)
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
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

                            let promise: Promises.Promise<MyRemoteObject> = sut.saveOnBeamObjectAPI(object)
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try self.checksum(object))
                        }
                    }
                }

                context("when we send a previousChecksum") {
                    beforeEach {
                        MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum = try? "foobar".SHA256()
                    }
                    context("Foundation") {
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
                    context("PromiseKit") {
                        it("saves new object") {
                            let networkCalls = APIRequest.callsCount

                            let promise: PromiseKit.Promise<MyRemoteObject> = sut.saveOnBeamObjectAPI(object)
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
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
                            let promise: PromiseKit.Promise<MyRemoteObject> = sut.saveOnBeamObjectAPI(object)
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.done { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try self.checksum(object))
                        }
                    }
                    context("Promises") {
                        it("saves new object") {
                            let networkCalls = APIRequest.callsCount

                            let promise: Promises.Promise<MyRemoteObject> = sut.saveOnBeamObjectAPI(object)
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
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
                            let promise: Promises.Promise<MyRemoteObject> = sut.saveOnBeamObjectAPI(object)
                            waitUntil(timeout: .seconds(10)) { done in
                                promise.then { remoteObject in
                                    done()
                                }.catch { error in
                                    fail("Should not happen: \(error)")
                                    done()
                                }
                            }

                            expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try self.checksum(object))
                        }
                    }
                }
            }

            context("when object already exist on the API") {
                beforeEach {
                    self.saveObjectAndSaveChecksum(object)
                }

                context("when called twice") {
                    let newTitle = "new Title"

                    it("doesn't generate conflicts") {
                        object.title = newTitle
                        let networkCalls = APIRequest.callsCount

                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                let group = DispatchGroup()

                                group.enter()

                                _ = try sut.saveOnBeamObjectAPI(object) { _ in group.leave() }

                                group.enter()

                                _ = try sut.saveOnBeamObjectAPI(object) { result in
                                    expect { try result.get() }.toNot(throwError())

                                    group.leave()
                                }
                                group.wait()
                                done()
                            } catch {
                                fail(error.localizedDescription)
                            }
                        }

                        let expectedNetworkCalls = ["update_beam_object", "update_beam_object"]

                        expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                        expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                        let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)
                        expect(object) == remoteObject

                        expect(remoteObject?.checksum) == (try self.checksum(object))
                    }
                }

                context("with conflict") {
                    let newTitle = "new Title"

                    beforeEach {
                        BeamDate.travel(2)

                        // Create 1 conflicted object
                        MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum = "00a3c318664ebae8b2239cd2be6dae3f546feb789cb005fa9f31512709f2fb00"
                        object.updatedAt = BeamDate.now
                    }

                    context("with replace policy") {
                        context("Foundation") {
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

                                let expectedNetworkCalls = ["update_beam_object",
                                                            "beam_object",
                                                            "update_beam_object"]

                                expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)
                                expect(object) == remoteObject

                                expect(remoteObject?.checksum) == (try self.checksum(object))
                            }

                            it("stores previousChecksum with overwritten content") {
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
                        context("PromiseKit") {
                            it("saves object overwriting content") {
                                object.title = newTitle
                                let networkCalls = APIRequest.callsCount

                                let promise: PromiseKit.Promise<MyRemoteObject> = sut.saveOnBeamObjectAPI(object)
                                waitUntil(timeout: .seconds(10)) { done in
                                    promise.done { remoteObject in
                                        done()
                                    }.catch { error in
                                        fail("Should not happen: \(error)")
                                        done()
                                    }
                                }

                                let expectedNetworkCalls = ["update_beam_object",
                                                            "beam_object",
                                                            "update_beam_object"]

                                expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)
                                expect(object) == remoteObject

                                expect(remoteObject?.checksum) == (try self.checksum(object))
                            }

                            it("stores previousChecksum with overwritten content") {
                                object.title = newTitle

                                let promise: PromiseKit.Promise<MyRemoteObject> = sut.saveOnBeamObjectAPI(object)
                                waitUntil(timeout: .seconds(10)) { done in
                                    promise.done { remoteObject in
                                        done()
                                    }.catch { error in
                                        fail("Should not happen: \(error)")
                                        done()
                                    }
                                }

                                expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try self.checksum(object))
                            }
                        }
                        context("Promises") {
                            it("saves object overwriting content") {
                                object.title = newTitle
                                let networkCalls = APIRequest.callsCount

                                let promise: Promises.Promise<MyRemoteObject> = sut.saveOnBeamObjectAPI(object)
                                waitUntil(timeout: .seconds(10)) { done in
                                    promise.then { remoteObject in
                                        done()
                                    }.catch { error in
                                        fail("Should not happen: \(error)")
                                        done()
                                    }
                                }

                                let expectedNetworkCalls = ["update_beam_object",
                                                            "beam_object",
                                                            "update_beam_object"]

                                expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)
                                expect(object) == remoteObject

                                expect(remoteObject?.checksum) == (try self.checksum(object))
                            }

                            it("stores previousChecksum with overwritten content") {
                                object.title = newTitle

                                let promise: Promises.Promise<MyRemoteObject> = sut.saveOnBeamObjectAPI(object)
                                waitUntil(timeout: .seconds(10)) { done in
                                    promise.then { remoteObject in
                                        done()
                                    }.catch { error in
                                        fail("Should not happen: \(error)")
                                        done()
                                    }
                                }

                                expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try self.checksum(object))
                            }
                        }
                    }

                    context("with fetch and raise error policy") {
                        beforeEach {
                            MyRemoteObjectManager.conflictPolicy = .fetchRemoteAndError
                        }
                        afterEach {
                            MyRemoteObjectManager.conflictPolicy = .replace
                        }
                        context("PromiseKit") {
                            it("saves object with merged content") {
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

                                let expectedNetworkCalls = ["update_beam_object",
                                                            "beam_object",
                                                            "update_beam_objects"]

                                expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                var expectedResult = object.copy()
                                expectedResult.title = "merged: \(newTitle)\(title)"

                                let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)
                                expect(expectedResult) == remoteObject

                                expect(remoteObject?.checksum) == (try self.checksum(expectedResult))

                                expect(MyRemoteObjectManager.store[object.beamObjectId]) == expectedResult
                            }

                            it("stores previousChecksum based on merged content") {
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

                                var expectedResult = object.copy()
                                expectedResult.title = "merged: \(newTitle)\(title)"

                                expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try self.checksum(expectedResult))
                            }
                        }
                        context("PromiseKit") {
                            it("saves object with merged content") {
                                object.title = newTitle
                                let networkCalls = APIRequest.callsCount

                                let promise: PromiseKit.Promise<MyRemoteObject> = sut.saveOnBeamObjectAPI(object)
                                waitUntil(timeout: .seconds(10)) { done in
                                    promise.done { remoteObject in
                                        done()
                                    }.catch { error in
                                        fail("Should not happen: \(error)")
                                        done()
                                    }
                                }

                                let expectedNetworkCalls = ["update_beam_object",
                                                            "beam_object",
                                                            "update_beam_objects"]

                                expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                var expectedResult = object.copy()
                                expectedResult.title = "merged: \(newTitle)\(title)"

                                let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)
                                expect(expectedResult) == remoteObject

                                expect(remoteObject?.checksum) == (try self.checksum(expectedResult))

                                expect(MyRemoteObjectManager.store[object.beamObjectId]) == expectedResult
                            }

                            it("stores previousChecksum based on merged content") {
                                object.title = newTitle

                                let promise: PromiseKit.Promise<MyRemoteObject> = sut.saveOnBeamObjectAPI(object)
                                waitUntil(timeout: .seconds(10)) { done in
                                    promise.done { remoteObject in
                                        done()
                                    }.catch { error in
                                        fail("Should not happen: \(error)")
                                        done()
                                    }
                                }

                                var expectedResult = object.copy()
                                expectedResult.title = "merged: \(newTitle)\(title)"

                                expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try self.checksum(expectedResult))
                            }
                        }
                        context("Promises") {
                            it("saves object with merged content") {
                                object.title = newTitle
                                let networkCalls = APIRequest.callsCount

                                let promise: Promises.Promise<MyRemoteObject> = sut.saveOnBeamObjectAPI(object)
                                waitUntil(timeout: .seconds(10)) { done in
                                    promise.then { remoteObject in
                                        done()
                                    }.catch { error in
                                        fail("Should not happen: \(error)")
                                        done()
                                    }
                                }

                                let expectedNetworkCalls = ["update_beam_object",
                                                            "beam_object",
                                                            "update_beam_objects"]

                                expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                                var expectedResult = object.copy()
                                expectedResult.title = "merged: \(newTitle)\(title)"

                                let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object.beamObjectId)
                                expect(expectedResult) == remoteObject

                                expect(remoteObject?.checksum) == (try self.checksum(expectedResult))

                                expect(MyRemoteObjectManager.store[object.beamObjectId]) == expectedResult
                            }

                            it("stores previousChecksum based on merged content") {
                                object.title = newTitle

                                let promise: Promises.Promise<MyRemoteObject> = sut.saveOnBeamObjectAPI(object)
                                waitUntil(timeout: .seconds(10)) { done in
                                    promise.then { remoteObject in
                                        done()
                                    }.catch { error in
                                        fail("Should not happen: \(error)")
                                        done()
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

    private func objectForUUID(_ uuid: String) -> MyRemoteObject? {
        Array(MyRemoteObjectManager.store.values).first(where: { $0.beamObjectId.uuidString.lowercased() == uuid })
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
}
