import XCTest
@testable import Beam

// MARK: - Initial state

class MediaContentGeometryInitialStateTests: XCTestCase {

    private var geometry: MediaContentGeometry!

    override func setUp() {
        geometry = MediaContentGeometry()
    }

    func testInitialSize() {
        // Default content dimensions are 170x128
        XCTAssertEqual(geometry.displaySize, CGSize(width: 170, height: 128))
    }

    func testContainerWidthUnknown() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)

        // Default container width is 300
        XCTAssertEqual(geometry.displaySize, CGSize(width: 300, height: 150))
    }

    func testContentIdealSizeUnknown() {
        let contentDescription = MediaContentGeometryDescription(
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)

        // Default container width is 300, default aspect ratio is 4/3
        XCTAssertEqual(geometry.displaySize, CGSize(width: 300, height: 225))
    }

    func testContentGeometryZeroWidth() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 0,
            idealHeight: 200,
            preservesAspectRatio: false
        )
        geometry.setGeometryDescription(contentDescription)

        // Minimum allowed dimensions are 48x48
        XCTAssertEqual(geometry.displaySize, CGSize(width: 48, height: 200))
    }

    func testContentGeometryZeroWidthAndHeight() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 0,
            idealHeight: 0,
            preservesAspectRatio: false
        )
        geometry.setGeometryDescription(contentDescription)

        // Minimum allowed dimensions are 48x48
        XCTAssertEqual(geometry.displaySize, CGSize(width: 48, height: 48))
    }

}

// MARK: - Content with free aspect ratio

class MediaContentGeometryFreeAspectRatioTests: XCTestCase {

    private var geometry: MediaContentGeometry!

    override func setUp() {
        geometry = MediaContentGeometry()
    }

    func testContentFitsInsideContainerWidth() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 400, height: 200))
    }

    func testContentLargerThanContainerWidth() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(300)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 300, height: 200))
    }

    func testContentSmallerThanMinWidth() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 10,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 48, height: 200))
    }

}

// MARK: - Landscape content with fixed height

class MediaContentGeometryFixedHeightLandscapeTests: XCTestCase {

    private var geometry: MediaContentGeometry!

    override func setUp() {
        geometry = MediaContentGeometry()
    }

    func testContentFitsInsideContainerWidth() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 400, height: 200))
    }

    func testContentLargerThanContainerWidth() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(300)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 300, height: 150))
    }

    func testContentSmallerThanMinWidth() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 10,
            idealHeight: 5,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 96, height: 48))
    }

}

// MARK: - Portrait content with fixed height

class MediaContentGeometryFixedHeightPortraitTests: XCTestCase {

    private var geometry: MediaContentGeometry!

    override func setUp() {
        geometry = MediaContentGeometry()
    }

    func testContentFitsInsideContainerWidth() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 200,
            idealHeight: 400,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 200, height: 400))
    }

    func testContentLargerThanContainerWidth() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 200,
            idealHeight: 400,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(100)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 100, height: 200))
    }

    func testContentSmallerThanMinWidth() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 5,
            idealHeight: 10,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 48, height: 96))
    }

}

// MARK: - Content with unknown height

class MediaContentGeometryUnknownHeightTests: XCTestCase {

    private var geometry: MediaContentGeometry!

    override func setUp() {
        geometry = MediaContentGeometry()
    }

    func testDefaultAspectRatio() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 400, height: 300))
    }

    func testContentLargerThanContainerWidth() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(300)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 300, height: 225))
    }

    func testContentSmallerThanMinWidth() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 10,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 64, height: 48))
    }

}

// MARK: - Horizontally resizable content with fixed height

class MediaContentGeometryFixedHeightResizeHorizontallyTests: XCTestCase {

    private var geometry: MediaContentGeometry!

    override func setUp() {
        geometry = MediaContentGeometry()
    }

    func testNotResizable() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(300)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 400, height: 200))
    }

    func testResize() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(300)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 300, height: 200))
    }

    func testShrinkContainerWidth() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(300)

        geometry.setContainerWidth(400)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 300, height: 200))
    }

    func testResizeBeyondContainerWidth() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(300)
        geometry.setPreferredDisplayWidth(600)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 300, height: 200))
    }

    func testResizeUnderContentMinWidth() {
        let contentDescription = MediaContentGeometryDescription(
            minWidth: 150,
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(100)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 150, height: 200))
    }

    func testResizeBeyondContentMaxWidth() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            maxWidth: 500,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(550)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 500, height: 200))
    }

}

// MARK: - Horizontally resizable content with aspect ratio preserved

class MediaContentGeometryPreserveAspectRatioResizeHorizontallyTests: XCTestCase {

    private var geometry: MediaContentGeometry!

    override func setUp() {
        geometry = MediaContentGeometry()
    }

    func testResize() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(300)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 300, height: 150))
    }

    func testResizeBeyondContainerWidth() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(300)
        geometry.setPreferredDisplayWidth(600)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 300, height: 150))
    }

    func testResizeUnderContentMinWidth() {
        let contentDescription = MediaContentGeometryDescription(
            minWidth: 150,
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(100)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 150, height: 75))
    }

    func testResizeBeyondContentMaxWidth() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            maxWidth: 500,
            idealHeight: 200,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(550)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 500, height: 250))
    }

}

// MARK: - Vertically resizable content

class MediaContentGeometryResizeVerticallyTests: XCTestCase {

    private var geometry: MediaContentGeometry!

    override func setUp() {
        geometry = MediaContentGeometry()
    }

    func testNotResizable() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayHeight(600)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 400, height: 200))
    }

    func testResize() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .both
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayHeight(600)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 400, height: 600))
    }

    func testDisregardSizeOverrideIfVerticallyResizable() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .both
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setDisplaySizeOverride(CGSize(width: 566, height: 399))

        XCTAssertEqual(geometry.displaySize, CGSize(width: 400, height: 200))
    }

    func testDisregardSizeOverrideIfAspectRatioPreserved() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: true,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setDisplaySizeOverride(CGSize(width: 566, height: 399))

        XCTAssertEqual(geometry.displaySize, CGSize(width: 400, height: 200))
    }

    func testResizeUnderContentMinHeight() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            minHeight: 100,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .both
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayHeight(50)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 400, height: 100))
    }

    func testResizeBeyondContentMaxHeight() {
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            maxHeight: 500,
            preservesAspectRatio: false,
            resizableAxes: .both
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayHeight(550)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 400, height: 500))
    }

}

// MARK: - Display size cache and size preferences persistence

class MediaContentGeometrySizePreferencesPersistence: XCTestCase {

    private var sizePreferencesStorage: DisplaySizePreferencesStorageFake!

    override func setUp() {
        sizePreferencesStorage = DisplaySizePreferencesStorageFake()
    }

    func testDontSaveOnSizeUpdates() {
        var geometry = MediaContentGeometry(
            sizePreferencesStorage: sizePreferencesStorage
        )
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(300)

        XCTAssertNil(sizePreferencesStorage.displaySizePreferences)
    }

    func testSaveContentSizeStrategy() {
        var geometry = MediaContentGeometry(
            sizePreferencesStorage: sizePreferencesStorage,
            sizePreferencesPersistenceStrategy: .contentSize
        )
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(300)

        geometry.savePreferredDisplaySize()

        XCTAssertEqual(
            sizePreferencesStorage.displaySizePreferences,
            .contentSize(containerWidthRatio: 0.5, contentWidth: 400, contentHeight: 200)
        )
    }

    func testSaveDisplayHeightStrategy() {
        var geometry = MediaContentGeometry(
            sizePreferencesStorage: sizePreferencesStorage,
            sizePreferencesPersistenceStrategy: .displayHeight
        )
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(300)

        geometry.savePreferredDisplaySize()

        XCTAssertEqual(
            sizePreferencesStorage.displaySizePreferences,
            .displayHeight(containerWidthRatio: 0.5, displayHeight: nil)
        )
    }

    func testSaveDisplayHeightStrategyCustomDisplayHeight() {
        var geometry = MediaContentGeometry(
            sizePreferencesStorage: sizePreferencesStorage,
            sizePreferencesPersistenceStrategy: .displayHeight
        )
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .both
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayHeight(350)

        geometry.savePreferredDisplaySize()

        XCTAssertEqual(
            sizePreferencesStorage.displaySizePreferences,
            .displayHeight(containerWidthRatio: 1, displayHeight: 350)
        )
    }

    func testSaveDisplayHeightStrategyCustomWidthRatioAndDisplayHeight() {
        var geometry = MediaContentGeometry(
            sizePreferencesStorage: sizePreferencesStorage,
            sizePreferencesPersistenceStrategy: .displayHeight
        )
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .both
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(300)
        geometry.setPreferredDisplayHeight(350)

        geometry.savePreferredDisplaySize()

        XCTAssertEqual(
            sizePreferencesStorage.displaySizePreferences,
            .displayHeight(containerWidthRatio: 0.5, displayHeight: 350)
        )
    }

    // MARK: - Preferred size is outside boundaries

    func testSaveRatioLargerThanContainerWidth() {
        var geometry = MediaContentGeometry(
            sizePreferencesStorage: sizePreferencesStorage,
            sizePreferencesPersistenceStrategy: .contentSize
        )

        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(700)

        geometry.savePreferredDisplaySize()

        XCTAssertEqual(
            sizePreferencesStorage.displaySizePreferences,
            .contentSize(containerWidthRatio: 1, contentWidth: 400, contentHeight: 200)
        )
    }

    func testSaveRatioSmallerThanDefaultMinWidth() {
        var geometry = MediaContentGeometry(
            sizePreferencesStorage: sizePreferencesStorage,
            sizePreferencesPersistenceStrategy: .contentSize
        )

        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(10)

        geometry.savePreferredDisplaySize()

        // 48 / 600 = 0.08
        XCTAssertEqual(
            sizePreferencesStorage.displaySizePreferences,
            .contentSize(containerWidthRatio: 0.08, contentWidth: 400, contentHeight: 200)
        )
    }

    func testSaveDisplayHeightSmallerThanDefaultMinHeight() {
        var geometry = MediaContentGeometry(
            sizePreferencesStorage: sizePreferencesStorage,
            sizePreferencesPersistenceStrategy: .displayHeight
        )
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .both
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(300)
        geometry.setPreferredDisplayHeight(10)

        geometry.savePreferredDisplaySize()

        XCTAssertEqual(
            sizePreferencesStorage.displaySizePreferences,
            .displayHeight(containerWidthRatio: 0.5, displayHeight: 48)
        )
    }

    func testSaveDisplayHeightTallerThanDefaultMaxHeight() {
        var geometry = MediaContentGeometry(
            sizePreferencesStorage: sizePreferencesStorage,
            sizePreferencesPersistenceStrategy: .displayHeight
        )
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .both
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(300)
        geometry.setPreferredDisplayHeight(3000)

        geometry.savePreferredDisplaySize()

        XCTAssertEqual(
            sizePreferencesStorage.displaySizePreferences,
            .displayHeight(containerWidthRatio: 0.5, displayHeight: 2200)
        )
    }

    func testSaveRatioSmallerThanContentMinWidth() {
        var geometry = MediaContentGeometry(
            sizePreferencesStorage: sizePreferencesStorage,
            sizePreferencesPersistenceStrategy: .contentSize
        )

        let contentDescription = MediaContentGeometryDescription(
            minWidth: 150,
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(50)

        geometry.savePreferredDisplaySize()

        XCTAssertEqual(
            sizePreferencesStorage.displaySizePreferences,
            .contentSize(containerWidthRatio: 0.25, contentWidth: 400, contentHeight: 200)
        )
    }

    func testSaveRatioLargerThanContentMaxWidth() {
        var geometry = MediaContentGeometry(
            sizePreferencesStorage: sizePreferencesStorage,
            sizePreferencesPersistenceStrategy: .contentSize
        )

        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            maxWidth: 540, // = 600 * 0.9
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(600)

        geometry.savePreferredDisplaySize()

        XCTAssertEqual(
            sizePreferencesStorage.displaySizePreferences,
            .contentSize(containerWidthRatio: 0.9, contentWidth: 400, contentHeight: 200)
        )
    }

    func testSaveDisplayHeightSmallerThanContentMinHeight() {
        var geometry = MediaContentGeometry(
            sizePreferencesStorage: sizePreferencesStorage,
            sizePreferencesPersistenceStrategy: .displayHeight
        )
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            minHeight: 100,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .both
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(300)
        geometry.setPreferredDisplayHeight(10)

        geometry.savePreferredDisplaySize()

        XCTAssertEqual(
            sizePreferencesStorage.displaySizePreferences,
            .displayHeight(containerWidthRatio: 0.5, displayHeight: 100)
        )
    }

    func testSaveDisplayHeightTallerThanContentMaxHeight() {
        var geometry = MediaContentGeometry(
            sizePreferencesStorage: sizePreferencesStorage,
            sizePreferencesPersistenceStrategy: .displayHeight
        )
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            maxHeight: 1000,
            preservesAspectRatio: false,
            resizableAxes: .both
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(300)
        geometry.setPreferredDisplayHeight(1500)

        geometry.savePreferredDisplaySize()

        XCTAssertEqual(
            sizePreferencesStorage.displaySizePreferences,
            .displayHeight(containerWidthRatio: 0.5, displayHeight: 1000)
        )
    }

    func testRestoreFromContentSizeStrategy() {
        sizePreferencesStorage.displaySizePreferences = .contentSize(
            containerWidthRatio: 0.5,
            contentWidth: 400,
            contentHeight: 200
        )

        var geometry = MediaContentGeometry(
            sizePreferencesStorage: sizePreferencesStorage
        )
        geometry.setContainerWidth(600)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 300, height: 150))
    }

    func testRestoreFromDisplayHeightStrategy() {
        sizePreferencesStorage.displaySizePreferences = .displayHeight(
            containerWidthRatio: 0.5,
            displayHeight: nil
        )

        var geometry = MediaContentGeometry(
            sizePreferencesStorage: sizePreferencesStorage
        )
        geometry.setContainerWidth(600)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 300, height: 225))
    }

    func testRestoreFromDisplayHeightStrategyCustomDisplayHeight() {
        sizePreferencesStorage.displaySizePreferences = .displayHeight(
            containerWidthRatio: 0.5,
            displayHeight: 350
        )

        var geometry = MediaContentGeometry(
            sizePreferencesStorage: sizePreferencesStorage
        )
        geometry.setContainerWidth(600)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 300, height: 350))
    }

    func testRestorePreferencesAndSizeCache() {
        sizePreferencesStorage.displaySizePreferences = .displayHeight(
            containerWidthRatio: 0.5,
            displayHeight: 350
        )

        var geometry = MediaContentGeometry(
            sizePreferencesStorage: sizePreferencesStorage,
            displaySizeCache: SizeCache(CGSize(width: 400, height: 200))
        )
        geometry.setContainerWidth(600)
        geometry.isLocked = true

        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .both
        )
        geometry.setGeometryDescription(contentDescription)

        geometry.isLocked = false

        XCTAssertEqual(geometry.displaySize, CGSize(width: 300, height: 350))
    }

}

// MARK: - Display size override

class MediaContentGeometryDisplaySizeOverrideTests: XCTestCase {

    func testApplySizeOverride() {
        var geometry = MediaContentGeometry()
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)

        geometry.setDisplaySizeOverride(CGSize(width: 400, height: 500))

        XCTAssertEqual(geometry.displaySize, CGSize(width: 400, height: 500))
    }

}

// MARK: - Display size cache

class MediaContentGeometryDisplaySizeCache: XCTestCase {

    func testSave() {
        let cache = SizeCache()
        var geometry = MediaContentGeometry(displaySizeCache: cache)
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .horizontal
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        _ = geometry.displaySize

        XCTAssertEqual(cache.displaySize, CGSize(width: 400, height: 200))
    }

    func testSaveAfterResize() {
        let cache = SizeCache()
        var geometry = MediaContentGeometry(displaySizeCache: cache)
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .both
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(300)
        geometry.setPreferredDisplayHeight(600)
        _ = geometry.displaySize

        XCTAssertEqual(cache.displaySize, CGSize(width: 300, height: 600))
    }

    func testRestore() {
        let cache = SizeCache(CGSize(width: 400, height: 200))
        var geometry = MediaContentGeometry(displaySizeCache: cache)
        geometry.setContainerWidth(600)
        geometry.isLocked = true

        XCTAssertEqual(geometry.displaySize, CGSize(width: 400, height: 200))
    }

    func testRestoreAndAdjustToContainerWidth() {
        let cache = SizeCache(CGSize(width: 400, height: 200))
        var geometry = MediaContentGeometry(displaySizeCache: cache)
        geometry.setContainerWidth(200)
        geometry.isLocked = true

        XCTAssertEqual(geometry.displaySize, CGSize(width: 200, height: 100))
    }

    func testLock() {
        var geometry = MediaContentGeometry()
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .both
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(300)

        geometry.isLocked = true
        geometry.setPreferredDisplayWidth(566)
        geometry.setPreferredDisplayHeight(399)

        XCTAssertEqual(geometry.displaySize, CGSize(width: 300, height: 200))
    }

    func testUnlock() {
        var geometry = MediaContentGeometry()
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 400,
            idealHeight: 200,
            preservesAspectRatio: false,
            resizableAxes: .both
        )
        geometry.setGeometryDescription(contentDescription)
        geometry.setContainerWidth(600)
        geometry.setPreferredDisplayWidth(300)

        geometry.isLocked = true
        geometry.setPreferredDisplayWidth(566)
        geometry.setPreferredDisplayHeight(399)

        geometry.isLocked = false

        XCTAssertEqual(geometry.displaySize, CGSize(width: 566, height: 399))
    }

    func testDoNotUpdateCacheWhileLocked() {
        let cache = SizeCache(CGSize(width: 400, height: 200))
        var geometry = MediaContentGeometry(displaySizeCache: cache)
        geometry.setContainerWidth(600)
        geometry.isLocked = true
        let contentDescription = MediaContentGeometryDescription(
            idealWidth: 566,
            idealHeight: 399,
            preservesAspectRatio: false,
            resizableAxes: .both
        )
        geometry.setGeometryDescription(contentDescription)
        _ = geometry.displaySize

        XCTAssertEqual(cache.displaySize, CGSize(width: 400, height: 200))
    }

}

// MARK: - Helpers

private final class DisplaySizePreferencesStorageFake: MediaContentDisplaySizePreferencesStorage {
    var displaySizePreferences: MediaContentGeometry.DisplaySizePreferences?
}

private final class SizeCache: MediaContentDisplaySizeCache {

    var displaySize: CGSize?

    init(_ displaySize: CGSize? = nil) {
        self.displaySize = displaySize
    }

}
