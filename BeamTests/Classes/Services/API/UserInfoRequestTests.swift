//
//  UserInfoRequestTests.swift
//  BeamTests
//
//  Created by Remi Santos on 13/12/2021.
//

import XCTest
import Quick
import Nimble

@testable import Beam
@testable import BeamCore

class UserInfoRequestTests: QuickSpec {
    override func spec() {
        var sut: UserInfoRequest!

        beforeEach {
            sut = UserInfoRequest()
            BeamDate.freeze("2022-04-18T06:00:03Z")
        }

        afterEach {
            BeamDate.reset()
        }

        describe("remote user API disabled") {
            asyncIt("setUsername throws networkUnavailable") {
                do {
                    _ = try await sut.setUsername(username: "any")
                    fail("expected networkUnavailable")
                } catch {
                    expect(error).to(matchError(APIRequestError.networkUnavailable))
                }
            }
        }
    }
}
