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

protocol ClusteringManagerProtocol {
    var typeInUse: ClusteringType { get }
    func getIdAndParent(tabToIndex: TabIndexingInfo) -> (UUID?, UUID?)
    func addPage(id: UUID, tabId: UUID, parentId: UUID?, value: TabIndexingInfo?)
    func addPage(id: UUID, tabId: UUID, parentId: UUID?, value: TabIndexingInfo?, newContent: String?)
    func removePage(pageId: UUID, tabId: UUID)
}

class ClusteringManager: ObservableObject {

    /// An UUID generated from a web page URL
    typealias PageID = UUID
    public struct BrowsingTreeOpenInTab {
        weak var browsingTree: BrowsingTree?
        let browserTabManagerId: UUID
    }

    public struct AllBrowsingTreesOpenInTabs {
        var allOpenBrowsingTrees = [BrowsingTreeOpenInTab]()
        var allOpenBrowsingPages: [PageID?] {
            allOpenBrowsingTrees.map { $0.browsingTree?.current?.link }
        }
    }

    var clusteredPagesId: [[PageID]] = [[]] {
        didSet {
            transformToClusteredPages()
            if clusteredPagesId.count > 0 && PreferencesManager.enableTabGrouping {
                updateTabGroupsWithOpenPages()
            }
        }
    }
    var clusteredNotesId: [[UUID]] = [[]] {
        didSet {
            transformToClusteredNotes()
        }
    }
    var sendRanking = false
    var ranker: SessionLinkRanker
    let noteToAdd = PassthroughSubject<BeamNote, Never>()
    @Published var clusteredTabs: [[TabIndexingInfo?]] = [[]]
    @Published var clusteredNotes: [[String?]] = [[]]
    @Published var isClustering: Bool = false
    @Published var selectedTabGroupingCandidate: Int
    @Published var weightNavigation: Double
    @Published var weightText: Double
    @Published var weightEntities: Double
    private var clusteringBridge: ClusteringBridge
    private var tabsInfo: [TabIndexingInfo] = []
    private var scope = Set<AnyCancellable>()
    weak private(set) var tabGroupingManager: TabGroupingManager?
    var sessionId: UUID
    var navigationBasedPageGroups = [[UUID]]()
    var notesChangedByUserInSession = [UUID]()
    var openBrowsing = AllBrowsingTreesOpenInTabs()
    public var continueToNotes = [UUID]()
    public var continueToPage: PageID?
    private var resultProcessQueue = DispatchQueue(label: "ClusteringManagerResultProcessing", target: .userInitiated)
    // swiftlint:disable:next function_body_length
    init(ranker: SessionLinkRanker, candidate: Int, navigation: Double, text: Double, entities: Double, sessionId: UUID, tabGroupingManager: TabGroupingManager?, objectManager: BeamObjectManager, forcedClusteringType: ClusteringType? = nil) {
        self.selectedTabGroupingCandidate = candidate
        self.weightNavigation = navigation
        self.weightText = text
        self.weightEntities = entities
        self.tabGroupingManager = tabGroupingManager
        let clusteringType = forcedClusteringType ?? ClusteringType.current
        self.clusteringBridge = clusteringType.buildBridge(selectedTabGroupingCandidate: candidate,
                                                           weightNavigation: navigation,
                                                           weightText: text,
                                                           weightEntities: entities)
        self.ranker = ranker
        self.sessionId = sessionId
        setupObservers()
        #if DEBUG
        setupDebugObservers()
        #endif
    }

    func changeClusteringType(_ type: ClusteringType) {
        self.clusteringBridge = type.buildBridge(selectedTabGroupingCandidate: selectedTabGroupingCandidate,
                                                 weightNavigation: weightNavigation,
                                                 weightText: weightText,
                                                 weightEntities: weightEntities)
    }

    private func setupObservers() {
        self.noteToAdd
            .debounce(for: .milliseconds(1000), scheduler: RunLoop.main)
            .sink { value in
                self.addNote(note: value)
            }.store(in: &scope)
    }

    private func setupDebugObservers() {
        $selectedTabGroupingCandidate.dropFirst().sink { value in
            self.change(candidate: value,
                        weightNavigation: self.weightNavigation,
                        weightText: self.weightText,
                        weightEntities: self.weightEntities)
        }.store(in: &scope)

        $weightNavigation.dropFirst().sink { value in
            self.change(candidate: self.selectedTabGroupingCandidate,
                        weightNavigation: value,
                        weightText: self.weightText,
                        weightEntities: self.weightEntities)
        }.store(in: &scope)

        $weightText.dropFirst().sink { value in
            self.change(candidate: self.selectedTabGroupingCandidate,
                        weightNavigation: self.weightNavigation,
                        weightText: value,
                        weightEntities: self.weightEntities)
        }.store(in: &scope)

        $weightEntities.dropFirst().sink { value in
            self.change(candidate: self.selectedTabGroupingCandidate,
                        weightNavigation: self.weightNavigation,
                        weightText: self.weightText,
                        weightEntities: value)
        }.store(in: &scope)
    }

    func findPageGroupForID(pageId: PageID, pageGroups: [[UUID]]) -> Int? {
        for pageGroup in pageGroups.enumerated() {
            if pageGroup.element.contains(pageId) {
                return pageGroup.offset
            }
        }
        return nil
    }

    func shouldBeWithAndApart(pageId: PageID, beWith: [PageID], beApart: [PageID]) {
        guard typeInUse == .legacy else { return }
        let pageToUpdate = Page(id: pageId, tabId: UUID(), beWith: beWith, beApart: beApart)
        isClustering = true
        clusteringBridge.add(textualItem: pageToUpdate.toTextualItem(), ranking: nil) { result in
            DispatchQueue.main.async {
                self.isClustering = false
            }
            switch result {
            case .failure(let error):
                self.isClustering = false
                if error as? LegacyClustering.AdditionError == .skippingToNextAddition {
                    Logger.shared.logInfo("Skipping to next addition before performing the final clustering")
                } else if error as? LegacyClustering.AdditionError == .abortingAdditionDuringClustering {
                    Logger.shared.logInfo("Aborting addition temporarility as to not hinder ongoing clustering process")
                } else {
                    Logger.shared.logError("Error while updating page in the cluster for \(pageToUpdate): \(error)", category: .clustering)
                }
            case .success(let result):
                self.updateClustersWithResult(result, changeCandidate: false)
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
        clusteringBridge.add(textualItem: clusteringNote.toTextualItem(), ranking: ranking) { result in
            DispatchQueue.main.async {
                self.isClustering = false
            }
            switch result {
            case .failure(let error):
                if error as? LegacyClustering.AdditionError == .notEnoughTextInNote {
                    Logger.shared.logInfo("Note ignored by the clustering process due to insufficient content. Suggestions can still be made for the note.")
                } else if error as? LegacyClustering.AdditionError == .skippingToNextAddition {
                    Logger.shared.logInfo("Skipping to next addition before performing the final clustering")
                } else if error as? LegacyClustering.AdditionError == .abortingAdditionDuringClustering {
                    Logger.shared.logInfo("Aborting addition temporarility as to not hinder ongoing clustering process")
                } else {
                    Logger.shared.logError("Error while adding note to cluster for \(clusteringNote): \(error)", category: .clustering)
                }
            case .success(let result):
                self.updateClustersWithResult(result, changeCandidate: false)
            }
        }
    }

    func removeNote(noteId: UUID) {
        clusteringBridge.removeTextualItem(textualItemUUID: noteId, textualItemTabId: noteId) { [weak self] result in
            guard let self = self, self.clusteringBridge.type == .smart else { return }
            switch result {
            case .failure(let error):
                Logger.shared.logError("\(error)", category: .clustering)
            case .success(let result):
                self.updateClustersWithResult(result, changeCandidate: false)
            }
        }
    }

    func change(candidate: Int, weightNavigation: Double, weightText: Double, weightEntities: Double) {
        isClustering = true
        clusteringBridge.changeCandidate(to: candidate, withWeightNavigation: weightNavigation,
                                         weightText: weightText, weightEntities: weightEntities) { result in
            DispatchQueue.main.async {
                self.isClustering = false
            }
            switch result {
            case .failure(let error):
                Logger.shared.logError("Error while changing candidate to cluster for: \(error)", category: .clustering)
            case .success(let result):
                self.updateClustersWithResult(result, changeCandidate: true)
            }
        }
    }

    private func splitByType(groups: [[UUID]]) {
        let pageIds = self.tabsInfo.map { $0.document.id }
        self.clusteredPagesId = groups.map { group in
            group.filter { id in
                pageIds.contains(id)
            }
        }
        self.clusteredNotesId = groups.map { group in
            group.filter { id in
                !pageIds.contains(id)
            }
        }
    }
    private func updateClustersWithResult(_ result: ClusteringResultValue, changeCandidate: Bool) {
        resultProcessQueue.async {
            self.splitByType(groups: result.groups)
            self.sendRanking = result.legacyFlag == .sendRanking
        }
        self.logForClustering(result: self.clusteredPagesId, changeCandidate: changeCandidate)
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
        let clusteredNotes = self.clusteredNotesId.compactMap({ cluster in
            return cluster.map { noteUuid in
                return BeamNote.titleForNoteId(noteUuid)
            }
        })
        DispatchQueue.main.async {
            self.clusteredNotes = clusteredNotes
        }
    }

    private func updateTabGroupsWithOpenPages() {
        Task { @MainActor in
            await self.tabGroupingManager?.updateAutomaticClustering(urlGroups: self.clusteredPagesId, openPages: self.openBrowsing.allOpenBrowsingPages)
        }
    }

    private func logForClustering(result: [[UUID]], changeCandidate: Bool) {
        var resultDescription = "\(result)"
        #if DEBUG
        var grps = [String]()

        for cluster in result {
            var grp = [String]()

            for uuid in cluster {
                if let linkStoreURL = LinkStore.shared.linkFor(id: uuid)?.url {
                    grp.append(URL(string: linkStoreURL)!.urlStringByRemovingUnnecessaryCharacters)
                }
            }

            if grp.isEmpty {
                grps.append("[]")
            } else {
                grps.append("\(grp)")
            }
        }

        resultDescription = "[\(grps.joined(separator: ", "))]"
        #endif
        if changeCandidate {
            Logger.shared.logDebug("Result provided by ClusteringFramework from changing to candidate \(self.selectedTabGroupingCandidate) with Nav \(self.weightNavigation), Text \(self.weightText), Entities \(self.weightEntities) for result: \(resultDescription)", category: .clustering)
        } else {
            Logger.shared.logDebug("Result provided by ClusteringFramework for adding a page with candidate\(self.selectedTabGroupingCandidate): \(resultDescription)", category: .clustering)
        }

    }
}

extension ClusteringManager: ClusteringManagerProtocol {
    var typeInUse: ClusteringType {
        clusteringBridge.type
    }

    func getIdAndParent(tabToIndex: TabIndexingInfo) -> (UUID?, UUID?) {
        guard tabToIndex.isPinnedTab == false else {
            return (nil, nil)
        }
        let id = tabToIndex.tabTree?.current.link
        var parentId: UUID?
        var parentTimeStamp = Date.distantPast
        // Check the case where a link is opened from a note
        switch tabToIndex.tabTree?.origin {
        case .linkFromNote(let noteName):
            if let noteName = noteName, let root = tabToIndex.tabTree?.root,
               tabToIndex.tabTree?.current.parent?.id == root.id,
               let id = id,
               let note = BeamNote.fetch(title: noteName) {
                if note.type == .note {
                    self.addNote(note: note)
                }
                return (id, nil)
            }
        default:
            break
        }
        // When not opening a link from a note, start with the case of opening a link in a new tab
        if let currentTabId = tabToIndex.currentTabTree?.current.link,
           currentTabId != id, // The tab to be added is not the active one
           let parentOpenId = tabToIndex.currentTabTree?.current.link,
           let current = tabToIndex.currentTabTree?.current.events.last?.type,
           current == .openLinkInNewTab { // The last event of the active tab is to open a link in a new tab
            parentId = parentOpenId
        } else { // A simple link opening in the same tab
            if let parent = tabToIndex.tabTree?.current.parent,
               let lastEventType = parent.events.last?.type,
               lastEventType == .navigateToLink ||
                lastEventType == .exitForward ||
                lastEventType == .exitBackward {
                parentId = parent.link
                parentTimeStamp = parent.events.last?.date ?? Date.distantPast
            } else if let parent = tabToIndex.tabTree?.current.parent,
                      let root = tabToIndex.tabTree?.root,
                      parent.id == root.id,
                      let previousTabTree = tabToIndex.previousTabTree,
                      let lastEventTypePreviousTree = previousTabTree.current.events.last?.type,
                      lastEventTypePreviousTree == .openLinkInNewTab {
                parentId = previousTabTree.current.link
                parentTimeStamp = previousTabTree.current.events.last?.date ?? parentTimeStamp
            }
            if let children = tabToIndex.tabTree?.current.children {
                for child in children {
                    if let lastEventType = child.events.last?.type,
                       let lastEventTime = child.events.last?.date,
                       lastEventType == .exitBackward,
                       lastEventTime > parentTimeStamp {
                        parentTimeStamp = lastEventTime
                        parentId = child.link
                    }
                }
            }
        }
        // The following is only here in order to save groups based on navigation, remove before release:
        if let id = id,
           self.findPageGroupForID(pageId: id, pageGroups: self.navigationBasedPageGroups) == nil {
            if let parentId = parentId,
               let group = self.findPageGroupForID(pageId: parentId, pageGroups: self.navigationBasedPageGroups) {
                self.navigationBasedPageGroups[group].append(id)
            } else {
                self.navigationBasedPageGroups.append([id])
            }
        }
        return (id, parentId)
    }

    func addPage(id: UUID, tabId: UUID, parentId: UUID?, value: TabIndexingInfo?) {
        addPage(id: id, tabId: tabId, parentId: parentId, value: value, newContent: nil)
    }
    
    func addUnpinTab(tabToUnpin: BrowserTab) {
        guard let url = tabToUnpin.url else { return }

        Readability.read(tabToUnpin.webView) { [weak self] result in
            switch result {
            case let .failure(error):
                Logger.shared.logError("Error while reading when unpintab: \(error)", category: .tabGrouping)
            case let .success(read):
                guard let self = self else { return }
                var currentId: UUID?
                var parentId: UUID?
                
                guard let readabilityResult = read else { return }
                let indexDocument = IndexDocument(source: url.absoluteString, title: tabToUnpin.webView.title ?? "", contents: readabilityResult.textContentForClustering.joined(separator: " "))
                let tabIndexingInfo = TabIndexingInfo(url: url, tabId: tabToUnpin.id,
                                                      requestedURL: nil,
                                                      shouldBeIndexed: tabToUnpin.responseStatusCode == 200,
                                                      tabTree: tabToUnpin.browsingTree.deepCopy(),
                                                      currentTabTree: nil,
                                                      previousTabTree: nil,
                                                      document: indexDocument,
                                                      cleanedTextContentForClustering: readabilityResult.textContentForClustering,
                                                      isPinnedTab: false,
                                                      isBackwardNavigation: false)
                (currentId, parentId) = self.getIdAndParent(tabToIndex: tabIndexingInfo)
                guard let id = currentId else { return }
                self.addPage(id: id, tabId: tabToUnpin.id, parentId: parentId, value: tabIndexingInfo)
            }
        }
    }
    
    func removePinTab(tabToPin: BrowserTab) {
        if let pageId = tabToPin.pageId {
            self.removePage(pageId: pageId, tabId: tabToPin.id)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func addPage(id: UUID, tabId: UUID, parentId: UUID?, value: TabIndexingInfo?, newContent: String?) {
        var pageToAdd: Page?
        if let value = value {
            pageToAdd = Page(id: id, tabId: tabId, parentId: parentId, url: value.url, title: value.document.title, originalContent: value.cleanedTextContentForClustering)
            tabsInfo.append(value)
        } else if let newContent = newContent {
            pageToAdd = Page(id: id, tabId: tabId, parentId: nil, title: nil, cleanedContent: newContent)
            // TODO: Should we bother changing the content in tabsInfo?
        }
        isClustering = true
        var ranking: [UUID]?
        if self.sendRanking {
            ranking = self.ranker.clusteringRemovalSorted(links: self.clusteredPagesId.reduce([], +))
        }
        let replaceContent = newContent != nil
        guard let pageToAdd = pageToAdd else { return }

        clusteringBridge.add(textualItem: pageToAdd.toTextualItem(), ranking: ranking, replaceContent: replaceContent) { result in
            DispatchQueue.main.async {
                self.isClustering = false
            }
            switch result {
            case .failure(let error):
                self.isClustering = false
                if error as? LegacyClustering.AdditionError == .skippingToNextAddition {
                    Logger.shared.logInfo("Skipping to next addition before performing the final clustering")
                } else if error as? LegacyClustering.AdditionError == .abortingAdditionDuringClustering {
                    Logger.shared.logInfo("Aborting addition temporarility as to not hinder ongoing clustering process")
                } else {
                    Logger.shared.logError("Error while adding page to cluster for \(pageToAdd): \(error)", category: .clustering)
                }
            case .success(let result):
                self.updateClustersWithResult(result, changeCandidate: false)
                // After adding the second page, add notes from previous sessions
                let initialiseNotes = result.legacyFlag == .addNotes
                if initialiseNotes {
                    guard let collection = BeamData.shared.currentDocumentCollection else {
                        Logger.shared.logError("Error while adding page to cluster for \(pageToAdd): no current document collection", category: .clustering)
                        return
                    }
                    do {
                        let notes = try collection.fetch(filters: [.limit(10, offset: 0), .type(.note)], sortingKey: .updatedAt(false))
                            .compactMap({
                                BeamNote.fetch(id: $0.id)
                            })
                        for note in notes {
                            self.addNote(note: note, addToNextSummary: false)
                        }
                    } catch {
                        Logger.shared.logError("Error while adding page to cluster for \(pageToAdd): unable to fetch 10 documents", category: .clustering)
                    }
                }
            }
        }
    }

    func removePage(pageId: PageID, tabId: UUID) {
        clusteringBridge.removeTextualItem(textualItemUUID: pageId, textualItemTabId: tabId) { [weak self] result in
            guard let self = self, self.typeInUse == .smart else { return }
            switch result {
            case .failure(let error):
                Logger.shared.logError("\(error)", category: .clustering)
            case .success(let result):
                self.splitByType(groups: result.groups)
            }
        }
    }

}

// MARK: - Feedback Export
extension ClusteringManager {

    struct ClusteringFeedbackCorrectedPage: Hashable {
        let pageId: PageID
        let groupId: TabGroup.GroupID?
        let isGroupCreatedDuringFeedback: Bool
    }

    private func getExportInformationForId(_ id: UUID, link: Link?) -> InformationForId {
        var informationForId = self.clusteringBridge.getExportInformationForId(id: id)
        guard typeInUse == .smart, let link = link else {
            return informationForId
        }
        // While Smart Clustering supports informationForId, we fill it manually
        let tabInfo = tabsInfo.first { $0.document.id == id }
        informationForId.title = informationForId.title ?? link.title
        var cleanedContent = informationForId.cleanedContent ?? tabInfo?.cleanedTextContentForClustering.joined(separator: " ") ?? link.content
        cleanedContent = cleanedContent?.components(separatedBy: .whitespacesAndNewlines).joined(separator: " ")
        informationForId.cleanedContent = cleanedContent
        return informationForId
    }

    public func getOrphanedUrlGroups(urlGroups: [[UUID]], noteGroups: [[UUID]]) -> [[UUID]] {
        return zip(urlGroups, noteGroups)
            .filter { _, noteGroup in return noteGroup.count == 0 } //not suggested via direct grouping
            .map { urlGroup, _ in return urlGroup }
    }

    public func addOrphanedUrlsFromCurrentSession(orphanedUrlManager: ClusteringOrphanedUrlManager) {
        let orphanedUrlGroups = getOrphanedUrlGroups(urlGroups: clusteredPagesId, noteGroups: clusteredNotesId)
        let savedAt = BeamDate.now
        for (id, group) in orphanedUrlGroups.enumerated() {
            for urlId in group {
                let link = LinkStore.linkFor(urlId)
                let url = link?.url
                let informationForId = self.getExportInformationForId(urlId, link: link)
                orphanedUrlManager.addTemporarily(orphanedUrl: ClusteringExportOrphanedURL(sessionId: sessionId, url: url, groupId: id, navigationGroupId: self.findPageGroupForID(pageId: urlId, pageGroups: self.navigationBasedPageGroups), savedAt: savedAt, title: informationForId.title, cleanedContent: informationForId.cleanedContent, entities: informationForId.entitiesInText, entitiesInTitle: informationForId.entitiesInTitle, language: informationForId.language))
            }
        }
    }

    public func saveOrphanedUrlsAtSessionClose(orphanedUrlManager: ClusteringOrphanedUrlManager) {
        let orphanedUrlGroups = getOrphanedUrlGroups(urlGroups: clusteredPagesId, noteGroups: clusteredNotesId)
        let savedAt = BeamDate.now
        for (id, group) in orphanedUrlGroups.enumerated() {
            for urlId in group {
                let link = LinkStore.linkFor(urlId)
                let url = link?.url
                let informationForId = self.getExportInformationForId(urlId, link: link)
                orphanedUrlManager.add(orphanedUrl: ClusteringExportOrphanedURL(sessionId: sessionId, url: url, groupId: id, navigationGroupId: self.findPageGroupForID(pageId: urlId, pageGroups: self.navigationBasedPageGroups), savedAt: savedAt, title: informationForId.title, cleanedContent: informationForId.cleanedContent, entities: informationForId.entitiesInText, entitiesInTitle: informationForId.entitiesInTitle, language: informationForId.language))
            }
        }
        orphanedUrlManager.save()
    }

    /// - Parameters:
    ///   - sessionExporter: TBD
    ///   - to: local URL to save the file
    ///   - allPages: opened tab pages.
    ///   - initialBuiltGroups: The initial grouping when opening the feedback window. Before any change.
    ///   - correctedPages: The changes suggested by the user in the feedback window.
    public func exportSession(sessionExporter: ClusteringSessionExporter, to: URL?, allPages: [PageID],
                              initialBuiltGroups: [PageID: TabGroup.GroupID],
                              correctedPages: [ClusteringFeedbackCorrectedPage]?) {
        for pageId in allPages {
            let groupOffsetInClustering: Int? = self.clusteredPagesId.firstIndex(where: { $0.contains(pageId) })

//            We don't need clustered notes for now, we would need a way to match them properly
//            let notesInGroup = self.clusteredNotesId[groupOffsetInClustering]
//            for noteId in notesInGroup {
//                let informationForId = self.getExportInformationForId(noteId, link: nil)
//                let exportObject = ClusteringExportAnyURL(noteId: noteId, group: group, threshold: clusteringBridge.threshold, informationForId: informationForId)
//                sessionExporter.add(anyUrl: exportObject)
//            }

            let link = LinkStore.linkFor(pageId)
            let url = link?.url
            let informationForId = self.getExportInformationForId(pageId, link: link)
            let isOpenAtExport = self.openBrowsing.allOpenBrowsingPages.contains(pageId)
            let currentGroupId = initialBuiltGroups[pageId]
            let correctedValue = correctedPages?.first { $0.pageId == pageId }
            // TODO: if group is 1 object only now, correct to nil.
            // if group wasn't correct we put the original value in there.
            let correctionGroupId = correctedValue != nil ? correctedValue?.groupId : currentGroupId
            let navigationGroup = self.findPageGroupForID(pageId: pageId, pageGroups: self.navigationBasedPageGroups)
            let isGroupCreatedDuringFeedback = correctedValue?.isGroupCreatedDuringFeedback ?? false

            let exportObject = ClusteringExportAnyURL(pageId: pageId, url: url, groupOffsetInClustering: groupOffsetInClustering,
                                                      navigationGroup: navigationGroup, currentGroupId: currentGroupId, correctionGroupId: correctionGroupId,
                                                      isGroupCreatedDuringFeedback: isGroupCreatedDuringFeedback,
                                                      threshold: clusteringBridge.threshold, isOpenAtExport: isOpenAtExport, informationForId: informationForId)
            sessionExporter.add(anyUrl: exportObject)
        }

        let pathUrl: URL = to ?? URL(fileURLWithPath: NSTemporaryDirectory())
        sessionExporter.export(to: pathUrl, sessionId: self.sessionId, keepFile: (to != nil))
        sessionExporter.urls = [ClusteringExportAnyURL]()
    }
}

private extension ClusteringExportAnyURL {
    init(noteId: UUID, groupOffsetInClustering: Int?, threshold: Float?, informationForId: Clustering.InformationForId) {
        let note = BeamNote.fetch(id: noteId)
        self.init(noteName: note?.title, groupOffsetInClustering: groupOffsetInClustering, title: informationForId.title,
                  cleanedContent: informationForId.cleanedContent, entities: informationForId.entitiesInText,
                  entitiesInTitle: informationForId.entitiesInTitle,
                  language: informationForId.language, threshold: threshold, id: noteId)
    }

    init(pageId: UUID, url: String?, groupOffsetInClustering: Int?,
         navigationGroup: Int?, currentGroupId: UUID?, correctionGroupId: UUID?,
         isGroupCreatedDuringFeedback: Bool,
         threshold: Float?, isOpenAtExport: Bool,
         informationForId: Clustering.InformationForId) {

        self.init(url: url, groupOffsetInClustering: groupOffsetInClustering,
                  navigationGroupId: navigationGroup, tabColouringGroupId: currentGroupId, userCorrectionGroupId: correctionGroupId,
                  isGroupCreatedDuringFeedback: isGroupCreatedDuringFeedback,
                  title: informationForId.title, cleanedContent: informationForId.cleanedContent,
                  entities: informationForId.entitiesInText, entitiesInTitle: informationForId.entitiesInTitle,
                  language: informationForId.language, threshold: threshold, isOpenAtExport: isOpenAtExport, id: pageId, parentId: informationForId.parentId)
    }
}
