import Foundation
@testable import Beam

final class DownloadItemDelegateMock: NSObject {

    var state: DownloadListItemState?

}

extension DownloadItemDelegateMock: DownloadItemDelegate {

    func downloadItem<T: DownloadListItem>(_ downloadItem: T, stateDidChange state: DownloadListItemState) {
        self.state = state
    }

}
