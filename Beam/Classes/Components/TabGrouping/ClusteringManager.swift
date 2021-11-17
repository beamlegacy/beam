//
//  ClusteringManager.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 31/05/2021.
//

import Foundation
import BeamCore
import Combine
import Clustering
import Fakery

class ClusteringManager: ObservableObject {

    enum InitialiseNotes {
        case zeroPagesAdded
        case onePageAdded
        case twoOrMorePagesAdded
    }

    var clusteredPagesId: [[UUID]] = [[]] {
        didSet {
            transformToClusteredPages()
        }
    }
    var clusteredNotesId: [[UUID]] = [[]] {
        didSet {
            transformToClusteredNotes()
            updateNoteSources()
        }
    }
    var sendRanking = false
    var initialiseNotes = false
    var ranker: SessionLinkRanker
    var activeSources: ActiveSources
    @Published var noteToAdd: BeamNote?
    @Published var clusteredTabs: [[TabInformation?]] = [[]]
    @Published var clusteredNotes: [[String?]] = [[]]
    @Published var isClustering: Bool = false
    @Published var selectedTabGroupingCandidate: Int
    @Published var weightNavigation: Double
    @Published var weightText: Double
    @Published var weightEntities: Double
    private var tabsInfo: [TabInformation] = []
    private var cluster: Cluster
    private var scope = Set<AnyCancellable>()
    var suggestedNoteUpdater: SuggestedNoteSourceUpdater
    var sessionId: UUID

    init(ranker: SessionLinkRanker, candidate: Int, navigation: Double, text: Double, entities: Double, sessionId: UUID, activeSources: ActiveSources) {
        self.selectedTabGroupingCandidate = candidate
        self.weightNavigation = navigation
        self.weightText = text
        self.weightEntities = entities
        self.activeSources = activeSources
        self.suggestedNoteUpdater = SuggestedNoteSourceUpdater(sessionId: sessionId)
        self.cluster = Cluster(candidate: candidate, weightNavigation: navigation, weightText: text, weightEntities: entities, noteContentThreshold: 100)
        self.ranker = ranker
        self.sessionId = sessionId
        setupObservers()
        #if DEBUG
        setupDebugObservers()
        #endif
    }

    private func setupObservers() {
        $noteToAdd
            .debounce(for: .milliseconds(1000), scheduler: RunLoop.main)
            .sink { value in
                if let note = value {
                    self.addNote(note: note)
                }
            }.store(in: &scope)
    }

    private func setupDebugObservers() {
        $selectedTabGroupingCandidate.sink { value in
            self.change(candidate: value,
                        weightNavigation: self.weightNavigation,
                        weightText: self.weightText,
                        weightEntities: self.weightEntities)
        }.store(in: &scope)

        $weightNavigation.sink { value in
            self.change(candidate: self.selectedTabGroupingCandidate,
                        weightNavigation: value,
                        weightText: self.weightText,
                        weightEntities: self.weightEntities)
        }.store(in: &scope)

        $weightText.sink { value in
            self.change(candidate: self.selectedTabGroupingCandidate,
                        weightNavigation: self.weightNavigation,
                        weightText: value,
                        weightEntities: self.weightEntities)
        }.store(in: &scope)

        $weightEntities.sink { value in
            self.change(candidate: self.selectedTabGroupingCandidate,
                        weightNavigation: self.weightNavigation,
                        weightText: self.weightText,
                        weightEntities: value)
        }.store(in: &scope)
    }

    func getIdAndParent(tabToIndex: TabInformation) -> (UUID?, UUID?) {
        guard tabToIndex.isPinnedTab == false else {
            return (nil, nil)
        }
        var id = tabToIndex.currentTabTree?.current.link
        var parentId = tabToIndex.parentBrowsingNode?.link
        var parentTimeStamp = Date.distantPast
        if let parent = tabToIndex.parentBrowsingNode,
           let lastEventType = parent.events.last?.type {
            if let lastEventTime = parent.events.last?.date {
                parentTimeStamp = lastEventTime
            }
            if lastEventType == .searchBarNavigation || lastEventType == .exitForward || lastEventType == .exitBackward {
                parentId = nil
            }
        }
        if let children = tabToIndex.currentTabTree?.current.children {
            for child in children {
                if let lastEventType = child.events.last?.type,
                   let lastEventTime = child.events.last?.date,
                   lastEventType == .exitBackward,
                   lastEventTime > parentTimeStamp {
                    parentTimeStamp = lastEventTime
                    parentId = nil
                    // TODO: Reconsider the relation implied by the back button
                    // when it is 100% reliable. (probably should stay the same)
                }
            }
        }
        // By definition, when opening a link in a new tab the link either
        // has no children or their events are farther in the past
        if let current = tabToIndex.currentTabTree?.current.events.last?.type,
           current == .openLinkInNewTab,
           let tabTree = tabToIndex.tabTree?.current.link {
            parentId = id
            id = tabTree
        }
        if let previousTabTree = tabToIndex.previousTabTree,
           let type = previousTabTree.current.events.last?.type,
           type == .openLinkInNewTab {
            parentId = previousTabTree.current.link
        }
        return (id, parentId)
    }

    // swiftlint:disable:next cyclomatic_complexity
    func addPage(id: UUID, parentId: UUID?, value: TabInformation? = nil, newContent: String? = nil) {
        var pageToAdd: Page?
        if let value = value {
            pageToAdd = Page(id: id, parentId: parentId, title: value.document.title, originalContent: value.cleanedTextContentForClustering)
            tabsInfo.append(value)
        } else if let newContent = newContent {
            pageToAdd = Page(id: id, parentId: nil, title: nil, cleanedContent: newContent)
            // TODO: Should we bother changing the content in tabsInfo?
        }
        isClustering = true
        var ranking: [UUID]?
        if self.sendRanking {
            ranking = self.ranker.clusteringRemovalSorted(links: self.clusteredPagesId.reduce([], +))
        }
        var replaceContent = false
        if let pageToAdd = pageToAdd {
            if newContent != nil {
                replaceContent = true
            }
            cluster.add(page: pageToAdd, ranking: ranking, replaceContent: replaceContent) { result in
                DispatchQueue.main.async {
                    self.isClustering = false
                }
                switch result {
                case .failure(let error):
                    self.isClustering = false
                    Logger.shared.logError("Error while adding page to cluster for \(pageToAdd): \(error)", category: .clustering)
                case .success(let result):
                    self.clusteredPagesId = result.pageGroups
                    self.clusteredNotesId = result.noteGroups
                    if result.flag == .sendRanking {
                        self.sendRanking = true
                        self.initialiseNotes = false
                    } else if result.flag == .addNotes {
                        self.initialiseNotes = true
                        self.sendRanking = false
                    } else {
                        self.initialiseNotes = false
                        self.sendRanking = false
                    }
                    self.logForClustering(result: result.pageGroups, changeCandidate: false)
                }
            }
        }
        // After adding the second page, add notes from previous sessions
        if self.initialiseNotes {
            let notes = BeamNote.fetchNotesWithType(type: .note, 10, 0)
            for note in notes {
                self.addNote(note: note)
            }
        }
    }

    func cleanTextFrom(note: BeamNote) -> String {
        var fullText = note.allTexts.map { $0.1.text }.joined(separator: "\n")
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return fullText }
        let matches = detector.matches(in: fullText, options: [], range: NSRange(location: 0, length: fullText.utf16.count))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: fullText) else { continue }
            fullText.removeSubrange(range)
        }
        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func addNote(note: BeamNote) {
        let fullText = cleanTextFrom(note: note)
        let clusteringNote = ClusteringNote(id: note.id, title: note.title, content: fullText)
        // TODO: Add link information to notes
        self.isClustering = true
        var ranking: [UUID]?
        if self.sendRanking {
            ranking = self.ranker.clusteringRemovalSorted(links: self.clusteredPagesId.reduce([], +))
        }
        self.cluster.add(note: clusteringNote, ranking: ranking) { result in
            DispatchQueue.main.async {
                self.isClustering = false
            }
            switch result {
            case .failure(let error):
                if error as? Cluster.AdditionError == .notEnoughTextInNote {
                    Logger.shared.logInfo("Note ignored by the clustering process due to insufficient content. Suggestions can still be made for the note.")
                } else {
                    Logger.shared.logError("Error while adding note to cluster for \(clusteringNote): \(error)", category: .clustering)
                }
            case .success(let result):
                self.clusteredPagesId = result.pageGroups
                self.clusteredNotesId = result.noteGroups
                if result.flag == .sendRanking {
                    self.sendRanking = true
                    self.initialiseNotes = false
                } else if result.flag == .addNotes {
                    self.initialiseNotes = true
                    self.sendRanking = false
                } else {
                    self.initialiseNotes = false
                    self.sendRanking = false
                }
                self.logForClustering(result: result.pageGroups, changeCandidate: false)
            }
        }
    }

    func change(candidate: Int, weightNavigation: Double, weightText: Double, weightEntities: Double) {
        isClustering = true
        cluster.changeCandidate(to: candidate, with: weightNavigation, with: weightText, with: weightEntities) { result in
            DispatchQueue.main.async {
                self.isClustering = false
            }
            switch result {
            case .failure(let error):
                Logger.shared.logError("Error while changing candidate to cluster for: \(error)", category: .clustering)
            case .success(let result):
                self.clusteredPagesId = self.reorganizeGroups(clusters: result.pageGroups)
                self.clusteredNotesId = result.noteGroups
                if result.flag == .sendRanking {
                    self.sendRanking = true
                    self.initialiseNotes = false
                } else if result.flag == .addNotes {
                    self.initialiseNotes = true
                    self.sendRanking = false
                } else {
                    self.initialiseNotes = false
                    self.sendRanking = false
                }
                self.logForClustering(result: result.pageGroups, changeCandidate: true)
            }
        }
    }

    private func reorganizeGroups(clusters: [[UUID]]) -> [[UUID]] {
        var clusters = clusters
        for cluster in clusters.enumerated() {
            clusters[cluster.offset] = self.ranker.clusteringSorted(links: cluster.element)
        }
        return clusters
    }

    private func transformToClusteredPages() {
        let clusteredTabs = self.clusteredPagesId.compactMap({ cluster in
            return cluster.map { id in
                return tabsInfo.first(where: { $0.document.id == id })
            }
        })
        DispatchQueue.main.async {
            self.clusteredTabs = clusteredTabs
        }
    }

    private func transformToClusteredNotes() {
        self.clusteredNotes = self.clusteredNotesId.compactMap({ cluster in
            return cluster.map { noteUuid in
                return BeamNote.titleForNoteId(noteUuid, false)
            }
        })
    }

    private func updateNoteSources() {
        self.suggestedNoteUpdater.update(urlGroups: self.clusteredPagesId, noteGroups: self.clusteredNotesId, activeSources: self.activeSources.activeSources)
    }

    private func logForClustering(result: [[UUID]], changeCandidate: Bool) {
        if changeCandidate {
            Logger.shared.logDebug("Result provided by ClusteringFramework from changing to candidate \(self.selectedTabGroupingCandidate) with Nav \(self.weightNavigation), Text \(self.weightText), Entities \(self.weightEntities) for result: \(result)", category: .clustering)
        } else {
            Logger.shared.logDebug("Result provided by ClusteringFramework for adding a page with candidate\(self.selectedTabGroupingCandidate): \(result)", category: .clustering)
        }

    }

    public func getOrphanedUrlGroups(urlGroups: [[UUID]], noteGroups: [[UUID]], activeSources: ActiveSources) -> [[UUID]] {
        let activeSourcesUrls = Set(activeSources.urls)
        return zip(urlGroups, noteGroups)
            .filter { _, noteGroup in return noteGroup.count == 0 } //not suggested via direct grouping
            .filter { urlGroup, _ in return activeSourcesUrls.intersection(urlGroup).count == 0 } //not suggested via active source grouping
            .map { urlGroup, _ in return urlGroup }
    }

    public func saveOrphanedUrls(orphanedUrlManager: ClusteringOrphanedUrlManager) {
        let orphanedUrlGroups = getOrphanedUrlGroups(urlGroups: clusteredPagesId, noteGroups: clusteredNotesId, activeSources: activeSources)
        let savedAt = BeamDate.now
        for (id, group) in orphanedUrlGroups.enumerated() {
            for urlId in group {
                let url = LinkStore.linkFor(urlId)?.url
                orphanedUrlManager.add(orphanedUrl: OrphanedUrl(sessionId: sessionId, url: url, groupId: id, savedAt: savedAt))
            }
        }
        orphanedUrlManager.save()
    }
}
