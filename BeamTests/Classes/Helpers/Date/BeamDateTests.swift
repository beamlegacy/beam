import Foundation
import XCTest
import Nimble

@testable import Beam

class BeamDateTests: XCTestCase {
    override func tearDown() {
        BeamDate.reset()
    }

    func testNowUpdates() {
        expect(BeamDate.currentDate).to(beNil())
        let now1 = BeamDate.now
        expect(BeamDate.currentDate).to(beNil())

        let now2 = BeamDate.now
        expect(BeamDate.currentDate).to(beNil())

        expect(now1).to(beCloseTo(now2, within: 0.1))
        expect(now1).toNot(equal(now2))
    }

    func testTravelForward() {
        let now1 = BeamDate.now
        expect(BeamDate.currentDate).to(beNil())
        BeamDate.travel(3600)
        expect(BeamDate.currentDate).toNot(beNil())
        let now2 = BeamDate.now

        expect(now2).to(beGreaterThan(now1))
        expect(now2.timeIntervalSince(now1)).to(beGreaterThan(3600))
    }

    func testTravelBackward() {
        let now1 = BeamDate.now
        expect(BeamDate.currentDate).to(beNil())
        BeamDate.travel(-3600)
        expect(BeamDate.currentDate).toNot(beNil())
        let now2 = BeamDate.now

        expect(now2).to(beLessThan(now1))
        expect(now2.timeIntervalSince(now1)).to(beLessThan(3600))
    }

    func testFreeze() {
        BeamDate.freeze()
        let now1 = BeamDate.now
        usleep(2000)
        let now2 = BeamDate.now

        expect(BeamDate.currentDate).toNot(beNil())
        expect(now2).to(equal(now1))

        BeamDate.reset()
        expect(BeamDate.currentDate).to(beNil())
    }
}
