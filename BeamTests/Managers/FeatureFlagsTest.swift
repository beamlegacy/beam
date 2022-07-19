//
//  FeatureFlags.swift
//  BeamTests
//
//  Created by Adrian Tofan on 13/07/2022.
//
import Foundation
import XCTest
import Quick
import Nimble


@testable import Beam
@testable import BeamCore
import Network

class FeatureFlagsTest: QuickSpec {
    override func spec() {

        describe("FeatureFlags") {
            beforeSuite {
                Configuration.reset()
            }
            it("has correct default values") {
                expect(FeatureFlags.current.syncEnabled).to(beTrue())
            }
            describe("test infastructure") {
                var oldSyncEnabled: Bool = false
                beforeEach {
                    oldSyncEnabled = FeatureFlags.current.syncEnabled
                    expect(oldSyncEnabled).to(beTrue())
                }
                afterEach {
                    FeatureFlags.testSetSyncEnabled(oldSyncEnabled)
                }
                it("can be overriden for testing pourposes") {
                    FeatureFlags.testSetSyncEnabled(false)
                    expect(FeatureFlags.current.syncEnabled).to(beFalse())
                }
            }
        }

        describe("FeatureFlagsService") {
            // Even if a bit indirect, goal is to make sure that by default the service would call this URL. Complete testing would require mocking/testing NSURLSession.
            it("has correct default update url") {
                // Don't want to change settings or wiring by mistake for this one
                expect(FeatureFlagsService.updateURL.absoluteString).to(equal("https://s3.eu-west-3.amazonaws.com/downloads.beamapp.co/flags/api.prod.beamapp.co.json"))
                expect(FeatureFlagsService.shared.updateURL).to(equal(FeatureFlagsService.updateURL))
            }

            // In the context of a test, for this amount of time, the test would timeout
            let fireOnceRefreshTimeInterval:TimeInterval = 100.0

            context("with active networking") {
                let beamHelper = BeamTestsHelper()

                afterEach {
                    beamHelper.endNetworkRecording()
                }

                beforeEach {
                    beamHelper.beginNetworkRecording()
                }

                it("updates remotely with testURL url") {
                    // Content should be updated to be diffrerent from defaults when FeatureFlagsValues change
                    // in order to be able to match updates.
                    let testURL = URL(string: "https://s3.eu-west-3.amazonaws.com/downloads.beamapp.co/flags/api.test.beamapp.co.json")!
                    let service = FeatureFlagsService(updateURL: testURL)
                    expect(service.values.syncEnabled).to(beTrue())
                    waitUntil(timeout: .seconds(10)) { done in
                        service.didRefresh = { result in
                            guard case .success(_) = result  else {
                                fail("Failed to update \(result)")
                                return
                            }
                            done()
                        }
                        service.startUpdate(refreshInterval: fireOnceRefreshTimeInterval)
                    }
                    expect(service.values.syncEnabled).to(beFalse())
                }

                it("does not change data on invalid json") {
                    let service = FeatureFlagsService(updateURL: URL(string: "https://s3.eu-west-3.amazonaws.com/downloads.beamapp.co/flags/api.test.beamapp.co.invalid.json")!)
                    expect(service.values.syncEnabled).to(beTrue())
                    waitUntil(timeout: .seconds(10)) { done in
                        service.didRefresh = { result in
                            guard case .failure(.invalidOutput(_)) = result else {
                                fail("Should have failed to decode \(result)")
                                return
                            }
                            done()
                        }
                        service.startUpdate(refreshInterval: fireOnceRefreshTimeInterval)
                    }
                    expect(service.values.syncEnabled).to(beTrue())
                }
            }

            // Vinyl does not like some of the calls such as connection errors
            context("with active networing but without vinyl") {
                it("do not change data on invalid response") {
                    let service = FeatureFlagsService(updateURL: URL(string: "https://s3.eu-west-3.amazonaws.com/downloads.beamapp.co/flags/api.test.beamapp.co.missing.json")!)
                    expect(service.values.syncEnabled).to(beTrue())
                    waitUntil(timeout: .seconds(10)) { done in
                        service.didRefresh = { result in
                            guard case .failure(.serverError) = result else {
                                fail("Should have failed to load inexistent resource\(result)")
                                return
                            }
                            done()
                        }
                        service.startUpdate(refreshInterval: fireOnceRefreshTimeInterval)
                    }
                    expect(service.values.syncEnabled).to(beTrue())
                }
                it("do not change data on network errors") {
                    // Assumes localhost does not have anything listening
                    let service = FeatureFlagsService(updateURL: URL(string: "https://doesnotexist")!)
                    expect(service.values.syncEnabled).to(beTrue())
                    waitUntil(timeout: .seconds(10)) { done in
                        service.didRefresh = { result in
                            guard case .failure(.networkError(_)) = result else {
                                fail("Should have failed to connect\(result)")
                                return
                            }
                            done()
                        }
                        service.startUpdate(refreshInterval: fireOnceRefreshTimeInterval)
                    }
                    expect(service.values.syncEnabled).to(beTrue())
                }
            }
        }
    }
}
