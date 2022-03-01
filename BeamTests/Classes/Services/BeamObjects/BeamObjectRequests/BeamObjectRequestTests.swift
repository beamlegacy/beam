import Foundation
import XCTest
import Quick
import Nimble
import Promises
import PromiseKit

@testable import Beam
@testable import BeamCore

class BeamObjectsRequests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        let beamHelper = BeamTestsHelper()
        let beamObjectHelper = BeamObjectTestsHelper()
        var sut: BeamObjectRequest!

        beforeEach {
            sut = BeamObjectRequest()
            Beam.Configuration.reset()
            Beam.Configuration.apiHostname = "http://api.beam.lvh.me"

            BeamDate.freeze("2021-03-19T12:21:03Z")

            BeamTestsHelper.logout()

            beamHelper.beginNetworkRecording()

            BeamTestsHelper.login()
            MyRemoteObjectManager().registerOnBeamObjectManager()
        }

        afterEach {
            Configuration.reset()
            beamHelper.endNetworkRecording()
            Beam.Configuration.reset()
        }

        context("with Foundation") {
            context("checksums") {
                var object: MyRemoteObject!
                let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd58".uuid ?? UUID()
                let title = "my title"

                beforeEach {
                    object = MyRemoteObject(beamObjectId: uuid,
                                                createdAt: BeamDate.now,
                                                updatedAt: BeamDate.now,
                                                deletedAt: nil,
                                                title: title)

                    _ = beamObjectHelper.saveOnAPI(object)
                }

                context("without params") {
                    it("sends a REST request") {
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.fetchAllChecksumsWithRest() { result in
                                    switch result {
                                    case .failure(let error):
                                        fail(error.localizedDescription)
                                    case .success(let beamObjects):
                                        let checksum = (try? object.checksum())
                                        let checksums: [String?] = beamObjects.map { beamObject in
                                            beamObject.dataChecksum
                                        }

                                        expect(checksums).to(contain(checksum))
                                    }
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                                done()
                            }
                        }
                    }
                }

                context("with ids") {
                    beforeEach {
                        let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd59".uuid ?? UUID()
                        let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                           createdAt: BeamDate.now,
                                                           updatedAt: BeamDate.now,
                                                           deletedAt: nil,
                                                           title: title)

                        _ = beamObjectHelper.saveOnAPI(anotherObject)
                    }

                    it("sends a REST request") {
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.fetchAllChecksumsWithRest(ids: [object.beamObjectId]) { result in
                                    switch result {
                                    case .failure(let error):
                                        fail(error.localizedDescription)
                                    case .success(let beamObjects):
                                        let checksum = (try? object.checksum())
                                        let checksums: [String?] = beamObjects.map { beamObject in
                                            beamObject.dataChecksum
                                        }

                                        expect(checksums).to(contain(checksum))
                                        expect(beamObjects).to(haveCount(1))
                                    }
                                    done()
                                }
                            } catch {
                                fail(error.localizedDescription)
                                done()
                            }
                        }
                    }
                }

                context("with type") {
                    beforeEach {
                        let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd59".uuid ?? UUID()
                        let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                           createdAt: BeamDate.now,
                                                           updatedAt: BeamDate.now,
                                                           deletedAt: nil,
                                                           title: title)

                        _ = beamObjectHelper.saveOnAPI(anotherObject)
                    }

                    it("sends a REST request") {
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.fetchAllChecksumsWithRest(beamObjectType: "my_remote_object") { result in
                                    switch result {
                                    case .failure(let error):
                                        fail(error.localizedDescription)
                                    case .success(let beamObjects):
                                        let checksum = (try? object.checksum())
                                        let checksums: [String?] = beamObjects.map { beamObject in
                                            beamObject.dataChecksum
                                        }

                                        expect(checksums).to(contain(checksum))
                                        expect(beamObjects).to(haveCount(2))
                                    }
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
    }
}
