import XCTest
import BeamCore
@testable import Beam

class BeamElementDisplaySizePreferencesStorageTests: XCTestCase {

    func testUnset() {
        let element = BeamElement()
        let displayInfos = MediaDisplayInfos(height: nil, width: nil, displayRatio: nil)
        element.kind = .image(UUID(), origin: nil, displayInfos: displayInfos)

        XCTAssertNil(element.displaySizePreferences)
    }

    func testRestoreFromImageElement() {
        let element = BeamElement()
        let displayInfos = MediaDisplayInfos(height: 200, width: 400, displayRatio: 0.5)
        element.kind = .image(UUID(), origin: nil, displayInfos: displayInfos)

        XCTAssertEqual(
            element.displaySizePreferences,
            .contentSize(containerWidthRatio: 0.5, contentWidth: 400, contentHeight: 200)
        )
    }

    func testRestoreFromEmbedElement() {
        let element = BeamElement()
        let displayInfos = MediaDisplayInfos(height: nil, width: nil, displayRatio: 0.5)
        element.kind = .embed(URL(string: "beam")!, origin: nil, displayInfos: displayInfos)

        XCTAssertEqual(
            element.displaySizePreferences,
            .displayHeight(containerWidthRatio: 0.5, displayHeight: nil)
        )
    }

    func testRestoreFromEmbedElementWithSetHeight() {
        let element = BeamElement()
        let displayInfos = MediaDisplayInfos(height: 350, width: nil, displayRatio: 0.5)
        element.kind = .embed(URL(string: "beam")!, origin: nil, displayInfos: displayInfos)

        XCTAssertEqual(
            element.displaySizePreferences,
            .displayHeight(containerWidthRatio: 0.5, displayHeight: 350)
        )
    }

    func testSaveImageElement() {
        let element = BeamElement()
        let displayInfos = MediaDisplayInfos(height: nil, width: nil, displayRatio: nil)
        let uuid = UUID()
        element.kind = .image(uuid, origin: nil, displayInfos: displayInfos)

        element.displaySizePreferences = .contentSize(
            containerWidthRatio: 0.5,
            contentWidth: 400,
            contentHeight: 200
        )

        XCTAssertEqual(element.imageDisplayInfos?.uuid, uuid)
        XCTAssertEqual(element.imageDisplayInfos?.displayInfos, MediaDisplayInfos(height: 200, width: 400, displayRatio: 0.5))
    }

    func testSaveEmbedElement() {
        let element = BeamElement()
        let displayInfos = MediaDisplayInfos(height: nil, width: nil, displayRatio: nil)
        let url = URL(string: "beam")!
        element.kind = .embed(url, origin: nil, displayInfos: displayInfos)

        element.displaySizePreferences = .displayHeight(
            containerWidthRatio: 0.5, displayHeight: nil
        )

        XCTAssertEqual(element.embedDisplayInfos?.url, url)
        XCTAssertEqual(element.embedDisplayInfos?.displayInfos, MediaDisplayInfos(height: nil, width: nil, displayRatio: 0.5))
    }

    func testSaveEmbedElementWithSetHeight() {
        let element = BeamElement()
        let displayInfos = MediaDisplayInfos(height: nil, width: nil, displayRatio: nil)
        let url = URL(string: "beam")!
        element.kind = .embed(url, origin: nil, displayInfos: displayInfos)

        element.displaySizePreferences = .displayHeight(
            containerWidthRatio: 0.5, displayHeight: 350
        )

        XCTAssertEqual(element.embedDisplayInfos?.url, url)
        XCTAssertEqual(element.embedDisplayInfos?.displayInfos, MediaDisplayInfos(height: 350, width: nil, displayRatio: 0.5))
    }

}

// MARK: - Helpers

private extension BeamElement {

    var imageDisplayInfos: (uuid: UUID, origin: SourceMetadata?, displayInfos: MediaDisplayInfos)? {
        if case let .image(uuid, origin, displayInfos) = kind {
            return (uuid, origin, displayInfos)
        }
        return nil
    }

    var embedDisplayInfos: (url: URL, origin: SourceMetadata?, displayInfos: MediaDisplayInfos)? {
        if case let .embed(url, origin, displayInfos) = kind {
            return (url, origin, displayInfos)
        }
        return nil
    }

}
