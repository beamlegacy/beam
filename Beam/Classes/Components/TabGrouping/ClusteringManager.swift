//
//  ClusteringManager.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 31/05/2021.
//
// swiftlint:disable:next file_length, type_body_length

import Foundation
import BeamCore
import Combine
import Clustering
import Fakery

// swiftlint:disable:next type_body_length
class ClusteringManager: ObservableObject {

    public struct SummaryForNewDay: Codable {
        var notes: [Date: [UUID]]?
        var pageId: UUID?
        var pageDate: Date = Date.distantPast
        var pageScore: Float = 0
    }

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
            if clusteredNotesId.count > 1 {
                updateNoteSources()
            }
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
    var navigationBasedPageGroups = [[UUID]]()
    var similarities = [UUID: [UUID: Double]]()
    var notesChangedByUserInSession = [UUID]()
    let LongTermUrlScoreStoreProtocol = LongTermUrlScoreStore.shared
    let frecencyFetcher = GRDBUrlFrecencyStorage()
    var summary: SummaryForNewDay
    public var continueToNotes = [UUID]()
    public var continueToPage: UUID?

    // swiftlint:disable:next function_body_length
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
        self.summary = SummaryForNewDay()
        if let summaryString = Persistence.ContinueTo.summary,
           let jsonData = summaryString.data(using: .utf8),
           let unwrappedSummary = try? JSONDecoder().decode(SummaryForNewDay.self, from: jsonData) {
            self.summary = unwrappedSummary
        }
        if let notesWithActivity = summary.notes {
            let allNotesWithFrequency = NSCountedSet(array: notesWithActivity.compactMap({ $0.value }))
            if let mostFrequentNote = allNotesWithFrequency.max(by: { allNotesWithFrequency.count(for: $0) < allNotesWithFrequency.count(for: $1) }) as? UUID {
                self.continueToNotes.append(mostFrequentNote)
            }
            for noteDate in notesWithActivity.keys.sorted(by: { $0 > $1 }) {
//                if Calendar.current.isDate(BeamDate.now, equalTo: noteDate, toGranularity: .day) {
//                    continue
//                }
                if let notesFromDate = notesWithActivity[noteDate] {
                    if notesFromDate.indices.contains(0) {
                        self.continueToNotes.append(notesFromDate[0]) // TODO: Try also random element
                        self.continueToNotes = Array(Set(self.continueToNotes))
                    }
                    if notesFromDate.indices.contains(1),
                       self.continueToNotes.count < 2 {
                        self.continueToNotes.append(notesFromDate[1])
                        self.continueToNotes = Array(Set(self.continueToNotes))
                    }
                }
                if continueToNotes.count > 1 {
                    break
                }
            }
        }
        if let pageWithActivity = summary.pageId {
            self.continueToPage = pageWithActivity
        }
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

    func findPageGroupForID(pageID: UUID, pageGroups: [[UUID]]) -> Int? {
        for pageGroup in pageGroups.enumerated() {
            if pageGroup.element.contains(pageID) {
                return pageGroup.offset
            }
        }
        return nil
    }

    // swiftlint:disable:next cyclomatic_complexity, function_body_length
    func getIdAndParent(tabToIndex: TabInformation) -> (UUID?, UUID?) {
        guard tabToIndex.isPinnedTab == false else {
            return (nil, nil)
        }
        var id = tabToIndex.currentTabTree?.current.link
        var parentId = tabToIndex.parentBrowsingNode?.link
        var parentTimeStamp = Date.distantPast
        switch tabToIndex.currentTabTree?.origin {
        case .linkFromNote(let noteName):
            if let root = tabToIndex.currentTabTree?.root,
               tabToIndex.parentBrowsingNode?.id == root.id,
               let id = id,
               let note = BeamNote.fetch(title: noteName) {
                note.sources.add(urlId: id, noteId: note.id, type: .user, sessionId: self.sessionId, activeSources: self.activeSources)
                self.addNote(note: note)
            }
        default:
            break
        }
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

        // The following is only here in order to save groups based on navigation, remove before release:
        if let id = id,
           self.findPageGroupForID(pageID: id, pageGroups: self.navigationBasedPageGroups) == nil {
            if let parentId = parentId,
               let group = self.findPageGroupForID(pageID: parentId, pageGroups: self.navigationBasedPageGroups) {
                self.navigationBasedPageGroups[group].append(id)
            } else {
                self.navigationBasedPageGroups.append([id])
            }
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
            cluster.add(page: pageToAdd, ranking: ranking, activeSources: Array(Set(activeSources.urls)), replaceContent: replaceContent) { result in
                DispatchQueue.main.async {
                    self.isClustering = false
                }
                switch result {
                case .failure(let error):
                    self.isClustering = false
                    Logger.shared.logError("Error while adding page to cluster for \(pageToAdd): \(error)", category: .clustering)
                case .success(let result):
                    self.similarities = result.similarities
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
            let notes = DocumentManager().loadAllWithLimit(10, sortingKey: .updatedAt(false), type: .note).compactMap {
                BeamNote.fetch(id: $0.id)
            }
            for note in notes {
                self.addNote(note: note, addToNextSummary: false)
            }
        }
    }

    func cleanTextFrom(note: BeamNote) -> [String] {
        var fullText = [note.title] + note.allTexts.map { $0.1.text }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return fullText }
        for block in fullText.enumerated() {
            let matches = detector.matches(in: block.element, options: [], range: NSRange(location: 0, length: block.element.utf16.count))
            var newBlock = block.element
            for match in matches.reversed() {
                guard let range = Range(match.range, in: newBlock) else { continue }
                newBlock.removeSubrange(range)
            }
            fullText[block.offset] = newBlock
        }
        return fullText
    }

    func addNote(note: BeamNote, addToNextSummary: Bool = true) {
        if addToNextSummary,
           !self.notesChangedByUserInSession.contains(note.id) {
            notesChangedByUserInSession.append(note.id)
        }
        let fullText = cleanTextFrom(note: note)
        let clusteringNote = ClusteringNote(id: note.id, title: note.title, content: fullText)
        // TODO: Add link information to notes
        self.isClustering = true
        var ranking: [UUID]?
        if self.sendRanking {
            ranking = self.ranker.clusteringRemovalSorted(links: self.clusteredPagesId.reduce([], +))
        }
        self.cluster.add(note: clusteringNote, ranking: ranking, activeSources: Array(Set(activeSources.urls))) { result in
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
                self.similarities = result.similarities
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
        cluster.changeCandidate(to: candidate, with: weightNavigation, with: weightText, with: weightEntities, activeSources: Array(Set(activeSources.urls))) { result in
            DispatchQueue.main.async {
                self.isClustering = false
            }
            switch result {
            case .failure(let error):
                Logger.shared.logError("Error while changing candidate to cluster for: \(error)", category: .clustering)
            case .success(let result):
                self.similarities = result.similarities
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
        self.suggestedNoteUpdater.update(urlGroups: self.clusteredPagesId, noteGroups: self.clusteredNotesId, activeSources: self.activeSources.activeSources, similarities: self.similarities)
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
                orphanedUrlManager.add(orphanedUrl: OrphanedUrl(sessionId: sessionId, url: url, groupId: id, navigationGroupId: self.findPageGroupForID(pageID: urlId, pageGroups: self.navigationBasedPageGroups), savedAt: savedAt))
            }
        }
        orphanedUrlManager.save()
    }

    // swiftlint:disable:next cyclomatic_complexity
    public func exportSummaryForNextSession() {
        if self.notesChangedByUserInSession.isEmpty {
            for (pageGroup, noteGroup) in zip(self.clusteredPagesId, self.clusteredNotesId).reversed() {
                if !noteGroup.isEmpty && !pageGroup.isEmpty {
                    for noteId in noteGroup {
                        self.notesChangedByUserInSession.append(noteId)
                    }
                }
            }
        }
        let allVisitedPages = self.clusteredPagesId.flatMap({ $0 })
        let allLongTermScores = self.LongTermUrlScoreStoreProtocol.getMany(urlIds: allVisitedPages)
        let allScores = allLongTermScores.enumerated().map { longTermScore -> Float in
            if let frecency = try? self.frecencyFetcher.fetchOne(id: allVisitedPages[longTermScore.offset], paramKey: .webVisit30d0)?.lastScore {
                return longTermScore.element.score() / frecency
            } else {
                return longTermScore.element.score()
            }
        }
        let dateToAdd = BeamDate.now
        if allVisitedPages.count > 0 && allScores.count > 0 {
            let (pageToPropose, pageScoreToPropose) = zip(allVisitedPages, allScores).sorted {$0.1 > $1.1}[0]
            if self.summary.pageId == nil {
                summary.pageId = pageToPropose
                summary.pageDate = dateToAdd
                summary.pageScore = pageScoreToPropose
            } else if !Calendar.current.isDate(dateToAdd, equalTo: summary.pageDate, toGranularity: .day) || summary.pageScore < pageScoreToPropose {
                summary.pageId = pageToPropose
                summary.pageDate = dateToAdd
                summary.pageScore = pageScoreToPropose
               }
        }
        if !self.notesChangedByUserInSession.isEmpty {
            if summary.notes == nil {
                summary.notes = [dateToAdd: self.notesChangedByUserInSession]
            } else {
                summary.notes?[dateToAdd] = self.notesChangedByUserInSession
                while summary.notes?.keys.count ?? 0 > 10 {
                    if let furthestDate = summary.notes?.keys.sorted(by: { $0 < $1 })[0],
                       Calendar.current.dateComponents([.day], from: furthestDate, to: dateToAdd).day ?? 0 > 7 {
                        summary.notes?[furthestDate] = nil
                    } else {
                        break
                    }
                }
            }
        }
        if let jsonData = try? JSONEncoder().encode(summary),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            Persistence.ContinueTo.summary = jsonString
        }
    }
    // swiftlint:disable:next file_length
}
