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

    func mergeSinglesOfSameDomain(urlGroups: [[UUID]], allOpenPages: [ClusteringManager.PageOpenInTab]) -> [[UUID]] {
        var newUrlGroups = [[UUID]]()
        var singles = [String: [UUID]]()
        for group in urlGroups {
            switch group.count {
            case 0:
                break
            case 1:
                if let hostName = allOpenPages.first(where: { $0.pageId == group[0] })?.domain {
                    if singles.keys.contains(hostName) {
                        singles[hostName]?.append(group[0])
                    } else {
                        singles[hostName] = [group[0]]
                    }
                }
            default:
                newUrlGroups.append(group)
            }
        }
        for newGroup in singles.values {
            newUrlGroups.append(newGroup)
        }
        return newUrlGroups
    }

    func mergeSingleWithGroupOfSameDomain(urlGroups: [[UUID]], allOpenPages: [ClusteringManager.PageOpenInTab]) -> [[UUID]] {
        var groupsWithOneDomain = [String: [Int]]()
        for group in urlGroups.enumerated() {
            if let groupDomain = allOpenPages.first(where: { $0.pageId == group.element[0] })?.domain {
                for id in group.element {
                    if let hostName = allOpenPages.first(where: { $0.pageId == id })?.domain,
                       hostName != groupDomain {
                        break
                    }
                    if group.element.last == id {
                        if groupsWithOneDomain.keys.contains(groupDomain) {
                            groupsWithOneDomain[groupDomain]?.append(group.offset)
                        } else {
                            groupsWithOneDomain[groupDomain] = [group.offset]
                        }
                    }
                }
            }
        }
        var groupsToErase = [Int]()
        var groupsToAdd = [[UUID]]()
        for domain in groupsWithOneDomain.keys {
            if groupsWithOneDomain[domain]?.count == 2,
               let groupOne = groupsWithOneDomain[domain]?[0],
               let groupTwo = groupsWithOneDomain[domain]?[1],
               urlGroups[groupOne].count == 1 || urlGroups[groupTwo].count == 1 {
                groupsToErase.append(groupOne)
                groupsToErase.append(groupTwo)
                groupsToAdd.append(urlGroups[groupOne] + urlGroups[groupTwo])
            }
        }
        var newUrlGroups = urlGroups + groupsToAdd
        newUrlGroups = newUrlGroups.enumerated().filter { !Set(groupsToErase).contains($0.offset) }.map { $0.element }
        return newUrlGroups
    }

    func update(urlGroups: [[UUID]], openPages: [ClusteringManager.PageOpenInTab]? = nil) {
        myQueue.async {
            var groupsOfOpen = urlGroups
            if let openPages = openPages {
                groupsOfOpen = self.removeClosedPages(urlGroups: urlGroups, openPages: openPages)
                groupsOfOpen = self.mergeSinglesOfSameDomain(urlGroups: groupsOfOpen, allOpenPages: openPages)
                groupsOfOpen = self.mergeSingleWithGroupOfSameDomain(urlGroups: groupsOfOpen, allOpenPages: openPages)
            }
            DispatchQueue.main.async {
                self.groupsToColor = groupsOfOpen
            }
        }
    }
}
