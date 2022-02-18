import Foundation
import BeamCore

public class TabColoringUpdater {
    private let myQueue = DispatchQueue(label: "tabColoringQueue")
    @Published var groupsToColor: [[UUID]]?

    func removeClosedPages(urlGroups: [[UUID]], openPages: [ClusteringManager.PageOpenInTab]) -> [[UUID]] {
        var newUrlGroups = [[UUID]]()
        for group in urlGroups where group.count > 0 {
            newUrlGroups.append(group.filter { Set(openPages.map { $0.pageId }).contains($0) })
        }
        return newUrlGroups
    }

    func removeSingles(urlGroups: [[UUID]]) -> [[UUID]] {
        var newUrlGroups = [[UUID]]()
        for group in urlGroups {
            switch group.count {
            case 0, 1:
                break
            default:
                newUrlGroups.append(group)
            }
        }
        return newUrlGroups
    }

    func update(urlGroups: [[UUID]], openPages: [ClusteringManager.PageOpenInTab]? = nil) {
        myQueue.async {
            var groupsOfOpen = urlGroups
            if let openPages = openPages {
                groupsOfOpen = self.removeClosedPages(urlGroups: urlGroups, openPages: openPages)
                groupsOfOpen = self.removeSingles(urlGroups: groupsOfOpen)
                // TODO: Consider coloring lone tabs that are in a group with a note
                // TODO: Consider merging groups based on active sources as well
                // TODO: Consider using similarity scores with notes/active-sources to split groups (similar to sources that are not to be suggested despite being in the correct group)
            }
            DispatchQueue.main.async {
                self.groupsToColor = groupsOfOpen
            }
        }
    }
}
