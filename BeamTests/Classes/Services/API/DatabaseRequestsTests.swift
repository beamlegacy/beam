import Foundation
import XCTest
import Quick
import Nimble
import PromiseKit
import Promises

@testable import Beam
class DatabaseRequestTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        // MARK: Properties
        var coreDataManager: CoreDataManager!
        var sut: DatabaseRequest!
        let beamHelper = BeamTestsHelper()

        beforeSuite {
            coreDataManager = CoreDataManager()
            // Setup CoreData
            coreDataManager.setup()
            CoreDataManager.shared = coreDataManager
            sut = DatabaseRequest()
        }

        beforeEach {
            beamHelper.beginNetworkRecording()
            /*
             I enforce logout, to make sure we login after and log that call to network stubs.

             If we don't logout:
             when running the full suite of tests, login was already called before and the network
             call isn't happening again
             then when running only this test, it fails because the login API call wasn't recorded
             and it doesn't match the cassette
             */
            BeamTestsHelper.logout()
            BeamTestsHelper.login()
        }

        afterEach {
            beamHelper.endNetworkRecording()
        }

        describe(".save()") {
            let databaseApiStruct = self.buildDatabase(id: "c2460fd4-79b7-4271-946e-e973b513d649", title: "Practical Wooden Chair 8Kif0oSgWv1lR8GAneWq9zIOK5LCIW3Occ3v7zbh")
            afterEach { self.delete(databaseApiStruct) }

            context("with Foundation") {
                it("creates database") {
                    waitUntil(timeout: .seconds(10)) { done in
                        do {
                            _ = try sut.save(databaseApiStruct) { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get().database?.id }.to(equal(databaseApiStruct.id))
                                expect { try result.get().database?.title }.to(equal(databaseApiStruct.title))

                                done()
                            }
                        } catch {
                            fail(error.localizedDescription)
                            done()
                        }
                    }
                }
            }

            context("with PromiseKit") {
                it("creates database") {
                    let promise: PromiseKit.Promise<DatabaseAPIType> = sut.save(databaseApiStruct)
                    
                    waitUntil(timeout: .seconds(10)) { done in
                        promise.done { result in
                            expect(result.id) == databaseApiStruct.id
                            expect(result.title) == databaseApiStruct.title
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }
                }
            }

            context("with Promises") {
                it("creates database") {
                    let promise: Promises.Promise<DatabaseAPIType> = sut.save(databaseApiStruct)

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.then { result in
                            expect(result.id) == databaseApiStruct.id
                            expect(result.title) == databaseApiStruct.title
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }
                }
            }
        }

        describe(".delete()") {
            let databaseApiStruct = self.buildDatabase(id: "c2460fd4-79b7-4271-946e-e973b513d649", title: "Practical Wooden Chair 8Kif0oSgWv1lR8GAneWq9zIOK5LCIW3Occ3v7zbh")
            beforeEach { self.save(databaseApiStruct) }

            context("with Foundation") {
                it("deletes database") {
                    waitUntil(timeout: .seconds(10)) { done in
                        do {
                            _ = try sut.delete(databaseApiStruct.id!) { result in
                                expect { try result.get() }.toNot(throwError())
                                expect { try result.get().database?.id }.to(equal(databaseApiStruct.id))

                                done()
                            }
                        } catch {
                            fail(error.localizedDescription)
                            done()
                        }
                    }
                }
            }

            context("with PromisesKit") {
                it("deletes database") {
                    let promise: PromiseKit.Promise<DatabaseAPIType?> = sut.delete(databaseApiStruct.id!)

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.done { result in
                            expect(result?.id) == databaseApiStruct.id
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }
                }
            }

            context("with Promises") {
                it("deletes database") {
                    let promise: Promises.Promise<DatabaseAPIType?> = sut.delete(databaseApiStruct.id!)

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.then { result in
                            expect(result?.id) == databaseApiStruct.id
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }
                }
            }
        }

        describe(".fetchAll()") {
            let databaseApiStruct = self.buildDatabase(id: "c2460fd4-79b7-4271-946e-e973b513d649", title: "Practical Wooden Chair 8Kif0oSgWv1lR8GAneWq9zIOK5LCIW3Occ3v7zbh")
            beforeEach { self.save(databaseApiStruct) }
            afterEach { self.delete(databaseApiStruct) }

            context("with Foundation") {
                it("fetches all databases") {
                    waitUntil(timeout: .seconds(10)) { done in
                        do {
                            _ = try sut.fetchAll() { result in
                                let databases = try! result.get()
                                expect(databases.contains(databaseApiStruct)) == true

                                done()
                            }
                        } catch {
                            fail(error.localizedDescription)
                            done()
                        }
                    }
                }
            }

            context("with PromiseKit") {
                it("fetches all databases") {
                    let promise: PromiseKit.Promise<[DatabaseAPIType]> = sut.fetchAll()

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.done { result in
                            expect(result.contains(databaseApiStruct)) == true
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }
                }
            }

            context("with Promises") {
                it("fetches all databases") {
                    let promise: Promises.Promise<[DatabaseAPIType]> = sut.fetchAll()

                    waitUntil(timeout: .seconds(10)) { done in
                        promise.then { result in
                            expect(result.contains(databaseApiStruct)) == true
                            done()
                        }.catch { fail("Should not be called: \($0)"); done() }
                    }
                }
            }
        }
    }

    private func buildDatabase(id: String? = nil, title: String? = nil) -> DatabaseAPIType {
        let databaseApiStruct = DatabaseAPIType(id: id ?? UUID().uuidString.lowercased())
        databaseApiStruct.title = title ?? String.randomTitle()
        return databaseApiStruct
    }

    private func save(_ databaseApiStruct: DatabaseAPIType) {
        waitUntil(timeout: .seconds(10)) { done in
            do {
                _ = try DatabaseRequest().save(databaseApiStruct) { result in
                    expect { try result.get() }.toNot(throwError())
                    expect { try result.get().database?.id }.to(equal(databaseApiStruct.id))
                    expect { try result.get().database?.title }.to(equal(databaseApiStruct.title))

                    done()
                }
            } catch {
                fail(error.localizedDescription)
                done()
            }
        }
    }

    private func delete(_ databaseApiStruct: DatabaseAPIType) {
        waitUntil(timeout: .seconds(10)) { done in
            do {
                _ = try DatabaseRequest().delete(databaseApiStruct.id!) { result in
                    expect { try result.get() }.toNot(throwError())
                    expect { try result.get().database?.id }.to(equal(databaseApiStruct.id))

                    done()
                }
            } catch {
                fail(error.localizedDescription)
                done()
            }
        }
    }
}
