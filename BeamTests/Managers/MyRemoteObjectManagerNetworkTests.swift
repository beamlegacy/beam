import Foundation
import XCTest
import Fakery
import Quick
import Nimble
import Combine

@testable import Beam
@testable import BeamCore

private func checksum(_ object: MyRemoteObject) throws -> String? {
    try? BeamObject(object).dataChecksum
}

class SaveOnBeamObjectAPIConfiguration: QuickConfiguration {
    private class func objectForUUID(_ uuid: String) -> MyRemoteObject? {
        Array(MyRemoteObjectManager.store.values).first(where: { $0.beamObjectId.uuidString.lowercased() == uuid })
    }

    override class func configure(_ configuration: Quick.Configuration) {
        let beamObjectHelper = BeamObjectTestsHelper()

        sharedExamples("saveAllOnBeamObjectApi with Foundation") { (sharedExampleContext: @escaping SharedExampleContext) in
            var networkCalls = APIRequest.callsCount

            beforeEach {
                networkCalls = APIRequest.callsCount
                let block = sharedExampleContext()
                let sut = block["sut"] as! MyRemoteObjectManager

                waitUntil(timeout: .seconds(60)) { done in
                    do {
                        _ = try sut.saveAllOnBeamObjectApi { result in
                            expect { try result.get() }.toNot(throwError())

                            done()
                        }
                    } catch {
                        fail(error.localizedDescription)
                    }
                }
            }

            it("saves all objects") {
                let block = sharedExampleContext()
                let expectedNetworkCalls = block["networkCallFiles"] as! [String]

                if let callsCount = block["callsCount"] as? Int {
                    expect(APIRequest.callsCount - networkCalls) == callsCount
                    expect(APIRequest.networkCallFiles) == expectedNetworkCalls
                } else {
                    expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count
                    expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                }

                for index in 1...3 {
                    if let expectedTitle = block["expectedTitle\(index)"] as? String,
                       let object = block["object\(index)"] as? MyRemoteObject {
                        var expectedResult = object.copy()
                        expectedResult.title = expectedTitle

                        let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object)
                        expect(expectedResult) == remoteObject
                    }
                }

                for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                            UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                            UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                    let object = MyRemoteObjectManager.store[key]
                    do {
                        let remoteObject = try beamObjectHelper.fetchOnAPI(object)
                        expect(object) == remoteObject
                    } catch {
                        dump(error)
                        fail(error.localizedDescription)
                    }
                }
            }

            it("stores previousChecksum") {
                for (_, object) in MyRemoteObjectManager.store {
                    expect(object.previousChecksum).toNot(beNil())
                }
            }
        }

        sharedExamples("saveAllOnBeamObjectApi with async") { (sharedExampleContext: @escaping SharedExampleContext) in
            var networkCalls = APIRequest.callsCount

            asyncBeforeEach {_ in
                networkCalls = APIRequest.callsCount
                let block = sharedExampleContext()
                let sut = block["sut"] as! MyRemoteObjectManager
                do {
                    _ = try await sut.saveAllOnBeamObjectApi()
                } catch {
                    fail(error.localizedDescription)
                }
            }

            it("saves all objects") {
                let block = sharedExampleContext()
                let expectedNetworkCalls = block["networkCallFiles"] as! [String]

                if let callsCount = block["callsCount"] as? Int {
                    expect(APIRequest.callsCount - networkCalls) == callsCount
                    expect(APIRequest.networkCallFiles) == expectedNetworkCalls
                } else {
                    expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count
                    expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                }

                for index in 1...3 {
                    if let expectedTitle = block["expectedTitle\(index)"] as? String,
                       let object = block["object\(index)"] as? MyRemoteObject {
                        var expectedResult = object.copy()
                        expectedResult.title = expectedTitle

                        let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object)
                        expect(expectedResult) == remoteObject
                    }
                }

                for key in [UUID(uuidString: "195d94e1-e0df-4eca-93e6-8778984bcd58")!,
                            UUID(uuidString: "295d94e1-e0df-4eca-93e6-8778984bcd58")!,
                            UUID(uuidString: "395d94e1-e0df-4eca-93e6-8778984bcd58")!] {
                    let object = MyRemoteObjectManager.store[key]
                    do {
                        let remoteObject = try beamObjectHelper.fetchOnAPI(object)
                        expect(object) == remoteObject
                    } catch {
                        dump(error)
                        fail(error.localizedDescription)
                    }
                }
            }

            it("stores previousChecksum") {
                for (_, object) in MyRemoteObjectManager.store {
                    expect(object.previousChecksum).toNot(beNil())
                }
            }
        }

        sharedExamples("saveOnBeamObjectsAPI with Foundation") { (sharedExampleContext: @escaping SharedExampleContext) in
            it("saves all objects") {
                let block = sharedExampleContext()
                let sut = block["sut"] as! MyRemoteObjectManager
                let networkCalls = APIRequest.callsCount
                let expectedNetworkCalls = block["networkCallFiles"] as! [String]

                let object1 = block["object1"] as! MyRemoteObject
                let object2 = block["object2"] as! MyRemoteObject
                let object3 = block["object3"] as! MyRemoteObject

                waitUntil(timeout: .seconds(30)) { done in
                    do {
                        _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3]) { result in
                            expect { try result.get() }.toNot(throwError())

                            done()
                        }
                    } catch {
                        fail(error.localizedDescription)
                    }
                }

                if let callsCount = block["callsCount"] as? Int {
                    expect(APIRequest.callsCount - networkCalls) == callsCount
                    expect(APIRequest.networkCallFiles) == expectedNetworkCalls
                } else {
                    expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count
                    expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                }

                for index in 1...3 {
                    let object = block["object\(index)"] as! MyRemoteObject
                    let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object)

                    if let expectedTitle = block["expectedTitle\(index)"] as? String {
                        var expectedResult = object.copy()
                        expectedResult.title = expectedTitle
                        expect(expectedResult) == remoteObject
                    } else {
                        expect(object) == remoteObject
                    }
                }
            }

            it("stores previousChecksum") {
                let block = sharedExampleContext()
                let sut = block["sut"] as! MyRemoteObjectManager
                let object1 = block["object1"] as! MyRemoteObject
                let object2 = block["object2"] as! MyRemoteObject
                let object3 = block["object3"] as! MyRemoteObject

                waitUntil(timeout: .seconds(30)) { done in
                    do {
                        _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3]) { result in
                            expect { try result.get() }.toNot(throwError())

                            done()
                        }
                    } catch {
                        fail(error.localizedDescription)
                    }
                }

                for index in 1...3 {
                    let object = block["object\(index)"] as! MyRemoteObject

                    if let expectedTitle = block["expectedTitle\(index)"] as? String {
                        var expectedResult = object.copy()
                        expectedResult.title = expectedTitle
                        expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try checksum(expectedResult))

                        if MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum != (try checksum(expectedResult)) {
                            dump(MyRemoteObjectManager.store[object.beamObjectId])
                            dump(expectedResult)
                            dump("not ok :(")
                        }
                    } else {
                        expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try checksum(object))
                    }
                }
            }
        }

        sharedExamples("saveOnBeamObjectsAPI with async") { (sharedExampleContext: @escaping SharedExampleContext) in
            asyncIt("saves all objects") {
                let block = sharedExampleContext()
                let sut = block["sut"] as! MyRemoteObjectManager
                let networkCalls = APIRequest.callsCount
                let expectedNetworkCalls = block["networkCallFiles"] as! [String]

                let object1 = block["object1"] as! MyRemoteObject
                let object2 = block["object2"] as! MyRemoteObject
                let object3 = block["object3"] as! MyRemoteObject

                do {
                    _ = try await sut.saveOnBeamObjectsAPI([object1, object2, object3])
                } catch {
                    fail(error.localizedDescription)
                }

                if let callsCount = block["callsCount"] as? Int {
                    expect(APIRequest.callsCount - networkCalls) == callsCount
                    expect(APIRequest.networkCallFiles) == expectedNetworkCalls
                } else {
                    expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count
                    expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                }

                for index in 1...3 {
                    let object = block["object\(index)"] as! MyRemoteObject
                    let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object)

                    if let expectedTitle = block["expectedTitle\(index)"] as? String {
                        var expectedResult = object.copy()
                        expectedResult.title = expectedTitle
                        expect(expectedResult) == remoteObject
                    } else {
                        expect(object) == remoteObject
                    }
                }
            }

            asyncIt("stores previousChecksum") {
                let block = sharedExampleContext()
                let sut = block["sut"] as! MyRemoteObjectManager
                let object1 = block["object1"] as! MyRemoteObject
                let object2 = block["object2"] as! MyRemoteObject
                let object3 = block["object3"] as! MyRemoteObject

                do {
                    _ = try await sut.saveOnBeamObjectsAPI([object1, object2, object3])
                } catch {
                    fail(error.localizedDescription)
                }

                for index in 1...3 {
                    let object = block["object\(index)"] as! MyRemoteObject

                    if let expectedTitle = block["expectedTitle\(index)"] as? String {
                        var expectedResult = object.copy()
                        expectedResult.title = expectedTitle
                        expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try checksum(expectedResult))

                        if MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum != (try checksum(expectedResult)) {
                            dump(MyRemoteObjectManager.store[object.beamObjectId])
                            dump(expectedResult)
                            dump("not ok :(")
                        }
                    } else {
                        expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try checksum(object))
                    }
                }
            }
        }

        sharedExamples("saveOnBeamObjectAPI with Foundation") { (sharedExampleContext: @escaping SharedExampleContext) in
            it("saves new object") {
                let block = sharedExampleContext()
                let sut = block["sut"] as! MyRemoteObjectManager
                let object = block["object"] as! MyRemoteObject
                let networkCalls = APIRequest.callsCount
                let expectedNetworkCalls = block["networkCallFiles"] as! [String]

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

                if let callsCount = block["callsCount"] as? Int {
                    expect(APIRequest.callsCount - networkCalls) == callsCount
                    expect(APIRequest.networkCallFiles) == expectedNetworkCalls
                } else {
                    expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count
                    expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                }

                do {
                    if let expectedTitle = block["expectedTitle"] as? String {
                        var expectedResult = object.copy()
                        expectedResult.title = expectedTitle
                        let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object)
                        expect(expectedResult) == remoteObject
                        expect(MyRemoteObjectManager.store[object.beamObjectId]) == expectedResult
                    } else {
                        let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object)
                        expect(object) == remoteObject
                    }
                } catch {
                    dump(error)
                    fail(error.localizedDescription)
                }
            }

            it("stores previousChecksum") {
                let block = sharedExampleContext()
                let sut = block["sut"] as! MyRemoteObjectManager
                let object = block["object"] as! MyRemoteObject

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

                if let expectedTitle = block["expectedTitle"] as? String {
                    var expectedResult = object.copy()
                    expectedResult.title = expectedTitle
                    expect(MyRemoteObjectManager.store[object.beamObjectId]) == expectedResult
                } else {
                    expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try checksum(object))
                }
            }
        }

        sharedExamples("saveOnBeamObjectAPI with async") { (sharedExampleContext: @escaping SharedExampleContext) in
            asyncIt("saves new object") {
                let block = sharedExampleContext()
                let sut = block["sut"] as! MyRemoteObjectManager
                let object = block["object"] as! MyRemoteObject
                let networkCalls = APIRequest.callsCount
                let expectedNetworkCalls = block["networkCallFiles"] as! [String]

                do {
                    _ = try await sut.saveOnBeamObjectAPI(object)
                } catch {
                    fail(error.localizedDescription)
                }

                if let callsCount = block["callsCount"] as? Int {
                    expect(APIRequest.callsCount - networkCalls) == callsCount
                    expect(APIRequest.networkCallFiles) == expectedNetworkCalls
                } else {
                    expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count
                    expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                }

                do {
                    if let expectedTitle = block["expectedTitle"] as? String {
                        var expectedResult = object.copy()
                        expectedResult.title = expectedTitle
                        let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object)
                        expect(expectedResult) == remoteObject
                        expect(MyRemoteObjectManager.store[object.beamObjectId]) == expectedResult
                    } else {
                        let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object)
                        expect(object) == remoteObject
                    }
                } catch {
                    dump(error)
                    fail(error.localizedDescription)
                }
            }

            asyncIt("stores previousChecksum") {
                let block = sharedExampleContext()
                let sut = block["sut"] as! MyRemoteObjectManager
                let object = block["object"] as! MyRemoteObject

                do {
                    _ = try await sut.saveOnBeamObjectAPI(object)
                } catch {
                    fail(error.localizedDescription)
                }

                if let expectedTitle = block["expectedTitle"] as? String {
                    var expectedResult = object.copy()
                    expectedResult.title = expectedTitle
                    expect(MyRemoteObjectManager.store[object.beamObjectId]) == expectedResult
                } else {
                    expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum) == (try checksum(object))
                }
            }
        }
    }
}

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
            BeamURLSession.shouldNotBeVinyled = true

            BeamObjectManager.disableSendingObjects = false
            BeamTestsHelper.login()

            BeamObjectManager.unregisterAll()
            sut.registerOnBeamObjectManager()

            try? MyRemoteObjectManager.deleteAll()
            try? BeamObjectChecksum.deleteAll()

            try? EncryptionManager.shared.replacePrivateKey(for: Configuration.testAccountEmail, with: Configuration.testPrivateKey)

            Configuration.beamObjectDirectCall = false
            Configuration.beamObjectOnRest = false
        }

        afterEach {
            beamHelper.endNetworkRecording()

            BeamDate.reset()
        }

        describe("refreshFromBeamObjectAPI()") {
            var object1: MyRemoteObject!

            beforeEach {
                self.createObjects()
                object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                Configuration.beamObjectDirectCall = false
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

                            waitUntil(timeout: .seconds(30)) { done in
                                _ = try? sut.refreshFromBeamObjectAPI(object1) { result in
                                    expect { try result.get() }.toNot(throwError())

                                    let remoteObject = try? result.get()

                                    let dateFormatter = ISO8601DateFormatter()
                                    let date = dateFormatter.date(from: "2021-03-19T12:21:13Z")

                                    expect(remoteObject?.updatedAt) == date
                                    expect(object1.updatedAt) == dateFormatter.date(from: fixedDate)
                                    expect(remoteObject?.title) == object1.title

                                    done()
                                }
                            }

                            expect(APIRequest.callsCount - networkCalls) == 2

                            let expectedNetworkCalls = ["beam_object_updated_at",
                                                        Beam.Configuration.beamObjectDataOnSeparateCall ? "beam_object_data_url" : "beam_object"]

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                        }
                    }

                    context("with async") {
                       asyncIt("fetches object") {
                           let networkCalls = APIRequest.callsCount

                           do {
                               let remoteObject = try await sut.refreshFromBeamObjectAPI(object1)

                               let dateFormatter = ISO8601DateFormatter()
                               let date = dateFormatter.date(from: "2021-03-19T12:21:13Z")

                               expect(remoteObject?.updatedAt) == date
                               expect(object1.updatedAt) == dateFormatter.date(from: fixedDate)
                               expect(remoteObject?.title) == object1.title
                           } catch {
                               fail(error.localizedDescription)

                           }

                           expect(APIRequest.callsCount - networkCalls) == 2

                           let expectedNetworkCalls = ["beam_object_updated_at",
                                                       Beam.Configuration.beamObjectDataOnSeparateCall ? "beam_object_data_url" : "beam_object"]

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

                                let expectedNetworkCalls = [Beam.Configuration.beamObjectDataOnSeparateCall ? "beam_object_data_url" : "beam_object"]

                                expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls
                            }
                        }

                        context("with async") {
                            asyncIt("fetches object") {
                                let networkCalls = APIRequest.callsCount

                                do {
                                    let remoteObject = try await sut.refreshFromBeamObjectAPI(object1, true)
                                    let dateFormatter = ISO8601DateFormatter()

                                    expect(remoteObject?.updatedAt) == dateFormatter.date(from: fixedDate)
                                    expect(object1.updatedAt) == dateFormatter.date(from: fixedDate)
                                } catch {
                                    fail(error.localizedDescription)
                                }

                                expect(APIRequest.callsCount - networkCalls) == 1

                                let expectedNetworkCalls = [Beam.Configuration.beamObjectDataOnSeparateCall ? "beam_object_data_url" : "beam_object"]

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

                        context("with async") {
                            asyncIt("doesnt't fetch object") {
                                let networkCalls = APIRequest.callsCount

                                do {
                                    let remoteObject = try await sut.refreshFromBeamObjectAPI(object1)
                                    expect(remoteObject).to(beNil())
                                } catch {
                                    fail(error.localizedDescription)
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

                context("with async") {
                    asyncIt("doesn't return error") {
                        let networkCalls = APIRequest.callsCount

                        do {
                            let remoteObject = try await sut.refreshFromBeamObjectAPI(object1)
                            expect(remoteObject).to(beNil())
                        } catch {
                            fail(error.localizedDescription)
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
                    it("doesn't have previousChecksum") {
                        for (_, object) in MyRemoteObjectManager.store {
                            expect(object.previousChecksum).to(beNil())
                        }
                    }

                    context("without direct upload") {
                        let beforeConfiguration = Configuration.beamObjectDataUploadOnSeparateCall
                        beforeEach { Configuration.beamObjectDataUploadOnSeparateCall = false }
                        afterEach { Configuration.beamObjectDataUploadOnSeparateCall = beforeConfiguration }

                        itBehavesLike("saveAllOnBeamObjectApi with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "callsCount": 1,
                             "networkCallFiles": ["sign_in", "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "callsCount": 1,
                             "networkCallFiles": ["sign_in", "update_beam_objects"]
                            ]
                        }
                    }

                    context("with direct upload") {
                        let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = true
                            Configuration.beamObjectDataOnSeparateCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload
                        }
                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "callsCount": 5,
                             "networkCallFiles": ["sign_in",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "callsCount": 5,
                             "networkCallFiles": ["sign_in",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }
                    }
                }

                context("when we send a previousChecksum") {
                    beforeEach {
                        for (key, object) in MyRemoteObjectManager.store {
                            try? BeamObjectChecksum.savePreviousChecksum(object: object,
                                                                         previousChecksum: "foobar".SHA256())
                            MyRemoteObjectManager.store[key] = object
                        }
                    }

                    context("without direct upload") {
                        let beforeConfiguration = Configuration.beamObjectDataUploadOnSeparateCall
                        beforeEach { Configuration.beamObjectDataUploadOnSeparateCall = false }
                        afterEach { Configuration.beamObjectDataUploadOnSeparateCall = beforeConfiguration }

                        itBehavesLike("saveAllOnBeamObjectApi with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "networkCallFiles": ["update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "networkCallFiles": ["update_beam_objects"]
                            ]
                        }
                    }

                    context("with direct upload") {
                        let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = true
                            Configuration.beamObjectDataOnSeparateCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload
                        }
                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "callsCount": 5,
                             "networkCallFiles": ["sign_in",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "callsCount": 5,
                             "networkCallFiles": ["sign_in",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }
                    }
                }
            }

            context("when all objects already exist, and we save all with 1 conflicted object") {
                let newTitle1 = "new Title1"

                context("with replace policy") {
                    context("without direct upload neither direct download") {
                        beforeEach {
                            Configuration.beamObjectDirectCall = false

                            self.saveAllObjectsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            // Create 1 conflicted object
                            object1.title = "fake"
                            object1.updatedAt = BeamDate.now
                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)

                            object1.title = newTitle1
                            MyRemoteObjectManager.store[object1.beamObjectId] = object1

                        }

                        itBehavesLike("saveAllOnBeamObjectApi with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "expectedTitle1": newTitle1,
                             "networkCallFiles": ["update_beam_objects",
                                                  "beam_object",
                                                  "update_beam_object"]
                            ]
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "expectedTitle1": newTitle1,
                             "networkCallFiles": ["update_beam_objects",
                                                  "beam_object",
                                                  "update_beam_object"]
                            ]
                        }
                    }

                    context("with direct upload and direct download") {
                        let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload

                            self.saveAllObjectsWithDirectUploadsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            // Create 1 conflicted object
                            object1.title = "fake"
                            object1.updatedAt = BeamDate.now
                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)

                            object1.title = newTitle1
                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "expectedTitle1": newTitle1,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "beam_object_data_url",
                                                  "direct_download",
                                                  "prepare_beam_object",
                                                  "direct_upload",
                                                  "update_beam_object"]
                            ]
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "expectedTitle1": newTitle1,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "beam_object_data_url",
                                                  "direct_download",
                                                  "prepare_beam_object",
                                                  "direct_upload",
                                                  "update_beam_object"]
                            ]
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

                    context("without direct upload neither direct download") {
                        beforeEach {
                            Configuration.beamObjectDirectCall = false

                            self.saveAllObjectsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            // Create 1 conflicted object
                            object1.title = "fake"
                            object1.updatedAt = BeamDate.now
                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)

                            object1.title = newTitle1
                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)",
                             "networkCallFiles": ["update_beam_objects",
                                                  "beam_object",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)",
                             "networkCallFiles": ["update_beam_objects",
                                                  "beam_object",
                                                  "update_beam_objects"]
                            ]
                        }
                    }

                    context("with direct upload and direct download") {
                        let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload

                            self.saveAllObjectsWithDirectUploadsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            // Create 1 conflicted object
                            object1.title = "fake"
                            object1.updatedAt = BeamDate.now
                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)

                            object1.title = newTitle1
                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)",
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "beam_object_data_url",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)",
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "beam_object_data_url",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }

                    }
                }
            }

            context("when all objects exist, and with save with multiple conflicted object") {
                let newTitle1 = "new Title1"
                let newTitle2 = "new Title2"

                context("with replace policy") {
                    context("without direct upload neither direct download") {
                        beforeEach {
                            Configuration.beamObjectDirectCall = false

                            self.saveAllObjectsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            // Create 2 conflicted objects

                            object1.title = "fake"
                            object2.title = "fake"

                            object1.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now

                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            MyRemoteObjectManager.store[object2.beamObjectId] = object2

                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object2)

                            object1.title = newTitle1
                            object2.title = newTitle2

                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            MyRemoteObjectManager.store[object2.beamObjectId] = object2
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "networkCallFiles": ["update_beam_objects",
                                                  "paginated_beam_objects",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "networkCallFiles": ["update_beam_objects",
                                                  "paginated_beam_objects",
                                                  "update_beam_objects"]
                            ]
                        }
                    }

                    context("with direct upload and direct download") {
                        let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload

                            self.saveAllObjectsWithDirectUploadsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            // Create 2 conflicted objects

                            object1.title = "fake"
                            object2.title = "fake"

                            object1.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now

                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            MyRemoteObjectManager.store[object2.beamObjectId] = object2

                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object2)

                            object1.title = newTitle1
                            object2.title = newTitle2

                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            MyRemoteObjectManager.store[object2.beamObjectId] = object2
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "paginated_beam_objects_data_url",
                                                  "direct_download",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "paginated_beam_objects_data_url",
                                                  "direct_download",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
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

                    context("without direct upload neither direct download") {
                        beforeEach {
                            Configuration.beamObjectDirectCall = false

                            self.saveAllObjectsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            // Create 2 conflicted objects

                            object1.title = "fake"
                            object2.title = "fake"

                            object1.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now

                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            MyRemoteObjectManager.store[object2.beamObjectId] = object2

                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object2)

                            object1.title = newTitle1
                            object2.title = newTitle2

                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            MyRemoteObjectManager.store[object2.beamObjectId] = object2
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)",
                             "expectedTitle2": "merged: \(newTitle2)\(title2!)",
                             "networkCallFiles": ["update_beam_objects",
                                                  "paginated_beam_objects",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)",
                             "expectedTitle2": "merged: \(newTitle2)\(title2!)",
                             "networkCallFiles": ["update_beam_objects",
                                                  "paginated_beam_objects",
                                                  "update_beam_objects"]
                            ]
                        }
                    }

                    context("with direct upload and direct download") {
                        let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload

                            self.saveAllObjectsWithDirectUploadsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            // Create 2 conflicted objects

                            object1.title = "fake"
                            object2.title = "fake"

                            object1.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now

                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            MyRemoteObjectManager.store[object2.beamObjectId] = object2

                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object2)

                            object1.title = newTitle1
                            object2.title = newTitle2

                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            MyRemoteObjectManager.store[object2.beamObjectId] = object2
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)",
                             "expectedTitle2": "merged: \(newTitle2)\(title2!)",
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "paginated_beam_objects_data_url",
                                                  "direct_download",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)",
                             "expectedTitle2": "merged: \(newTitle2)\(title2!)",
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "paginated_beam_objects_data_url",
                                                  "direct_download",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }
                    }
                }
            }

            context("when all objects exist, and we save with all objects in conflict") {
                let newTitle1 = "new Title1"
                let newTitle2 = "new Title2"
                let newTitle3 = "new Title3"

                context("with replace policy") {
                    context("without direct upload neither direct download") {
                        beforeEach {
                            Configuration.beamObjectDirectCall = false

                            self.saveAllObjectsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            object1.title = "fake"
                            object2.title = "fake"
                            object3.title = "fake"

                            object1.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now
                            object3.updatedAt = BeamDate.now

                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            MyRemoteObjectManager.store[object2.beamObjectId] = object2
                            MyRemoteObjectManager.store[object3.beamObjectId] = object3

                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object2)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object3)

                            object1.title = newTitle1
                            object2.title = newTitle2
                            object3.title = newTitle3

                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            MyRemoteObjectManager.store[object2.beamObjectId] = object2
                            MyRemoteObjectManager.store[object3.beamObjectId] = object3
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "networkCallFiles": ["update_beam_objects",
                                                  "paginated_beam_objects",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "networkCallFiles": ["update_beam_objects",
                                                  "paginated_beam_objects",
                                                  "update_beam_objects"]
                            ]
                        }
                    }

                    context("with direct upload and direct download") {
                        let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload

                            self.saveAllObjectsWithDirectUploadsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            object1.title = "fake"
                            object2.title = "fake"
                            object3.title = "fake"

                            object1.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now
                            object3.updatedAt = BeamDate.now

                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            MyRemoteObjectManager.store[object2.beamObjectId] = object2
                            MyRemoteObjectManager.store[object3.beamObjectId] = object3

                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object2)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object3)

                            object1.title = newTitle1
                            object2.title = newTitle2
                            object3.title = newTitle3

                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            MyRemoteObjectManager.store[object2.beamObjectId] = object2
                            MyRemoteObjectManager.store[object3.beamObjectId] = object3
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "paginated_beam_objects_data_url",
                                                  "direct_download",
                                                  "direct_download",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "paginated_beam_objects_data_url",
                                                  "direct_download",
                                                  "direct_download",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
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

                    context("without direct upload neither direct download") {
                        beforeEach {
                            Configuration.beamObjectDirectCall = false

                            self.saveAllObjectsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            object1.title = "fake"
                            object2.title = "fake"
                            object3.title = "fake"

                            object1.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now
                            object3.updatedAt = BeamDate.now

                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            MyRemoteObjectManager.store[object2.beamObjectId] = object2
                            MyRemoteObjectManager.store[object3.beamObjectId] = object3

                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object2)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object3)

                            object1.title = newTitle1
                            object2.title = newTitle2
                            object3.title = newTitle3

                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            MyRemoteObjectManager.store[object2.beamObjectId] = object2
                            MyRemoteObjectManager.store[object3.beamObjectId] = object3
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)" as String,
                             "expectedTitle2": "merged: \(newTitle2)\(title2!)" as String,
                             "expectedTitle3": "merged: \(newTitle3)\(title3!)" as String,

                             "networkCallFiles": ["update_beam_objects",
                                                  Beam.Configuration.beamObjectDataOnSeparateCall ? "paginated_beam_objects_data_url" : "paginated_beam_objects",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)" as String,
                             "expectedTitle2": "merged: \(newTitle2)\(title2!)" as String,
                             "expectedTitle3": "merged: \(newTitle3)\(title3!)" as String,

                             "networkCallFiles": ["update_beam_objects",
                                                  Beam.Configuration.beamObjectDataOnSeparateCall ? "paginated_beam_objects_data_url" : "paginated_beam_objects",
                                                  "update_beam_objects"]
                            ]
                        }
                    }

                    context("with direct upload and direct download") {
                        let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload

                            self.saveAllObjectsWithDirectUploadsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            object1.title = "fake"
                            object2.title = "fake"
                            object3.title = "fake"

                            object1.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now
                            object3.updatedAt = BeamDate.now

                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            MyRemoteObjectManager.store[object2.beamObjectId] = object2
                            MyRemoteObjectManager.store[object3.beamObjectId] = object3

                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object2)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object3)

                            object1.title = newTitle1
                            object2.title = newTitle2
                            object3.title = newTitle3

                            MyRemoteObjectManager.store[object1.beamObjectId] = object1
                            MyRemoteObjectManager.store[object2.beamObjectId] = object2
                            MyRemoteObjectManager.store[object3.beamObjectId] = object3
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)" as String,
                             "expectedTitle2": "merged: \(newTitle2)\(title2!)" as String,
                             "expectedTitle3": "merged: \(newTitle3)\(title3!)" as String,

                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "paginated_beam_objects_data_url",
                                                  "direct_download",
                                                  "direct_download",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveAllOnBeamObjectApi with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)" as String,
                             "expectedTitle2": "merged: \(newTitle2)\(title2!)" as String,
                             "expectedTitle3": "merged: \(newTitle3)\(title3!)" as String,

                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "paginated_beam_objects_data_url",
                                                  "direct_download",
                                                  "direct_download",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
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
                    it("doesn't have previousChecksums") {
                        for (_, object) in MyRemoteObjectManager.store {
                            expect(object.previousChecksum).to(beNil())
                        }
                    }

                    context("without direct upload neither direct download") {
                        let beforeConfiguration = Configuration.beamObjectDataUploadOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = false
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfiguration
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "callsCount": 1,
                             "networkCallFiles": ["sign_in", "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "callsCount": 1,
                             "networkCallFiles": ["sign_in", "update_beam_objects"]
                            ]
                        }
                    }

                    context("with direct upload and direct download") {
                        let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "callsCount": 5,
                             "networkCallFiles": ["sign_in",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "callsCount": 5,
                             "networkCallFiles": ["sign_in",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }
                    }
                }

                context("when we send a previousChecksum") {
                    beforeEach {
                        for object in MyRemoteObjectManager.store.values {
                            try? BeamObjectChecksum.savePreviousChecksum(object: object,
                                                                         previousChecksum: "foobar".SHA256())
                        }
                    }

                    context("without direct upload neither direct download") {
                        let beforeConfiguration = Configuration.beamObjectDataUploadOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = false
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfiguration
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "callsCount": 1,
                             "networkCallFiles": ["sign_in", "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "callsCount": 1,
                             "networkCallFiles": ["sign_in", "update_beam_objects"]
                            ]
                        }
                    }

                    context("with direct upload and direct download") {
                        let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "callsCount": 5,
                             "networkCallFiles": ["sign_in",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "callsCount": 5,
                             "networkCallFiles": ["sign_in",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
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

                context("Foundation") {
                    context("without direct upload") {
                        let beforeConfiguration = Configuration.beamObjectDataUploadOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = false
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfiguration
                        }

                        it("doesn't generate conflicts") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                do {
                                    let group = DispatchGroup()

                                    group.enter()
                                    _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3], force: true) { _ in group.leave() }

                                    group.enter()
                                    _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3], force: true) { result in
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

                            let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1)
                            expect(object1) == remoteObject1

                            let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2)
                            expect(object2) == remoteObject2

                            let remoteObject3: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object3)
                            expect(object3) == remoteObject3
                        }
                    }

                    context("with direct upload") {
                        let beforeConfiguration = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration2 = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = true
                            Configuration.beamObjectDataOnSeparateCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfiguration
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration2
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        it("doesn't generate conflicts") {
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                do {
                                    let group = DispatchGroup()

                                    group.enter()
                                    _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3], force: true) { _ in group.leave() }

                                    group.enter()
                                    _ = try sut.saveOnBeamObjectsAPI([object1, object2, object3], force: true) { result in
                                        expect { try result.get() }.toNot(throwError())

                                        group.leave()
                                    }

                                    group.wait()
                                    done()

                                } catch {
                                    fail(error.localizedDescription)
                                }
                            }

                            let expectedNetworkCalls = ["prepare_beam_objects",
                                                        "direct_upload",
                                                        "direct_upload",
                                                        "direct_upload",
                                                        "update_beam_objects",
                                                        "prepare_beam_objects",
                                                        "direct_upload",
                                                        "direct_upload",
                                                        "direct_upload",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count
                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1)
                            expect(object1) == remoteObject1

                            let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2)
                            expect(object2) == remoteObject2

                            let remoteObject3: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object3)
                            expect(object3) == remoteObject3
                        }
                    }
                }

                context("with async") {
                    context("without direct upload") {
                        let beforeConfiguration = Configuration.beamObjectDataUploadOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = false
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfiguration
                        }

                        asyncIt("doesn't generate conflicts") {
                            let networkCalls = APIRequest.callsCount

                            do {
                                _ = try await sut.saveOnBeamObjectsAPI([object1, object2, object3], force: true)

                                _ = try await sut.saveOnBeamObjectsAPI([object1, object2, object3], force: true)
                            } catch {
                                fail(error.localizedDescription)
                            }

                            let expectedNetworkCalls = ["update_beam_objects", "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count
                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1)
                            expect(object1) == remoteObject1

                            let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2)
                            expect(object2) == remoteObject2

                            let remoteObject3: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object3)
                            expect(object3) == remoteObject3
                        }
                    }

                    context("with direct upload") {
                        let beforeConfiguration = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration2 = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = true
                            Configuration.beamObjectDataOnSeparateCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfiguration
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration2
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        asyncIt("doesn't generate conflicts") {
                            let networkCalls = APIRequest.callsCount

                            do {
                                _ = try await sut.saveOnBeamObjectsAPI([object1, object2, object3], force: true)

                                _ = try await sut.saveOnBeamObjectsAPI([object1, object2, object3], force: true)
                            } catch {
                                fail(error.localizedDescription)
                            }

                            let expectedNetworkCalls = ["prepare_beam_objects",
                                                        "direct_upload",
                                                        "direct_upload",
                                                        "direct_upload",
                                                        "update_beam_objects",
                                                        "prepare_beam_objects",
                                                        "direct_upload",
                                                        "direct_upload",
                                                        "direct_upload",
                                                        "update_beam_objects"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count
                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            let remoteObject1: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object1)
                            expect(object1) == remoteObject1

                            let remoteObject2: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object2)
                            expect(object2) == remoteObject2

                            let remoteObject3: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object3)
                            expect(object3) == remoteObject3
                        }
                    }
                }
            }


            context("when all objects already exist, and we save all with 1 conflicted object") {
                let newTitle1 = "new Title1"

                context("with replace policy") {
                    context("without direct upload neither direct download") {
                        beforeEach {
                            Configuration.beamObjectDirectCall = false
                            self.saveAllObjectsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            // Create 1 conflicted object
                            object1.title = "fake"
                            object1.updatedAt = BeamDate.now
                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)

                            object1.title = newTitle1
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "networkCallFiles": ["update_beam_objects",
                                                  "beam_object",
                                                  "update_beam_object"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "networkCallFiles": ["update_beam_objects",
                                                  "beam_object",
                                                  "update_beam_object"]
                            ]
                        }
                    }

                    context("with direct upload and direct download") {
                        let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload
                            self.saveAllObjectsWithDirectUploadsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            // Create 1 conflicted object
                            object1.title = "fake"
                            object1.updatedAt = BeamDate.now
                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)

                            object1.title = newTitle1
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "beam_object_data_url",
                                                  "direct_download",
                                                  "prepare_beam_object",
                                                  "direct_upload",
                                                  "update_beam_object"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "beam_object_data_url",
                                                  "direct_download",
                                                  "prepare_beam_object",
                                                  "direct_upload",
                                                  "update_beam_object"]
                            ]
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

                    context("without direct upload neither direct download") {
                        let beforeConfiguration = Configuration.beamObjectDataUploadOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = false
                            self.saveAllObjectsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            // Create 1 conflicted object
                            object1.title = "fake"
                            object1.updatedAt = BeamDate.now
                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)

                            object1.title = newTitle1
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfiguration
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)" as String,
                             "networkCallFiles": ["update_beam_objects",
                                                  "beam_object",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)" as String,
                             "networkCallFiles": ["update_beam_objects",
                                                  "beam_object",
                                                  "update_beam_objects"]
                            ]
                        }
                    }

                    context("with direct upload and direct download") {
                        let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload
                            self.saveAllObjectsWithDirectUploadsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            // Create 1 conflicted object
                            object1.title = "fake"
                            object1.updatedAt = BeamDate.now
                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)

                            object1.title = newTitle1
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)" as String,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "beam_object_data_url",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)" as String,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "beam_object_data_url",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }
                    }
                }
            }

            context("when all objects exist, and with save with multiple conflicted object") {
                let newTitle1 = "new Title1"
                let newTitle2 = "new Title2"

                context("with replace policy") {
                    context("without direct upload neither direct download") {
                        beforeEach {
                            Configuration.beamObjectDirectCall = false
                            self.saveAllObjectsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            // Create 2 conflicted objects
                            BeamDate.travel(2)

                            object1.title = "fake"
                            object2.title = "fake"

                            object1.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now

                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object2)

                            object1.title = newTitle1
                            object2.title = newTitle2
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "networkCallFiles": ["update_beam_objects",
                                                  "paginated_beam_objects",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "networkCallFiles": ["update_beam_objects",
                                                  "paginated_beam_objects",
                                                  "update_beam_objects"]
                            ]
                        }
                    }

                    context("with direct upload and direct download") {
                        let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload

                            self.saveAllObjectsWithDirectUploadsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            // Create 2 conflicted objects
                            BeamDate.travel(2)

                            object1.title = "fake"
                            object2.title = "fake"

                            object1.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now

                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object2)

                            object1.title = newTitle1
                            object2.title = newTitle2
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "paginated_beam_objects_data_url",
                                                  "direct_download",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "paginated_beam_objects_data_url",
                                                  "direct_download",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
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

                    context("without direct upload neither direct download") {
                        let beforeConfiguration = Configuration.beamObjectDataUploadOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = false
                            self.saveAllObjectsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            // Create 2 conflicted objects
                            BeamDate.travel(2)

                            object1.title = "fake"
                            object2.title = "fake"

                            object1.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now

                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object2)

                            object1.title = newTitle1
                            object2.title = newTitle2
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfiguration
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)" as String,
                             "expectedTitle2": "merged: \(newTitle2)\(title2!)" as String,
                             "networkCallFiles": ["update_beam_objects",
                                                  "paginated_beam_objects",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)" as String,
                             "expectedTitle2": "merged: \(newTitle2)\(title2!)" as String,
                             "networkCallFiles": ["update_beam_objects",
                                                  "paginated_beam_objects",
                                                  "update_beam_objects"]
                            ]
                        }
                    }

                    context("with direct upload and direct download") {
                        let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload
                            self.saveAllObjectsWithDirectUploadsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            // Create 2 conflicted objects
                            BeamDate.travel(2)

                            object1.title = "fake"
                            object2.title = "fake"

                            object1.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now

                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object2)

                            object1.title = newTitle1
                            object2.title = newTitle2
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)" as String,
                             "expectedTitle2": "merged: \(newTitle2)\(title2!)" as String,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "paginated_beam_objects_data_url",
                                                  "direct_download",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)" as String,
                             "expectedTitle2": "merged: \(newTitle2)\(title2!)" as String,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "paginated_beam_objects_data_url",
                                                  "direct_download",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }
                    }
                }
            }

            context("when all objects exist, and we save with all objects in conflict") {
                let newTitle1 = "new Title1"
                let newTitle2 = "new Title2"
                let newTitle3 = "new Title3"

                context("with replace policy") {
                    context("without direct upload neither direct download") {
                        let beforeConfiguration = Configuration.beamObjectDataUploadOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = false
                            self.saveAllObjectsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            object1.title = "fake"
                            object2.title = "fake"
                            object3.title = "fake"

                            object1.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now
                            object3.updatedAt = BeamDate.now

                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object2)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object3)

                            object1.title = newTitle1
                            object2.title = newTitle2
                            object3.title = newTitle3
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfiguration
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "networkCallFiles": ["update_beam_objects",
                                                  "paginated_beam_objects",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "networkCallFiles": ["update_beam_objects",
                                                  "paginated_beam_objects",
                                                  "update_beam_objects"]
                            ]
                        }
                    }

                    context("with direct upload and direct download") {
                        let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload
                            self.saveAllObjectsWithDirectUploadsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            object1.title = "fake"
                            object2.title = "fake"
                            object3.title = "fake"

                            object1.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now
                            object3.updatedAt = BeamDate.now

                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object2)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object3)

                            object1.title = newTitle1
                            object2.title = newTitle2
                            object3.title = newTitle3
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "paginated_beam_objects_data_url",
                                                  "direct_download",
                                                  "direct_download",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "paginated_beam_objects_data_url",
                                                  "direct_download",
                                                  "direct_download",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
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

                    context("without direct upload neither direct download") {
                        let beforeConfiguration = Configuration.beamObjectDataUploadOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = false
                            self.saveAllObjectsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            object1.title = "fake"
                            object2.title = "fake"
                            object3.title = "fake"

                            object1.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now
                            object3.updatedAt = BeamDate.now

                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object2)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object3)

                            object1.title = newTitle1
                            object2.title = newTitle2
                            object3.title = newTitle3
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfiguration
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)" as String,
                             "expectedTitle2": "merged: \(newTitle2)\(title2!)" as String,
                             "expectedTitle3": "merged: \(newTitle3)\(title3!)" as String,
                             "networkCallFiles": ["update_beam_objects",
                                                  "paginated_beam_objects",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)" as String,
                             "expectedTitle2": "merged: \(newTitle2)\(title2!)" as String,
                             "expectedTitle3": "merged: \(newTitle3)\(title3!)" as String,
                             "networkCallFiles": ["update_beam_objects",
                                                  "paginated_beam_objects",
                                                  "update_beam_objects"]
                            ]
                        }
                    }

                    context("with direct upload and direct download") {
                        let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload
                            self.saveAllObjectsWithDirectUploadsAndSaveChecksum()

                            object1 = self.objectForUUID("195d94e1-e0df-4eca-93e6-8778984bcd58")
                            object2 = self.objectForUUID("295d94e1-e0df-4eca-93e6-8778984bcd58")
                            object3 = self.objectForUUID("395d94e1-e0df-4eca-93e6-8778984bcd58")

                            title1 = object1.title!
                            title2 = object2.title!
                            title3 = object3.title!

                            BeamDate.travel(2)

                            object1.title = "fake"
                            object2.title = "fake"
                            object3.title = "fake"

                            object1.updatedAt = BeamDate.now
                            object2.updatedAt = BeamDate.now
                            object3.updatedAt = BeamDate.now

                            try? BeamObjectChecksum.savePreviousChecksum(object: object1)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object2)
                            try? BeamObjectChecksum.savePreviousChecksum(object: object3)

                            object1.title = newTitle1
                            object2.title = newTitle2
                            object3.title = newTitle3
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)" as String,
                             "expectedTitle2": "merged: \(newTitle2)\(title2!)" as String,
                             "expectedTitle3": "merged: \(newTitle3)\(title3!)" as String,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "paginated_beam_objects_data_url",
                                                  "direct_download",
                                                  "direct_download",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectsAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object1": object1 as MyRemoteObject,
                             "object2": object2 as MyRemoteObject,
                             "object3": object3 as MyRemoteObject,
                             "expectedTitle1": "merged: \(newTitle1)\(title1!)" as String,
                             "expectedTitle2": "merged: \(newTitle2)\(title2!)" as String,
                             "expectedTitle3": "merged: \(newTitle3)\(title3!)" as String,
                             "networkCallFiles": ["prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects",
                                                  "paginated_beam_objects_data_url",
                                                  "direct_download",
                                                  "direct_download",
                                                  "direct_download",
                                                  "prepare_beam_objects",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "direct_upload",
                                                  "update_beam_objects"]
                            ]
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
                                        title: title)
                MyRemoteObjectManager.store[object.beamObjectId] = object
            }

            afterEach {
                beamObjectHelper.deleteAll()
                MyRemoteObjectManager.store.removeAll()
            }

            context("when object doesn't exist on the API") {
                context("when we don't send previousChecksum") {
                    it("starts without checksum") {
                        expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum).to(beNil())
                    }

                    context("without direct upload") {
                        let beforeConfiguration = Configuration.beamObjectDataUploadOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = false
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfiguration
                        }

                        itBehavesLike("saveOnBeamObjectAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object": object as MyRemoteObject,
                             "callsCount": 1,
                             "networkCallFiles": ["sign_in", "update_beam_object"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object": object as MyRemoteObject,
                             "callsCount": 1,
                             "networkCallFiles": ["sign_in", "update_beam_object"]
                            ]
                        }
                    }

                    context("with direct upload") {
                        let beforeConfiguration = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration2 = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = true
                            Configuration.beamObjectDataOnSeparateCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfiguration
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration2
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveOnBeamObjectAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object": object as MyRemoteObject,
                             "callsCount": 3,
                             "networkCallFiles": ["sign_in",
                                                  "prepare_beam_object",
                                                  "direct_upload",
                                                  "update_beam_object"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object": object as MyRemoteObject,
                             "callsCount": 3,
                             "networkCallFiles": ["sign_in",
                                                  "prepare_beam_object",
                                                  "direct_upload",
                                                  "update_beam_object"]
                            ]
                        }
                    }
                }

                context("when we send a previousChecksum") {
                    beforeEach {
                        try? BeamObjectChecksum.savePreviousChecksum(object: MyRemoteObjectManager.store[object.beamObjectId]!,
                                                                     previousChecksum: "foobar".SHA256())
                    }

                    it("starts without checksum") {
                        expect(MyRemoteObjectManager.store[object.beamObjectId]?.previousChecksum).notTo(beNil())
                    }

                    context("without direct upload") {
                        let beforeConfiguration = Configuration.beamObjectDataUploadOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDirectCall = false
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfiguration
                        }

                        itBehavesLike("saveOnBeamObjectAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object": object as MyRemoteObject,
                             "callsCount": 1,
                             "networkCallFiles": ["sign_in", "update_beam_object"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object": object as MyRemoteObject,
                             "callsCount": 1,
                             "networkCallFiles": ["sign_in", "update_beam_object"]
                            ]
                        }
                    }

                    context("with direct upload") {
                        let beforeConfiguration = Configuration.beamObjectDataUploadOnSeparateCall
                        let beforeConfiguration2 = Configuration.beamObjectDataOnSeparateCall

                        beforeEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = true
                            Configuration.beamObjectDataOnSeparateCall = true
                            BeamObjectManager.uploadTypeForTests = .directUpload
                        }

                        afterEach {
                            Configuration.beamObjectDataUploadOnSeparateCall = beforeConfiguration
                            Configuration.beamObjectDataOnSeparateCall = beforeConfiguration2
                            BeamObjectManager.uploadTypeForTests = .multipartUpload
                        }

                        itBehavesLike("saveOnBeamObjectAPI with Foundation") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object": object as MyRemoteObject,
                             "callsCount": 3,
                             "networkCallFiles": ["sign_in",
                                                  "prepare_beam_object",
                                                  "direct_upload",
                                                  "update_beam_object"]
                            ]
                        }

                        itBehavesLike("saveOnBeamObjectAPI with async") {
                            ["sut": sut as MyRemoteObjectManager,
                             "object": object as MyRemoteObject,
                             "callsCount": 3,
                             "networkCallFiles": ["sign_in",
                                                  "prepare_beam_object",
                                                  "direct_upload",
                                                  "update_beam_object"]
                            ]
                        }
                    }
                }
            }

            context("when object already exist on the API") {
                context("when called twice") {
                    let newTitle = "new Title"

                    beforeEach {
                        beamObjectHelper.saveOnAPIAndSaveChecksum(object)
                    }

                    context("with Foundation") {
                        it("doesn't generate conflicts") {
                            object.title = newTitle
                            let networkCalls = APIRequest.callsCount

                            waitUntil(timeout: .seconds(10)) { done in
                                do {
                                    let group = DispatchGroup()

                                    group.enter()

                                    _ = try sut.saveOnBeamObjectAPI(object, force: true) { _ in group.leave() }

                                    group.enter()

                                    _ = try sut.saveOnBeamObjectAPI(object, force: true) { result in
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

                            let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object)
                            expect(object) == remoteObject
                        }
                    }

                    context("with async") {
                        asyncIt("doesn't generate conflicts") {
                            object.title = newTitle
                            let networkCalls = APIRequest.callsCount

                            do {
                                _ = try await sut.saveOnBeamObjectAPI(object, force: true)
                                _ = try await sut.saveOnBeamObjectAPI(object, force: true)
                            } catch {
                                fail(error.localizedDescription)
                            }

                            let expectedNetworkCalls = ["update_beam_object", "update_beam_object"]

                            expect(APIRequest.callsCount - networkCalls) == expectedNetworkCalls.count

                            expect(APIRequest.networkCallFiles.suffix(expectedNetworkCalls.count)) == expectedNetworkCalls

                            let remoteObject: MyRemoteObject? = try beamObjectHelper.fetchOnAPI(object)
                            expect(object) == remoteObject
                        }
                    }
                }

                context("with conflict") {
                    let newTitle = "new Title"

                    context("with replace policy") {
                        context("without direct upload neither direct download") {
                            beforeEach {
                                Configuration.beamObjectDirectCall = false

                                beamObjectHelper.saveOnAPIAndSaveChecksum(object)

                                BeamDate.travel(2)

                                // Create 1 conflicted object
                                object.updatedAt = BeamDate.now
                                try? BeamObjectChecksum.savePreviousChecksum(object: object)

                                object.title = newTitle
                            }

                            itBehavesLike("saveOnBeamObjectAPI with Foundation") {
                                ["sut": sut as MyRemoteObjectManager,
                                 "object": object as MyRemoteObject,
                                 "networkCallFiles": ["update_beam_object",
                                                      "beam_object",
                                                      "update_beam_object"]
                                ]
                            }

                            itBehavesLike("saveOnBeamObjectAPI with async") {
                                ["sut": sut as MyRemoteObjectManager,
                                 "object": object as MyRemoteObject,
                                 "networkCallFiles": ["update_beam_object",
                                                      "beam_object",
                                                      "update_beam_object"]
                                ]
                            }
                        }

                        context("with direct upload and direct download") {
                            let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                            let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                            beforeEach {
                                Configuration.beamObjectDirectCall = true
                                BeamObjectManager.uploadTypeForTests = .directUpload

                                beamObjectHelper.saveOnAPIWithDirectUploadAndSaveChecksum(object)

                                BeamDate.travel(2)

                                // Create 1 conflicted object
                                object.updatedAt = BeamDate.now
                                try? BeamObjectChecksum.savePreviousChecksum(object: object)

                                object.title = newTitle
                            }

                            afterEach {
                                Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                                Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                                BeamObjectManager.uploadTypeForTests = .multipartUpload
                            }

                            itBehavesLike("saveOnBeamObjectAPI with Foundation") {
                                ["sut": sut as MyRemoteObjectManager,
                                 "object": object as MyRemoteObject,
                                 "networkCallFiles": ["prepare_beam_object",
                                                      "direct_upload",
                                                      "update_beam_object",
                                                      "beam_object_data_url",
                                                      "direct_download",
                                                      "prepare_beam_object",
                                                      "direct_upload",
                                                      "update_beam_object"]
                                ]
                            }

                            itBehavesLike("saveOnBeamObjectAPI with async") {
                                ["sut": sut as MyRemoteObjectManager,
                                 "object": object as MyRemoteObject,
                                 "networkCallFiles": ["prepare_beam_object",
                                                      "direct_upload",
                                                      "update_beam_object",
                                                      "beam_object_data_url",
                                                      "direct_download",
                                                      "prepare_beam_object",
                                                      "direct_upload",
                                                      "update_beam_object"]
                                ]
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

                        context("without direct upload neither direct download") {
                            beforeEach {
                                Configuration.beamObjectDirectCall = false

                                beamObjectHelper.saveOnAPIAndSaveChecksum(object)

                                BeamDate.travel(2)

                                // Create 1 conflicted object
                                object.updatedAt = BeamDate.now
                                try? BeamObjectChecksum.savePreviousChecksum(object: object)

                                object.title = newTitle
                            }

                            itBehavesLike("saveOnBeamObjectAPI with Foundation") {
                                ["sut": sut as MyRemoteObjectManager,
                                 "object": object as MyRemoteObject,
                                 "expectedTitle": "merged: \(newTitle)\(title)",
                                 "networkCallFiles": ["update_beam_object",
                                                      Beam.Configuration.beamObjectDataOnSeparateCall ? "beam_object_data_url" : "beam_object",
                                                      "update_beam_objects"]
                                ]
                            }

                            itBehavesLike("saveOnBeamObjectAPI with async") {
                                ["sut": sut as MyRemoteObjectManager,
                                 "object": object as MyRemoteObject,
                                 "expectedTitle": "merged: \(newTitle)\(title)",
                                 "networkCallFiles": ["update_beam_object",
                                                      Beam.Configuration.beamObjectDataOnSeparateCall ? "beam_object_data_url" : "beam_object",
                                                      "update_beam_objects"]
                                ]
                            }
                        }

                        context("with direct upload and direct download") {
                            let beforeConfigurationUpload = Configuration.beamObjectDataUploadOnSeparateCall
                            let beforeConfiguration = Configuration.beamObjectDataOnSeparateCall

                            beforeEach {
                                Configuration.beamObjectDirectCall = true
                                BeamObjectManager.uploadTypeForTests = .directUpload

                                beamObjectHelper.saveOnAPIWithDirectUploadAndSaveChecksum(object)

                                BeamDate.travel(2)

                                // Create 1 conflicted object
                                object.updatedAt = BeamDate.now
                                try? BeamObjectChecksum.savePreviousChecksum(object: object)

                                object.title = newTitle
                            }

                            afterEach {
                                Configuration.beamObjectDataUploadOnSeparateCall = beforeConfigurationUpload
                                Configuration.beamObjectDataOnSeparateCall = beforeConfiguration
                                BeamObjectManager.uploadTypeForTests = .multipartUpload
                            }

                            itBehavesLike("saveOnBeamObjectAPI with Foundation") {
                                ["sut": sut as MyRemoteObjectManager,
                                 "object": object as MyRemoteObject,
                                 "expectedTitle": "merged: \(newTitle)\(title)",
                                 "networkCallFiles": ["prepare_beam_object",
                                                      "direct_upload",
                                                      "update_beam_object",
                                                      "beam_object_data_url",
                                                      "direct_download",
                                                      "prepare_beam_objects",
                                                      "direct_upload",
                                                      "update_beam_objects"]
                                ]
                            }

                            itBehavesLike("saveOnBeamObjectAPI with async") {
                                ["sut": sut as MyRemoteObjectManager,
                                 "object": object as MyRemoteObject,
                                 "expectedTitle": "merged: \(newTitle)\(title)",
                                 "networkCallFiles": ["prepare_beam_object",
                                                      "direct_upload",
                                                      "update_beam_object",
                                                      "beam_object_data_url",
                                                      "direct_download",
                                                      "prepare_beam_objects",
                                                      "direct_upload",
                                                      "update_beam_objects"]
                                ]
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
                                     title: "Object 1")

        let object2 = MyRemoteObject(beamObjectId: "295d94e1-e0df-4eca-93e6-8778984bcd58".uuid ?? UUID(),
                                     createdAt: BeamDate.now,
                                     updatedAt: BeamDate.now,
                                     deletedAt: nil,
                                     title: "Object 2")

        let object3 = MyRemoteObject(beamObjectId: "395d94e1-e0df-4eca-93e6-8778984bcd58".uuid ?? UUID(),
                                     createdAt: BeamDate.now,
                                     updatedAt: BeamDate.now,
                                     deletedAt: nil,
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
    private func checksum(_ object: MyRemoteObject) throws -> String? {
        try? BeamObject(object).dataChecksum
    }

    /// Save all objects on the API, and store their checksum
    private func saveAllObjectsAndSaveChecksum() {
        // Can't do `forEach` or vinyl and save will break it
        let beamObjectHelper = BeamObjectTestsHelper()

        beamObjectHelper.saveOnAPIAndSaveChecksum(MyRemoteObjectManager.store["195d94e1-e0df-4eca-93e6-8778984bcd58".uuid!]!)
        beamObjectHelper.saveOnAPIAndSaveChecksum(MyRemoteObjectManager.store["295d94e1-e0df-4eca-93e6-8778984bcd58".uuid!]!)
        beamObjectHelper.saveOnAPIAndSaveChecksum(MyRemoteObjectManager.store["395d94e1-e0df-4eca-93e6-8778984bcd58".uuid!]!)
    }

    /// Save all objects on the API, and store their checksum
    private func saveAllObjectsWithDirectUploadsAndSaveChecksum() {
        // Can't do `forEach` or vinyl and save will break it
        let beamObjectHelper = BeamObjectTestsHelper()

        beamObjectHelper.saveOnAPIWithDirectUploadAndSaveChecksum(MyRemoteObjectManager.store["195d94e1-e0df-4eca-93e6-8778984bcd58".uuid!]!)
        beamObjectHelper.saveOnAPIWithDirectUploadAndSaveChecksum(MyRemoteObjectManager.store["295d94e1-e0df-4eca-93e6-8778984bcd58".uuid!]!)
        beamObjectHelper.saveOnAPIWithDirectUploadAndSaveChecksum(MyRemoteObjectManager.store["395d94e1-e0df-4eca-93e6-8778984bcd58".uuid!]!)
    }
}
