import Foundation

public class ActiveSources {
    public var activeSources: [UUID: [UUID]]

    public init() {
        activeSources = [UUID: [UUID]]()
    }

    public func addActiveSource(pageId: UUID, noteId: UUID) {
        if var pages = self.activeSources[noteId] {
            if !pages.contains(pageId) {
                pages.append(pageId)
                self.activeSources[noteId] = pages
            }
        } else {
            self.activeSources[noteId] = [pageId]
        }
    }

    public func removeActiveSource(pageId: UUID, noteId: UUID) {
        if var pages = self.activeSources[noteId] {
            while let index = pages.firstIndex(of: pageId) {
                pages.remove(at: index)
            }
            self.activeSources[noteId] = pages
        }
    }
    public var urls: [UUID] { activeSources.values.flatMap { $0 } }
}
