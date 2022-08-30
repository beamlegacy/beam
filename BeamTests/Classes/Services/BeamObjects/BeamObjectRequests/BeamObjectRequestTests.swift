import Foundation
import XCTest
import Quick
import Nimble


@testable import Beam
@testable import BeamCore

class BeamObjectsRequests: QuickSpec {
    override func spec() {
        let beamHelper = BeamTestsHelper()
        let beamObjectHelper = BeamObjectTestsHelper()
        var sut: BeamObjectRequest!

        let objectManager = BeamData.shared.objectManager

        beforeEach {
            sut = BeamObjectRequest()
            Configuration.reset()
            Configuration.beamObjectsPageSize = 10

            BeamDate.freeze("2021-03-19T12:21:03Z")

            BeamTestsHelper.logout()

            beamHelper.beginNetworkRecording()

            BeamTestsHelper.login()
            MyRemoteObjectManager(objectManager: objectManager).registerOnBeamObjectManager(objectManager)
        }

        asyncAfterEach { _ in
            await beamObjectHelper.deleteAll(beamObjectType: .myRemoteObject)
            MyRemoteObjectManager.store.removeAll()

            Configuration.reset()
            beamHelper.endNetworkRecording()
            BeamDate.reset()
        }

        afterSuite {
            objectManager.unregister(objectType: .myRemoteObject)
        }

        context("with async") {
            context("delete all objects") {
                var object: MyRemoteObject!
                let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd58".uuid ?? UUID()
                let title = "my title"

                asyncBeforeEach { _ in
                    object = MyRemoteObject(beamObjectId: uuid,
                                                createdAt: BeamDate.now,
                                                updatedAt: BeamDate.now,
                                                deletedAt: nil,
                                                title: title)

                    _ = await beamObjectHelper.saveOnAPI(object)
                }

                asyncIt("sends a REST request") {
                    do {
                        let result = try await sut.deleteAllWithRest()
                        expect(result).to(beTrue())
                    } catch {
                        fail(error.localizedDescription)
                    }
                }
            }

            context("fetch fields") {
                let title = "my title"

                context("with many ids") {
                    var objects: [MyRemoteObject] = []
                    asyncBeforeEach { _ in
                        for index in 1...100 {
                            let uuid = "995d94e1-e0df-4eca-93e6-8778984b\(String(format: "%04d", index))".uuid ?? UUID()
                            let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                               createdAt: BeamDate.now,
                                                               updatedAt: BeamDate.now,
                                                               deletedAt: nil,
                                                               title: title)

                            objects.append(anotherObject)
                        }

                        _ = await beamObjectHelper.saveOnAPI(objects)
                    }

                    asyncIt("sends a REST request") {
                        do {
                            let beamObjects = try await sut.fetchAllWithRest(ids: objects.map { $0.beamObjectId })
                            let ids: [String] = beamObjects.compactMap { beamObject in
                                beamObject.id.uuidString.lowercased()
                            }.sorted()

                            expect(ids).to(equal(objects.map { $0.beamObjectId.uuidString.lowercased() }.sorted()))
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }
            }

            context("fetch fields (paginated query)") {
                let title = "my title"

                context("with many ids") {
                    var objects: [MyRemoteObject] = []
                    asyncBeforeEach { _ in
                        for index in 1...100 {
                            let uuid = "995d94e1-e0df-4eca-93e6-8778984b\(String(format: "%04d", index))".uuid ?? UUID()
                            let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                               createdAt: BeamDate.now,
                                                               updatedAt: BeamDate.now,
                                                               deletedAt: nil,
                                                               title: title)

                            objects.append(anotherObject)
                        }

                        _ = await beamObjectHelper.saveOnAPI(objects)
                    }

                    asyncIt("sends a graphql request") {
                        do {
                            let beamObjects = try await sut.fetchAllWithGraphQL(ids: objects.map { $0.beamObjectId })
                            let ids: [String] = beamObjects.compactMap { beamObject in
                                beamObject.id.uuidString.lowercased()
                            }.sorted()

                            expect(ids).to(equal(objects.map { $0.beamObjectId.uuidString.lowercased() }.sorted()))
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }
            }

            context("checksums") {
                var object: MyRemoteObject!
                let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd58".uuid ?? UUID()
                let title = "my title"

                asyncBeforeEach { _ in
                    object = MyRemoteObject(beamObjectId: uuid,
                                                createdAt: BeamDate.now,
                                                updatedAt: BeamDate.now,
                                                deletedAt: nil,
                                                title: title)

                    _ = await beamObjectHelper.saveOnAPI(object)
                }

                context("without params") {
                    asyncIt("sends a REST request") {
                        do {
                            let beamObjects = try await sut.fetchAllChecksumsWithRest()
                            let checksum = (try? object.checksum())
                            let checksums: [String?] = beamObjects.map { beamObject in
                                beamObject.dataChecksum
                            }

                            expect(checksums).to(contain(checksum))
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }

                context("with ids") {
                    asyncBeforeEach { _ in
                        let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd59".uuid ?? UUID()
                        let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                           createdAt: BeamDate.now,
                                                           updatedAt: BeamDate.now,
                                                           deletedAt: nil,
                                                           title: title)

                        _ = await beamObjectHelper.saveOnAPI(anotherObject)
                    }

                    asyncIt("sends a REST request") {
                        do {
                            let beamObjects = try await sut.fetchAllChecksumsWithRest(ids: [object.beamObjectId])
                            let checksum = (try? object.checksum())
                            let checksums: [String?] = beamObjects.map { beamObject in
                                beamObject.dataChecksum
                            }
                            expect(checksums).to(contain(checksum))
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }

                context("with many ids") {
                    var objects: [MyRemoteObject] = []
                    asyncBeforeEach { _ in
                        for index in 1...100 {
                            let uuid = "995d94e1-e0df-4eca-93e6-8778984b\(String(format: "%04d", index))".uuid ?? UUID()
                            let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                               createdAt: BeamDate.now,
                                                               updatedAt: BeamDate.now,
                                                               deletedAt: nil,
                                                               title: title)

                            objects.append(anotherObject)
                        }

                        _ = await beamObjectHelper.saveOnAPI(objects)
                    }

                    asyncIt("sends a REST request") {
                        do {
                            let beamObjects = try await sut.fetchAllChecksumsWithRest(ids: objects.map { $0.beamObjectId })
                            let checksums: [String] = beamObjects.compactMap { beamObject in
                                beamObject.dataChecksum
                            }.sorted()

                            expect(checksums).to(equal(objects.compactMap { try? $0.checksum() }))
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }

                context("with type") {
                    asyncBeforeEach { _ in
                        let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd59".uuid ?? UUID()
                        let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                           createdAt: BeamDate.now,
                                                           updatedAt: BeamDate.now,
                                                           deletedAt: nil,
                                                           title: title)

                        _ = await beamObjectHelper.saveOnAPI(anotherObject)
                    }

                    asyncIt("sends a REST request") {
                        do {
                            let beamObjects = try await sut.fetchAllChecksumsWithRest(beamObjectType: "my_remote_object")
                            let checksum = (try? object.checksum())
                            let checksums: [String?] = beamObjects.map { beamObject in
                                beamObject.dataChecksum
                            }

                            expect(checksums).to(contain(checksum))
                            expect(beamObjects).to(haveCount(2))
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }
            }

            context("checksums (paginated query)") {
                var object: MyRemoteObject!
                let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd58".uuid ?? UUID()
                let title = "my title"

                asyncBeforeEach { _ in
                    object = MyRemoteObject(beamObjectId: uuid,
                                                createdAt: BeamDate.now,
                                                updatedAt: BeamDate.now,
                                                deletedAt: nil,
                                                title: title)

                    _ = await beamObjectHelper.saveOnAPI(object)
                }

                context("without params") {
                    asyncIt("sends a graphql request") {
                        do {
                            let beamObjects = try await sut.fetchAllChecksumsWithGraphQL()
                            let checksum = (try? object.checksum())
                            let checksums: [String?] = beamObjects.map { beamObject in
                                beamObject.dataChecksum
                            }

                            expect(checksums).to(contain(checksum))
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }

                context("with ids") {
                    asyncBeforeEach { _ in
                        let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd59".uuid ?? UUID()
                        let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                           createdAt: BeamDate.now,
                                                           updatedAt: BeamDate.now,
                                                           deletedAt: nil,
                                                           title: title)

                        _ = await beamObjectHelper.saveOnAPI(anotherObject)
                    }

                    asyncIt("sends a graphql request") {
                        do {
                            let beamObjects = try await sut.fetchAllChecksumsWithGraphQL(ids: [object.beamObjectId])
                            let checksum = (try? object.checksum())
                            let checksums: [String?] = beamObjects.map { beamObject in
                                beamObject.dataChecksum
                            }

                            expect(checksums).to(contain(checksum))
                            expect(beamObjects).to(haveCount(1))
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }

                context("with many ids") {
                    var objects: [MyRemoteObject] = []
                    asyncBeforeEach { _ in
                        for index in 1...100 {
                            let uuid = "995d94e1-e0df-4eca-93e6-8778984b\(String(format: "%04d", index))".uuid ?? UUID()
                            let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                               createdAt: BeamDate.now,
                                                               updatedAt: BeamDate.now,
                                                               deletedAt: nil,
                                                               title: title)

                            objects.append(anotherObject)
                        }

                        _ = await beamObjectHelper.saveOnAPI(objects)
                    }

                    asyncIt("sends a graphql request") {
                        do {
                            let beamObjects = try await sut.fetchAllChecksumsWithGraphQL(ids: objects.map { $0.beamObjectId })
                            let checksums: [String] = beamObjects.compactMap { beamObject in
                                beamObject.dataChecksum
                            }.sorted()

                            expect(checksums).to(equal(objects.compactMap { try? $0.checksum() }))
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }

                context("with type") {
                    asyncBeforeEach { _ in
                        let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd59".uuid ?? UUID()
                        let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                           createdAt: BeamDate.now,
                                                           updatedAt: BeamDate.now,
                                                           deletedAt: nil,
                                                           title: title)

                        _ = await beamObjectHelper.saveOnAPI(anotherObject)
                    }

                    asyncIt("sends a graphql request") {
                        do {
                            let beamObjects = try await sut.fetchAllChecksumsWithGraphQL(beamObjectType: "my_remote_object")
                            let checksum = (try? object.checksum())
                            let checksums: [String?] = beamObjects.map { beamObject in
                                beamObject.dataChecksum
                            }

                            expect(checksums).to(contain(checksum))
                            expect(beamObjects).to(haveCount(2))
                        } catch {
                            fail(error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
}


class BeamObjectsRequestsTestNetworkError: QuickSpec {
    override func spec() {
        let beamHelper = BeamTestsHelper()
        var sut: BeamObjectRequest!

        beforeEach {
            sut = BeamObjectRequest()
            Beam.Configuration.reset()
            beamHelper.disableNetworkRecording()
            BeamURLSession.shouldNotBeVinyled = true
        }

        afterEach {
            BeamURLSession.shouldNotBeVinyled = false
        }

        context("with async") {
            context("with paginated query and not authenticated") {
                asyncIt("returns an error") {
                    do {
                        let _ = try await sut.fetchAllWithGraphQL(ids: [UUID()])
                        fail()
                    } catch {
                        expect(error).to(matchError(APIRequestError.notAuthenticated))
                    }
                }
            }
        }
    }
}
