import Foundation
import XCTest
import Quick
import Nimble
import Promises

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
            Configuration.beamObjectsPageSize = 10

            BeamDate.freeze("2021-03-19T12:21:03Z")

            BeamTestsHelper.logout()

            beamHelper.beginNetworkRecording()

            BeamTestsHelper.login()
            MyRemoteObjectManager().registerOnBeamObjectManager()
        }

        afterEach {
            beamObjectHelper.deleteAll(beamObjectType: .myRemoteObject)
            MyRemoteObjectManager.store.removeAll()

            Configuration.reset()
            beamHelper.endNetworkRecording()
            Beam.Configuration.reset()
            BeamDate.reset()
        }

        context("with Foundation") {
            context("delete all objects") {
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

                it("sends a REST request") {
                    waitUntil(timeout: .seconds(10)) { done in
                        do {
                            _ = try sut.deleteAllWithRest { result in
                                switch result {
                                case .failure(let error):
                                    fail(error.localizedDescription)
                                case .success(let success):
                                    expect(success).to(beTrue())
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

            context("fetch fields") {
                let title = "my title"

                context("with many ids") {
                    var objects: [MyRemoteObject] = []
                    beforeEach {
                        for index in 1...100 {
                            let uuid = "995d94e1-e0df-4eca-93e6-8778984b\(String(format: "%04d", index))".uuid ?? UUID()
                            let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                               createdAt: BeamDate.now,
                                                               updatedAt: BeamDate.now,
                                                               deletedAt: nil,
                                                               title: title)

                            objects.append(anotherObject)
                        }

                        _ = beamObjectHelper.saveOnAPI(objects)
                    }

                    it("sends a REST request") {
                        waitUntil(timeout: .seconds(20)) { done in
                            do {
                                _ = try sut.fetchAllWithRest(ids: objects.map { $0.beamObjectId }) { result in
                                    switch result {
                                    case .failure(let error):
                                        fail(error.localizedDescription)
                                    case .success(let beamObjects):
                                        let ids: [String] = beamObjects.compactMap { beamObject in
                                            beamObject.id.uuidString.lowercased()
                                        }.sorted()

                                        expect(ids).to(equal(objects.map { $0.beamObjectId.uuidString.lowercased() }.sorted()))
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

            context("fetch fields (paginated query)") {
                let title = "my title"

                context("with many ids") {
                    var objects: [MyRemoteObject] = []
                    beforeEach {
                        for index in 1...100 {
                            let uuid = "995d94e1-e0df-4eca-93e6-8778984b\(String(format: "%04d", index))".uuid ?? UUID()
                            let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                               createdAt: BeamDate.now,
                                                               updatedAt: BeamDate.now,
                                                               deletedAt: nil,
                                                               title: title)

                            objects.append(anotherObject)
                        }

                        _ = beamObjectHelper.saveOnAPI(objects)
                    }

                    it("sends a graphql request") {
                        waitUntil(timeout: .seconds(20)) { done in
                            do {
                                _ = try sut.fetchAllWithGraphQL(ids: objects.map { $0.beamObjectId }) { result in
                                    switch result {
                                    case .failure(let error):
                                        fail(error.localizedDescription)
                                    case .success(let beamObjects):
                                        let ids: [String] = beamObjects.compactMap { beamObject in
                                            beamObject.id.uuidString.lowercased()
                                        }.sorted()

                                        expect(ids).to(equal(objects.map { $0.beamObjectId.uuidString.lowercased() }.sorted()))
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

                context("with many ids") {
                    var objects: [MyRemoteObject] = []
                    beforeEach {
                        for index in 1...100 {
                            let uuid = "995d94e1-e0df-4eca-93e6-8778984b\(String(format: "%04d", index))".uuid ?? UUID()
                            let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                               createdAt: BeamDate.now,
                                                               updatedAt: BeamDate.now,
                                                               deletedAt: nil,
                                                               title: title)

                            objects.append(anotherObject)
                        }

                        _ = beamObjectHelper.saveOnAPI(objects)
                    }

                    it("sends a REST request") {
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.fetchAllChecksumsWithRest(ids: objects.map { $0.beamObjectId }) { result in
                                    switch result {
                                    case .failure(let error):
                                        fail(error.localizedDescription)
                                    case .success(let beamObjects):
                                        let checksums: [String] = beamObjects.compactMap { beamObject in
                                            beamObject.dataChecksum
                                        }.sorted()

                                        expect(checksums).to(equal(objects.compactMap { try? $0.checksum() }))
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

            context("checksums (paginated query)") {
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
                    it("sends a graphql request") {
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.fetchAllChecksumsWithGraphQL() { result in
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

                    it("sends a graphql request") {
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.fetchAllChecksumsWithGraphQL(ids: [object.beamObjectId]) { result in
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

                context("with many ids") {
                    var objects: [MyRemoteObject] = []
                    beforeEach {
                        for index in 1...100 {
                            let uuid = "995d94e1-e0df-4eca-93e6-8778984b\(String(format: "%04d", index))".uuid ?? UUID()
                            let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                               createdAt: BeamDate.now,
                                                               updatedAt: BeamDate.now,
                                                               deletedAt: nil,
                                                               title: title)

                            objects.append(anotherObject)
                        }

                        _ = beamObjectHelper.saveOnAPI(objects)
                    }

                    it("sends a graphql request") {
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.fetchAllChecksumsWithGraphQL(ids: objects.map { $0.beamObjectId }) { result in
                                    switch result {
                                    case .failure(let error):
                                        fail(error.localizedDescription)
                                    case .success(let beamObjects):
                                        let checksums: [String] = beamObjects.compactMap { beamObject in
                                            beamObject.dataChecksum
                                        }.sorted()

                                        expect(checksums).to(equal(objects.compactMap { try? $0.checksum() }))
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

                    it("sends a graphql request") {
                        waitUntil(timeout: .seconds(10)) { done in
                            do {
                                _ = try sut.fetchAllChecksumsWithGraphQL(beamObjectType: "my_remote_object") { result in
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

        context("with async") {
            context("delete all objects") {
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
                    beforeEach {
                        for index in 1...100 {
                            let uuid = "995d94e1-e0df-4eca-93e6-8778984b\(String(format: "%04d", index))".uuid ?? UUID()
                            let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                               createdAt: BeamDate.now,
                                                               updatedAt: BeamDate.now,
                                                               deletedAt: nil,
                                                               title: title)

                            objects.append(anotherObject)
                        }

                        _ = beamObjectHelper.saveOnAPI(objects)
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
                    beforeEach {
                        for index in 1...100 {
                            let uuid = "995d94e1-e0df-4eca-93e6-8778984b\(String(format: "%04d", index))".uuid ?? UUID()
                            let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                               createdAt: BeamDate.now,
                                                               updatedAt: BeamDate.now,
                                                               deletedAt: nil,
                                                               title: title)

                            objects.append(anotherObject)
                        }

                        _ = beamObjectHelper.saveOnAPI(objects)
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

                beforeEach {
                    object = MyRemoteObject(beamObjectId: uuid,
                                                createdAt: BeamDate.now,
                                                updatedAt: BeamDate.now,
                                                deletedAt: nil,
                                                title: title)

                    _ = beamObjectHelper.saveOnAPI(object)
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
                    beforeEach {
                        let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd59".uuid ?? UUID()
                        let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                           createdAt: BeamDate.now,
                                                           updatedAt: BeamDate.now,
                                                           deletedAt: nil,
                                                           title: title)

                        _ = beamObjectHelper.saveOnAPI(anotherObject)
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
                    beforeEach {
                        for index in 1...100 {
                            let uuid = "995d94e1-e0df-4eca-93e6-8778984b\(String(format: "%04d", index))".uuid ?? UUID()
                            let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                               createdAt: BeamDate.now,
                                                               updatedAt: BeamDate.now,
                                                               deletedAt: nil,
                                                               title: title)

                            objects.append(anotherObject)
                        }

                        _ = beamObjectHelper.saveOnAPI(objects)
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
                    beforeEach {
                        let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd59".uuid ?? UUID()
                        let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                           createdAt: BeamDate.now,
                                                           updatedAt: BeamDate.now,
                                                           deletedAt: nil,
                                                           title: title)

                        _ = beamObjectHelper.saveOnAPI(anotherObject)
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

                beforeEach {
                    object = MyRemoteObject(beamObjectId: uuid,
                                                createdAt: BeamDate.now,
                                                updatedAt: BeamDate.now,
                                                deletedAt: nil,
                                                title: title)

                    _ = beamObjectHelper.saveOnAPI(object)
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
                    beforeEach {
                        let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd59".uuid ?? UUID()
                        let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                           createdAt: BeamDate.now,
                                                           updatedAt: BeamDate.now,
                                                           deletedAt: nil,
                                                           title: title)

                        _ = beamObjectHelper.saveOnAPI(anotherObject)
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
                    beforeEach {
                        for index in 1...100 {
                            let uuid = "995d94e1-e0df-4eca-93e6-8778984b\(String(format: "%04d", index))".uuid ?? UUID()
                            let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                               createdAt: BeamDate.now,
                                                               updatedAt: BeamDate.now,
                                                               deletedAt: nil,
                                                               title: title)

                            objects.append(anotherObject)
                        }

                        _ = beamObjectHelper.saveOnAPI(objects)
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
                    beforeEach {
                        let uuid = "995d94e1-e0df-4eca-93e6-8778984bcd59".uuid ?? UUID()
                        let anotherObject = MyRemoteObject(beamObjectId: uuid,
                                                           createdAt: BeamDate.now,
                                                           updatedAt: BeamDate.now,
                                                           deletedAt: nil,
                                                           title: title)

                        _ = beamObjectHelper.saveOnAPI(anotherObject)
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
    // swiftlint:disable:next function_body_length
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

        context("with Foundation") {
            context("with paginated query and not authenticated") {
                it("returns an error") {
                    waitUntil(timeout: .seconds(10)) { done in
                        do {
                            _ = try sut.fetchAllWithGraphQL(ids: [UUID()]) { result in
                                switch result {
                                case .failure(let error):
                                    expect(error).to(matchError(APIRequestError.notAuthenticated))
                                case .success:
                                    fail()
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
