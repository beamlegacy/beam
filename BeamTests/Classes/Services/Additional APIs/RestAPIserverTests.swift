//
//  RestAPIserverTests.swift
//  BeamTests
//
//  Created by Jérôme Blondon on 27/05/2022.
//

import Foundation

import XCTest
import BeamCore
import Quick
import Nimble

@testable import Beam

class RestAPIserverTests: QuickSpec {
    override func spec() {

        afterEach() {
            Configuration.reset()
        }

        describe("baseURL") {
            describe("with embed") {
                let request = RestAPIServer.Request.embed(url: URL.init(string: "foo")!)

                describe("with default configuration") {
                    it("Returns the env url") {
                        Configuration.reset()
                        XCTAssertEqual(request.baseURL, URL.init(string: EnvironmentVariables.PublicAPI.embed))
                    }
                }

                describe("with custom URL") {
                    it("Returns the custom url") {
                        Configuration.publicAPIembed = "https://custom"
                        XCTAssertEqual(request.baseURL, URL.init(string: "https://custom"))
                    }
                }
            }

            describe("with providers") {
                let request = RestAPIServer.Request.providers

                describe("with default configuration") {
                    it("Returns the env url") {
                        Configuration.reset()
                        XCTAssertEqual(request.baseURL, URL.init(string: EnvironmentVariables.PublicAPI.embed))
                    }
                }

                describe("with custom URL") {
                    it("Returns the custom url") {
                        Configuration.publicAPIembed = "https://custom"
                        XCTAssertEqual(request.baseURL, URL.init(string: "https://custom"))
                    }
                }
            }

            describe("with publishNote") {
                guard let note = try? BeamNote(title: "foo") else {
                    fail("Error while creating note")
                    return
                }
                let request = RestAPIServer.Request.publishNote(note: note, tabGroups: nil, publicationGroups: [], fileManager: BeamData.shared.fileDBManager!)

                describe("with default configuration") {
                    it("Returns the env url") {
                        Configuration.reset()
                        XCTAssertEqual(request.baseURL, URL.init(string: EnvironmentVariables.PublicAPI.publishServer))
                    }
                }

                describe("with custom URL") {
                    it("Returns the custom url") {
                        Configuration.publicAPIpublishServer = "https://custom"
                        XCTAssertEqual(request.baseURL, URL.init(string: "https://custom"))
                    }
                }
            }

            describe("with unpublishNote") {
                let request = RestAPIServer.Request.unpublishNote(noteId: UUID())

                describe("with default configuration") {
                    it("Returns the env url") {
                        Configuration.reset()
                        XCTAssertEqual(request.baseURL, URL.init(string: EnvironmentVariables.PublicAPI.publishServer))
                    }
                }

                describe("with custom URL") {
                    it("Returns the custom url") {
                        Configuration.publicAPIpublishServer = "https://custom"
                        XCTAssertEqual(request.baseURL, URL.init(string: "https://custom"))
                    }
                }
            }

            describe("with updatePublicationGroup") {
                guard let note = try? BeamNote(title: "foo") else {
                    fail("Error while creating note")
                    return
                }
                let request = RestAPIServer.Request.updatePublicationGroup(note: note, tabGroups: nil, publicationGroups: [], fileManager: BeamData.shared.fileDBManager!)

                describe("with default configuration") {
                    it("Returns the env url") {
                        Configuration.reset()
                        XCTAssertEqual(request.baseURL, URL.init(string: EnvironmentVariables.PublicAPI.publishServer))
                    }
                }

                describe("with custom URL") {
                    it("Returns the custom url") {
                        Configuration.publicAPIpublishServer = "https://custom"
                        XCTAssertEqual(request.baseURL, URL.init(string: "https://custom"))
                    }
                }
            }
        }
    }
}
