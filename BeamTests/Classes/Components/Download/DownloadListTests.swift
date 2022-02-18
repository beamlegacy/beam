import XCTest
import Combine
@testable import Beam

class DownloadListTests: XCTestCase {

    private var downloadList: DownloadList<DownloadListItemMock>!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        downloadList = DownloadList<DownloadListItemMock>()
        cancellables = []
    }

    func testAdd() {
        let d1 = DownloadListItemMock(id: 1, state: .running)
        let d2 = DownloadListItemMock(id: 2, state: .running)
        downloadList.addDownload(d1)
        downloadList.addDownload(d2)

        XCTAssertEqual(downloadList.downloads.count, 2)
        XCTAssertTrue(downloadList.downloads.contains(d1))
        XCTAssertTrue(downloadList.downloads.contains(d2))
    }

    func testReverseChronologicalOrder() {
        let d1 = DownloadListItemMock(id: 1, state: .running)
        let d2 = DownloadListItemMock(id: 2, state: .running)
        let d3 = DownloadListItemMock(id: 3, state: .running)
        downloadList.addDownload(d1)
        downloadList.addDownload(d2)
        downloadList.addDownload(d3)

        XCTAssertEqual(downloadList.downloads[0].id, 3)
        XCTAssertEqual(downloadList.downloads[1].id, 2)
        XCTAssertEqual(downloadList.downloads[2].id, 1)
    }

    func testAddDuplicate() {
        downloadList.addDownload(DownloadListItemMock(id: 1, state: .running))
        downloadList.addDownload(DownloadListItemMock(id: 1, state: .suspended))

        XCTAssertEqual(downloadList.downloads.count, 1)
    }

    func testDownloading() {
        downloadList.addDownload(DownloadListItemMock(id: 1, state: .running))
        downloadList.addDownload(DownloadListItemMock(id: 2, state: .suspended))
        downloadList.addDownload(DownloadListItemMock(id: 3, state: .running))

        XCTAssertTrue(downloadList.isDownloading)
    }

    func testNotDownloading() {
        downloadList.addDownload(DownloadListItemMock(id: 1, state: .completed))
        downloadList.addDownload(DownloadListItemMock(id: 2, state: .suspended))
        downloadList.addDownload(DownloadListItemMock(id: 3, state: .suspended))

        XCTAssertFalse(downloadList.isDownloading)
    }

    func testDownloadingUpdates() {
        let d1 = DownloadListItemMock(id: 1, state: .suspended)
        let d2 = DownloadListItemMock(id: 2, state: .suspended)
        downloadList.addDownload(d1)
        downloadList.addDownload(d2)

        d1.state = .running

        XCTAssertTrue(downloadList.isDownloading)
    }

    func testRunningDownloads() {
        let d1 = DownloadListItemMock(id: 1, state: .running)
        let d2 = DownloadListItemMock(id: 2, state: .suspended)
        let d3 = DownloadListItemMock(id: 3, state: .running)
        downloadList.addDownload(d1)
        downloadList.addDownload(d2)
        downloadList.addDownload(d3)

        let runningDownloads = downloadList.runningDownloads
        XCTAssertEqual(runningDownloads.count, 2)
        XCTAssertTrue(runningDownloads.contains(d1))
        XCTAssertTrue(runningDownloads.contains(d3))
    }

    func testContainsOnlyCompletedOrSuspendedDownloads() {
        downloadList.addDownload(DownloadListItemMock(id: 1, state: .completed))
        downloadList.addDownload(DownloadListItemMock(id: 2, state: .suspended))
        downloadList.addDownload(DownloadListItemMock(id: 3, state: .completed))

        XCTAssertTrue(downloadList.containsOnlyCompletedOrSuspendedDownloads)
    }

    func testDoesNotContainOnlyCompletedOrSuspendedDownloads() {
        downloadList.addDownload(DownloadListItemMock(id: 1, state: .running))
        downloadList.addDownload(DownloadListItemMock(id: 2, state: .suspended))
        downloadList.addDownload(DownloadListItemMock(id: 3, state: .completed))

        XCTAssertFalse(downloadList.containsOnlyCompletedOrSuspendedDownloads)
    }

    func testRemoveRunningDownloadIfCompletedOrSuspended() {
        let d1 = DownloadListItemMock(id: 1, state: .running)
        let d2 = DownloadListItemMock(id: 2, state: .suspended)
        downloadList.addDownload(d1)
        downloadList.addDownload(d2)

        downloadList.removeDownloadIfCompletedOrSuspended(d1)

        XCTAssertEqual(downloadList.downloads.count, 2)
    }

    func testRemoveSuspendedDownloadIfCompletedOrSuspended() {
        let d1 = DownloadListItemMock(id: 1, state: .running)
        let d2 = DownloadListItemMock(id: 2, state: .suspended)
        downloadList.addDownload(d1)
        downloadList.addDownload(d2)

        downloadList.removeDownloadIfCompletedOrSuspended(d2)

        XCTAssertEqual(downloadList.downloads.count, 1)
    }

    func testRemoveAllCompletedOrSuspendedDownloads() {
        let d1 = DownloadListItemMock(id: 1, state: .running)
        let d2 = DownloadListItemMock(id: 2, state: .suspended)
        let d3 = DownloadListItemMock(id: 3, state: .completed)
        downloadList.addDownload(d1)
        downloadList.addDownload(d2)
        downloadList.addDownload(d3)

        downloadList.removeAllCompletedOrSuspendedDownloads()

        XCTAssertEqual(downloadList.downloads.count, 1)
        XCTAssertTrue(downloadList.downloads.contains(d1))
    }

    func testProgressFractionCompleted() {
        let d1 = DownloadListItemMock(id: 1, state: .running)
        let d2 = DownloadListItemMock(id: 2, state: .suspended)
        let d3 = DownloadListItemMock(id: 3, state: .running)
        let d4 = DownloadListItemMock(id: 4, state: .completed)
        downloadList.addDownload(d1)
        downloadList.addDownload(d2)
        downloadList.addDownload(d3)
        downloadList.addDownload(d4)

        d1.progressFractionCompleted = 0.2
        d2.progressFractionCompleted = 0.5 // Not running, ignored from computation
        d3.progressFractionCompleted = 0.4
        d4.progressFractionCompleted = 1 // Not running, ignored from computation

        let expectation = XCTestExpectation()
        var fraction: Double = 0

        downloadList.$progressFractionCompleted
            .dropFirst()
            .sink { value in
                fraction = value
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 10)

        // (d1: 0.2) + (d3: 0.4) = (0.6 / 2) = 0.3
        XCTAssertEqual(fraction, 0.3, accuracy: 0.0001)
    }

}
