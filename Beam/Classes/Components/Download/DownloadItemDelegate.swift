protocol DownloadItemDelegate: AnyObject {

    func downloadItem<T: DownloadListItem>(_ downloadItem: T, stateDidChange state: DownloadListItemState)

}
