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
                let note = BeamNote(title: "foo")
                let request = RestAPIServer.Request.publishNote(note: note, publicationGroups: [])

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
                let note = BeamNote(title: "foo")
                let request = RestAPIServer.Request.updatePublicationGroup(note: note, publicationGroups: [])

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
