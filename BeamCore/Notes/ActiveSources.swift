import Foundation

public class ActiveSources {
    public var activeSources: [UUID: [UInt64]]

    public init() {
        activeSources = [UUID: [UInt64]]()
    }

    public func addActiveSource(pageId: UInt64, noteId: UUID) {
        if var pages = self.activeSources[noteId] {
            if !pages.contains(pageId) {
                pages.append(pageId)
                self.activeSources[noteId] = pages
            }
        } else {
            self.activeSources[noteId] = [pageId]
        }
    }

    public func removeActiveSource(pageId: UInt64, noteId: UUID) {
        if var pages = self.activeSources[noteId] {
            while let index = pages.firstIndex(of: pageId) {
                pages.remove(at: index)
            }
            self.activeSources[noteId] = pages
        }
    }
}
