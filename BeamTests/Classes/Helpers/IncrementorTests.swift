import XCTest
@testable import Beam

class IncrementorTests: XCTestCase {

    private var incrementor: Incrementor<CGFloat>!

    override func setUp() {
        incrementor = Incrementor(
            defaultValue: 1,
            increments: [0.1, 0.4, 0.5, 1, 1.5, 2]
        )
    }

    func testIncreaseFromIncrement() {
        incrementor.value = 1

        incrementor.increase()

        XCTAssertEqual(incrementor.value, 1.5)
    }

    func testIncreaseFromCustomValue() {
        incrementor.value = 1.2

        incrementor.increase()

        XCTAssertEqual(incrementor.value, 1.5)
    }

    func testDecreaseFromIncrement() {
        incrementor.value = 0.5

        incrementor.decrease()

        XCTAssertEqual(incrementor.value, 0.4)
    }

    func testDecreaseFromCustomValue() {
        incrementor.value = 0.44

        incrementor.decrease()

        XCTAssertEqual(incrementor.value, 0.4)
    }

    func testReset() {
        incrementor.value = 1.34

        incrementor.reset()

        XCTAssertEqual(incrementor.value, 1)
    }

    func testSmallest() {
        incrementor.value = 0.1

        XCTAssertTrue(incrementor.isSmallestIncrement)
    }

    func testHighest() {
        incrementor.value = 2

        XCTAssertTrue(incrementor.isHighestIncrement)
    }

}
