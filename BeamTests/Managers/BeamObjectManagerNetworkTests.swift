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
        }

        describe("saveToAPI") {
            var object: MyRemoteObject!
            let title = "This is my title"
            let newTitle = "This is a new title"

            beforeEach {
                object = MyRemoteObject(beamObjectId: UUID(),
                                        createdAt: BeamDate.now,
                                        updatedAt: BeamDate.now,
                                        deletedAt: nil,
                                        previousChecksum: nil,
                                        checksum: nil,
                                        title: title)
            }

            afterEach {
                let semaphore = DispatchSemaphore(value: 0)
                sut.delete(object.beamObjectId) { _ in
                    semaphore.signal()
                }

                _ = semaphore.wait(timeout: DispatchTime.now() + .seconds(5))
            }

            context("with Foundation") {
                context("with new object") {
                    it("saves new object") {
                        let networkCalls = APIRequest.callsCount

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

                        let remoteBeamObject = beamObjectHelper.fetchOnAPI(object.beamObjectId)
                        let remoteObject: MyRemoteObject? = try remoteBeamObject?.decodeBeamObject()

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

                        let remoteBeamObject = beamObjectHelper.fetchOnAPI(object.beamObjectId)
                        let remoteObject: MyRemoteObject? = try remoteBeamObject?.decodeBeamObject()

                        expect(remoteObject?.beamObjectId) == object.beamObjectId
                        expect(remoteObject?.title) == newTitle
                        expect(remoteObject?.checksum) == beamObject.dataChecksum
                    }

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

                        let remoteBeamObject = beamObjectHelper.fetchOnAPI(object.beamObjectId)
                        try remoteBeamObject?.decrypt()
                        let remoteObject: MyRemoteObject? = try remoteBeamObject?.decodeBeamObject()

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

                        let remoteBeamObject = beamObjectHelper.fetchOnAPI(object.beamObjectId)
                        try remoteBeamObject?.decrypt()
                        let remoteObject: MyRemoteObject? = try remoteBeamObject?.decodeBeamObject()

                        expect(remoteObject?.beamObjectId) == object.beamObjectId
                        expect(remoteObject?.title) == newTitle
                        expect(remoteObject?.checksum) == beamObject.dataChecksum
                    }
                }
            }
        }
    }
}
