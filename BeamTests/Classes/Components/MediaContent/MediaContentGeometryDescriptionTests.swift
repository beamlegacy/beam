import XCTest
@testable import Beam

class MediaContentGeometryDescriptionTests: XCTestCase {

    func testNotHorizontallyResizable() {
        var description = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: true
        )

        description.setPreferredWidth(566)

        XCTAssertEqual(description.idealWidth, 400)
    }

    func testResizeHorizontally() {
        var description = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )

        description.setPreferredWidth(600)

        XCTAssertEqual(description.idealWidth, 600)
    }

    func testPreserveRatio() {
        var description = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )

        description.setPreferredWidth(600)

        XCTAssertEqual(description.idealHeight, 300)
    }

    func testResizeVertically() {
        var description = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .both
        )

        description.setPreferredHeight(500)

        XCTAssertEqual(description.idealWidth, 400)
        XCTAssertEqual(description.idealHeight, 500)
    }

    func testOverrideHeight() {
        var description = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false
        )

        description.setIdealHeight(500)

        XCTAssertEqual(description.idealHeight, 500)
    }

    func testDoNotResizeVerticallyIfNotVerticallyResizable() {
        var description = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )

        description.setPreferredHeight(500)

        XCTAssertEqual(description.idealHeight, 200)
    }

    func testDoNotOverrideHeightIfAspectRatioPreserved() {
        var description = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: true,
            resizableAxes: .both
        )

        description.setIdealHeight(500)

        XCTAssertEqual(description.idealHeight, 200)
    }

}
