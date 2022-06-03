//
//  BrowserTabsManager.swift
//  Beam
//
//  Created by Remi Santos on 30/04/2021.
//
// swiftlint:disable file_length

import Foundation
import Combine
import SwiftSoup
import BeamCore

protocol BrowserTabsManagerDelegate: AnyObject {

    func areTabsVisible(for manager: BrowserTabsManager) -> Bool

    func tabsManagerDidUpdateTabs(_ tabs: [BrowserTab])
    func tabsManagerDidChangeCurrentTab(_ currentTab: BrowserTab?, previousTab: BrowserTab?)
    func tabsManagerBrowsingHistoryChanged(canGoBack: Bool, canGoForward: Bool)
}

class BrowserTabsManager: ObservableObject {

    weak var delegate: BrowserTabsManagerDelegate?

    private var currentTabScope = Set<AnyCancellable>()
    private var dataScope = Set<AnyCancellable>()
    private var tabsAreVisible: Bool {
        self.delegate?.areTabsVisible(for: self) == true
    }

    var browserTabManagerId = UUID()
    private var data: BeamData
    private weak var state: BeamState?
    private var pauseListItemsUpdate = false
    @Published public var tabs: [BrowserTab] = [] {
        didSet {
            self.delegate?.tabsManagerDidUpdateTabs(tabs)

            if let state = state, !state.isIncognito {
                self.updateClusteringOpenPages()
            }
            if !pauseListItemsUpdate {
                updateListItems()
            }
        }
    }
    /// Only the tabs that are displayed, excluding the ones in collapsed group for exemple.
    @Published private var visibleTabs: [BrowserTab] = []

    /// Actual visual representation of the items in the TabsListView, hiding collapsed tabs and adding group capsules.
    /// **This should be used only by the TabsListView.**
    ///
    /// Every other part of the app should interact only with `tabs` and tab indexes
    @Published public private(set) var listItems: TabsListItemsSections = .init()

    private var tabPinSuggester = TabPinSuggester(storage: DomainPath0TreeStatsStorage())

    /// Dictionary of `key`: BrowserTab.id, `value`: Group to which this tab belongs
    @Published private(set) var tabsClusteringGroups = [UUID: TabClusteringGroup]() {
        didSet {
            guard tabsClusteringGroups != oldValue else { return }
            cleanForcedGroups()
            guard !pauseListItemsUpdate else { return }
            updateListItems()
        }
    }
    /// We collapsed only the tabs visible when collapsing a group.
    /// If a tab is added to the group while it is collapsed, it will still be displayed.
    private var collapsedTabsInGroup = [TabClusteringGroup.GroupID: [UUID]]()

    /// Groups of tabs by interactions, to help know where to insert new tabs. *Not related to Clustering*
    private var tabsNeighborhoods: [UUID: [UUID]] = [:]

    @Published var currentTab: BrowserTab? {
        didSet {
            if tabsAreVisible {
                oldValue?.switchToOtherTab()
                currentTab?.tabDidAppear(withState: state)
            }

            self.updateCurrentTabObservers()
            self.delegate?.tabsManagerDidChangeCurrentTab(currentTab, previousTab: oldValue)
        }
    }
    @Published var currentTabUIFrame: CGRect?

    init(with data: BeamData, state: BeamState) {
        self.data = data
        self.state = state
        tabs.append(contentsOf: data.pinnedTabs)
        setupPinnedTabObserver()
        currentTab = tabs.first
        setupTabsClustering()
    }

    private var isModifyingPinnedTabs = false
    private func setupPinnedTabObserver() {
        data.$pinnedTabs
            .scan(([], [])) { ($0.1, $1) }
            .sink { [weak self] (previousPinnedTab, newPinnedTabs) in
                guard self?.isModifyingPinnedTabs == false else { return }
                guard previousPinnedTab != newPinnedTabs else { return }
                // receiving updated pinned tabs from another window
                let previousTabs = self?.tabs
                var tabs = previousTabs ?? []
                let previousIds = previousPinnedTab.map { $0.id }
                let statePinnedTabs = tabs.filter { $0.isPinned || previousIds.contains($0.id) }
                guard statePinnedTabs != newPinnedTabs else { return }
                tabs.removeAll { previousIds.contains($0.id) }
                tabs.insert(contentsOf: newPinnedTabs, at: 0)
                self?.tabs = tabs
                self?.changeCurrentTabIfNotVisible(previousTabsList: previousTabs)
        }.store(in: &dataScope)
    }

    private func updateCurrentTabObservers() {
        currentTabScope.removeAll()
        currentTab?.$canGoBack.receive(on: DispatchQueue.main).sink { [unowned self]  v in
            guard let tab = self.currentTab else { return }
            self.delegate?.tabsManagerBrowsingHistoryChanged(canGoBack: v, canGoForward: tab.canGoForward)
        }.store(in: &currentTabScope)
        currentTab?.$canGoForward.receive(on: DispatchQueue.main).sink { [unowned self] v in
            guard let tab = self.currentTab else { return }
            self.delegate?.tabsManagerBrowsingHistoryChanged(canGoBack: tab.canGoBack, canGoForward: v)
        }.store(in: &currentTabScope)
        currentTab?.$title.receive(on: DispatchQueue.main).sink { [unowned self] _ in
            self.state?.updateWindowTitle()
        }.store(in: &currentTabScope)
    }

    private func updateListItems() {
        var sections = TabsListItemsSections()
        let groups = tabsClusteringGroups
        var previousGroup: TabClusteringGroup?
        var alreadyAddedGroups: [UUID: Bool] = [:]
        var visibleTabs: [BrowserTab] = []
        tabs.forEach { tab in
            let forcedGroup = Self.forcedTabsInGroup[tab.id]
            let forcedOutOfGroup = Self.forcedTabsOutOfGroup[tab.id]
            let suggestedGroup = groups[tab.id]

            var currentGroup: TabClusteringGroup?
            if forcedGroup != nil {
                currentGroup = forcedGroup
            } else if forcedOutOfGroup == nil && suggestedGroup != nil {
                currentGroup = suggestedGroup
            }

            if tab.isPinned {
                let tabItem = TabsListItem(tab: tab, group: nil)
                sections.allItems.append(tabItem)
                sections.pinnedItems.append(tabItem)
                visibleTabs.append(tab)
            } else {
                let tabItem = TabsListItem(tab: tab, group: currentGroup)
                if let currentGroup = currentGroup, currentGroup != previousGroup && alreadyAddedGroups[currentGroup.id] != true {
                    alreadyAddedGroups[currentGroup.id] = true
                    let groupItem = TabsListItem(group: currentGroup)
                    sections.allItems.append(groupItem)
                    sections.unpinnedItems.append(groupItem)
                }
                previousGroup = currentGroup
                if currentGroup?.collapsed != true || collapsedTabsInGroup[currentGroup?.id ?? UUID()]?.contains(tab.id) != true {
                    sections.unpinnedItems.append(tabItem)
                    visibleTabs.append(tab)
                    sections.allItems.append(tabItem)
                }
            }
        }
        self.visibleTabs = visibleTabs
        self.listItems = sections
    }

    private var indexForNewTabInNeighborhood: Int? {
        guard let currentTabNeighborhood = currentTabNeighborhoodValue,
              let currentTabIndex = tabs.firstIndex(where: {$0.id == currentTab?.id}) else { return nil }
        if let lastTabIndex = tabs.firstIndex(where: {$0.id == currentTabNeighborhood.last}), lastTabIndex > currentTabIndex {
            return lastTabIndex + 1
        } else {
            return currentTabIndex + 1
        }
    }

    private func addNewTab(_ tab: BrowserTab, setCurrent: Bool = true, withURLRequest request: URLRequest? = nil, at index: Int? = nil) {
        if let request = request, request.url != nil {
            tab.load(request: request)
        }
        if let tabIndex = index, tabs.count > tabIndex {
            tabs.insert(tab, at: tabIndex)
        } else {
            tabs.append(tab)
        }
        if setCurrent || currentTab == nil {
            currentTab = tab
        }
        data.sessionLinkRanker.addTree(tree: tab.browsingTree)
    }

    private func changeCurrentTabIfNotVisible(previousTabsList: [BrowserTab]?) {
        guard let currentTab = currentTab, !visibleTabs.contains(currentTab) else { return }
        let index = previousTabsList?.firstIndex(of: currentTab) ?? 0
        // current tab is not visible anymore, select the next one.
        setCurrentTab(at: index)
    }
}

// MARK: - Public methods
extension BrowserTabsManager {

    func updateTabsForStateModeChange(_ newMode: Mode, previousMode: Mode) {
        guard newMode != previousMode else { return }
        if newMode == .web {
            currentTab?.tabDidAppear(withState: state)
        } else if previousMode == .web {
            switch newMode {
            case .note:
                currentTab?.switchToCard()
            case .today:
                currentTab?.switchToJournal()
            default:
                break
            }
        }
    }

    /// This is now the only entry point to add a tab
    func addNewTabAndNeighborhood(_ tab: BrowserTab, setCurrent: Bool = true, withURLRequest request: URLRequest? = nil, at tabIndex: Int? = nil) {
        if tabIndex == nil {
            addNewTab(tab, setCurrent: setCurrent, withURLRequest: request, at: indexForNewTabInNeighborhood)
        } else {
            addNewTab(tab, setCurrent: setCurrent, withURLRequest: request, at: tabIndex)
        }

        guard !tab.isPinned else { return }
        if let currentTabNeighborhoodKey = currentTabNeighborhoodKey, (request?.url != nil || tab.preloadUrl != nil) {
            tabsNeighborhoods[currentTabNeighborhoodKey]?.append(tab.id)
        } else {
            createNewNeighborhood(for: tab.id)
        }
    }

    func showNextTab() {
        guard let tab = currentTab, let i = visibleTabs.firstIndex(of: tab) else { return }
        let index = (i + 1) % visibleTabs.count
        currentTab = visibleTabs[index]
    }

    func showPreviousTab() {
        guard let tab = currentTab, let i = visibleTabs.firstIndex(of: tab) else { return }
        let index = i - 1 < 0 ? visibleTabs.count - 1 : i - 1
        currentTab = visibleTabs[index]
    }

    func setCurrentTab(at index: Int) {
        var index = index
        guard var tab = index < tabs.count ? tabs[index] : tabs.last else { return }
        while !visibleTabs.contains(tab) && index < tabs.count-1 {
            index += 1
            tab = tabs[index]
        }
        if index == tabs.count {
            guard let firstTab = visibleTabs.first else { return }
            tab = firstTab
        }
        currentTab = tab
    }

    func setCurrentTab(_ tab: BrowserTab?) {
        currentTab = tab
    }

    func reloadCurrentTab() {
        currentTab?.reload()
    }

    func stopLoadingCurrentTab() {
        currentTab?.stopLoad()
    }

    func resetFirstResponderAfterClosingTab() {
        // This make sure any webview is not retained by the first responder chain
        let window = AppDelegate.main.window
        if window?.firstResponder is BeamWebView {
            _ = window?.makeFirstResponder(nil)
        }
        if let currentTab = currentTab {
            DispatchQueue.main.async {
                currentTab.webView.window?.makeFirstResponder(currentTab.webView)
            }
        }
    }

    func openedTab(for url: URL) -> BrowserTab? {
        tabs.first { $0.url?.absoluteString == url.absoluteString }
    }

    private func updateIsPinned(for tab: BrowserTab, isPinned: Bool) {
        isModifyingPinnedTabs = true
        defer { isModifyingPinnedTabs = false }
        tab.isPinned = isPinned
        tabs.sort { a, b in
            a.isPinned && !b.isPinned
        }
        let allPinnedTabs = tabs.filter { $0.isPinned }
        data.savePinnedTabs(allPinnedTabs)
        self.objectWillChange.send()
    }

    func pinTab(_ tabToPin: BrowserTab) {
        tabPinSuggester.hasPinned()
        tabToPin.pin()
        updateIsPinned(for: tabToPin, isPinned: true)
        removeFromTabNeighborhood(tabId: tabToPin.id)
    }

    func unpinTab(_ tabToUnpin: BrowserTab) {
        tabToUnpin.unPin()
        updateIsPinned(for: tabToUnpin, isPinned: false)
        createNewNeighborhood(for: tabToUnpin.id)
    }

    func tabIndex(forListIndex listIndex: Int) -> Int? {
        guard listIndex < listItems.allItems.count, let tab = listItems.allItems[listIndex].tab else { return nil }
        return tabs.firstIndex(of: tab)
    }

    func moveListItem(atListIndex: Int, toListIndex: Int, changeGroup destinationGroup: TabClusteringGroup?) {

        guard atListIndex < listItems.allItems.count && toListIndex < listItems.allItems.count else { return }
        let movedItem = listItems.allItems[atListIndex]
        guard let tab = movedItem.tab, let atIndexInTabs = tabs.firstIndex(of: tab) else { return }

        if atListIndex != toListIndex {
            var toIndexInTabs = tabs.count - 1
            for i in toListIndex..<listItems.allItems.count {
                if let tabIndex = tabIndex(forListIndex: i) {
                    toIndexInTabs = tabIndex
                    if i > toListIndex && toListIndex > atListIndex {
                        toIndexInTabs -= 1
                    }
                    break
                }
            }
            if atIndexInTabs != toIndexInTabs {
                var tabs = tabs
                tabs.remove(at: atIndexInTabs)
                tabs.insert(tab, at: toIndexInTabs)
                self.tabs = tabs
            }
        }
        if destinationGroup != movedItem.group {
            moveTabToGroup(tab.id, group: destinationGroup)
        }
    }

    public func removeTab(tabId: UUID, suggestedNextCurrentTab: BrowserTab?) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        tabs.remove(at: index)
        let nextTabIdFromNeighborhood = removeFromTabNeighborhood(tabId: tabId)
        let nextTabIndex = min(index, tabs.count - 1)

        if currentTab?.id == tabId {
            var newCurrentTab: BrowserTab?
            if let suggestedNextCurrentTab = suggestedNextCurrentTab, nextTabIdFromNeighborhood == nil {
                newCurrentTab = suggestedNextCurrentTab
            } else if let nextTabIdFromNeighborhood = nextTabIdFromNeighborhood {
                newCurrentTab = tabs.first(where: {$0.id == nextTabIdFromNeighborhood})
            } else if nextTabIndex >= 0 {
                newCurrentTab = tabs[nextTabIndex]
            }
            setCurrentTab(newCurrentTab)
        }
    }
}

// MARK: - Tabs Interactions Neighborhoods
extension BrowserTabsManager {

    private var currentTabNeighborhoodValue: [UUID]? {
        guard let currentTabId = self.currentTab?.id, tabsNeighborhoods[currentTabId] != nil else {
            return tabsNeighborhoods.first(where: { $1.contains(where: { $0 == currentTab?.id }) })?.value
        }
        return tabsNeighborhoods[currentTabId]
    }

    public var currentTabNeighborhoodKey: UUID? {
        guard let currentTabId = self.currentTab?.id, tabsNeighborhoods[currentTabId] != nil else {
            return tabsNeighborhoods.first(where: { $1.contains(where: { $0 == currentTab?.id }) })?.key
        }
        return currentTabId
    }

    public func createNewNeighborhood(for tabId: UUID, with tabs: [UUID] = []) {
        tabsNeighborhoods[tabId] = tabs
    }

    /// Remove the TabId from the Neighborhood and return the next TabId to show
    @discardableResult
    public func removeFromTabNeighborhood(tabId: UUID) -> UUID? {
        guard let neighborhoodKey = currentTabNeighborhoodKey else { return nil }
        if tabId == neighborhoodKey {
            guard var neighborhood = tabsNeighborhoods.removeValue(forKey: neighborhoodKey), !neighborhood.isEmpty else { return nil }
            let firstTabId = neighborhood.removeFirst()
            tabsNeighborhoods[firstTabId] = neighborhood
            return firstTabId
        } else {
            guard let index = tabsNeighborhoods[neighborhoodKey]?.firstIndex(of: tabId),
                  let tabNeighborhood = tabsNeighborhoods[neighborhoodKey] else { return nil }
            let nextTabToGo = nextTabToGo(from: index, in: tabNeighborhood)

            tabsNeighborhoods[neighborhoodKey]?.removeAll(where: {$0 == tabId})
            if let neighborhood = tabsNeighborhoods[neighborhoodKey], neighborhood.isEmpty {
                tabsNeighborhoods.removeValue(forKey: neighborhoodKey)
            }
            return nextTabToGo ?? neighborhoodKey
        }
    }

    private func nextTabToGo(from index: Int, in neighborhood: [UUID]) -> UUID? {
        let afterIdx = neighborhood.index(after: index)
        let beforeIdx = neighborhood.index(before: index)
        if afterIdx < neighborhood.count {
            return neighborhood[afterIdx]
        } else if beforeIdx < neighborhood.count && beforeIdx >= 0 {
            return neighborhood[beforeIdx]
        } else {
            return nil
        }
    }

}

// MARK: - Tab events
extension BrowserTabsManager {

    func tabDidFinishNavigating(_ tab: BrowserTab, url: URL) {

        if data.pinnedTabs.isEmpty && tabPinSuggester.isEligible(url: url) {
            Logger.shared.logInfo("Suggested url to pin \(url)", category: .tabPinSuggestion)
            // TODO: uncomment when pin tab call to action is implemented
            // tab.pinSuggest()
            // self.tabPinSuggester.hasSuggested(url: url)
        }
    }
}

// MARK: - Tabs Clustering
extension BrowserTabsManager {
    /// The UI might want to temporarily force a tab in or out a group, independently of the Clustering.
    /// Either for temporary UI states (opening a new tab in group). Or while we're waiting for Clustering to update.
    private static var forcedTabsInGroup = [UUID: TabClusteringGroup]()
    private static var forcedTabsOutOfGroup = [UUID: TabClusteringGroup]()

    private func setupTabsClustering() {
        data.clusteringManager.tabGroupingUpdater.$builtPagesGroups.sink { [weak self] pagesGroups in
            guard let self = self else { return }
            let tabsPerPageId = Dictionary(grouping: self.tabs, by: { $0.browsingTree.current.link })
            var tabsGroups = [UUID: TabClusteringGroup]()
            pagesGroups.forEach { (pageID, group) in
                tabsPerPageId[pageID]?.forEach { tab in
                    tabsGroups[tab.id] = group
                }
            }
            self.tabsClusteringGroups = tabsGroups
        }.store(in: &dataScope)
    }

    private func getGroup(_ groupID: TabClusteringGroup.GroupID) -> TabClusteringGroup? {
        tabsClusteringGroups.values.first { $0.id == groupID }
    }

    private func tabsIds(inGroup groupID: TabClusteringGroup.GroupID) -> [UUID] {
        tabsClusteringGroups.compactMap { (key: UUID, value: TabClusteringGroup) in
            return value.id == groupID ? key : nil
        }
    }

    private func tabs(inGroup groupID: TabClusteringGroup.GroupID) -> [BrowserTab] {
        let tabsIDs = tabsIds(inGroup: groupID)
        return tabs.filter { tabsIDs.contains($0.id) }
    }

    private func updateClusteringOpenPages() {
        var openTabs: [ClusteringManager.BrowsingTreeOpenInTab] = []
        for tab in tabs where !tab.isPinned {
            openTabs.append(ClusteringManager.BrowsingTreeOpenInTab(browsingTree: tab.browsingTree, browserTabManagerId: self.browserTabManagerId))
        }
        self.data.clusteringManager.openBrowsing.allOpenBrowsingTrees = (self.data.clusteringManager.openBrowsing.allOpenBrowsingTrees.filter { $0.browserTabManagerId != self.browserTabManagerId }) + openTabs
    }

    /// After receiving new groups, let's clean up the unnecessary forced group in/out
    private func cleanForcedGroups() {
        let clusteringGroups = tabsClusteringGroups
        Self.forcedTabsInGroup = Self.forcedTabsInGroup.filter { forcedIn in
            clusteringGroups[forcedIn.key] != forcedIn.value
        }
        Self.forcedTabsOutOfGroup = Self.forcedTabsOutOfGroup.filter { forcedOut in
            clusteringGroups[forcedOut.key] == forcedOut.value
        }
    }

    func renameGroup(_ groupID: TabClusteringGroup.GroupID, title: String) {
        getGroup(groupID)?.title = title
        updateListItems()
    }

    func changeGroupColor(_ groupID: TabClusteringGroup.GroupID, color: TabGroupingColor?) {
        getGroup(groupID)?.color = color
        updateListItems()
    }

    private func gatherTabsInGroupTogether(_ groupID: TabClusteringGroup.GroupID) {
        let tabsInGroup = tabsIds(inGroup: groupID)
        var tabsIndexToMove = IndexSet()
        tabs.enumerated().forEach { (index, tab) in
            if tabsInGroup.contains(tab.id) {
                tabsIndexToMove.insert(index)
            }
        }
        guard let firstIndexOfGroup = tabsIndexToMove.first else { return }
        tabs.move(fromOffsets: tabsIndexToMove, toOffset: firstIndexOfGroup)
    }

    func toggleGroupCollapse(_ groupID: TabClusteringGroup.GroupID) {
        guard let group = getGroup(groupID) else { return }
        group.collapsed.toggle()

        if group.collapsed {
            let tabsInGroup = tabsIds(inGroup: groupID)
            pauseListItemsUpdate = true
            defer { pauseListItemsUpdate = false }
            collapsedTabsInGroup[group.id] = tabsInGroup
            gatherTabsInGroupTogether(group.id)
            updateListItems()
            if let currentTab = currentTab, tabsInGroup.contains(currentTab.id) {
                changeCurrentTabIfNotVisible(previousTabsList: tabs)
            }
        } else {
            collapsedTabsInGroup.removeValue(forKey: group.id)
            updateListItems()
        }
    }

    func ungroupTabsInGroup(_ group: TabClusteringGroup) {
        pauseListItemsUpdate = true
        let tabsIDs = tabsIds(inGroup: group.id)
        let beWith: [ClusteringManager.PageID] = []
        let beApart: [ClusteringManager.PageID] = group.pageIDs
        let clusteringManager = state?.data.clusteringManager
        tabsIDs.forEach { tabID in
            Self.forcedTabsInGroup.removeValue(forKey: tabID)
            Self.forcedTabsOutOfGroup[tabID] = group
        }
        beApart.forEach { pageID in
            clusteringManager?.shouldBeWithAndApart(pageId: pageID, beWith: beWith, beApart: beApart)
        }
        updateListItems()
        pauseListItemsUpdate = false
    }

    func closeTabsInGroup(_ group: TabClusteringGroup) {
        let tabs = tabs(inGroup: group.id)
        guard let state = state else { return }
        state.cmdManager.beginGroup(with: "CloseTabsInGroup")
        state.closeTabs(tabs)
        state.cmdManager.endGroup(forceGroup: true)
    }

    func moveGroupToNewWindow(_ group: TabClusteringGroup) {
        let tabsIDs = tabsIds(inGroup: group.id)
        let tabs = tabs.filter { tabsIDs.contains($0.id) }
        tabsIDs.forEach { tabID in
            self.removeTab(tabId: tabID, suggestedNextCurrentTab: nil)
            Self.forcedTabsInGroup.removeValue(forKey: tabID)
            Self.forcedTabsOutOfGroup.removeValue(forKey: tabID)
        }
        AppDelegate.main.createWindow(withTabs: tabs, at: .zero)
    }

    func createNewTab(inGroup group: TabClusteringGroup) {
        pauseListItemsUpdate = true
        defer {
            pauseListItemsUpdate = false
        }
        guard let tab = state?.createEmptyTab(), let index = tabs.firstIndex(of: tab) else { return }
        if let firstItemOfThatGroup = listItems.allItems.firstIndex(where: { $0.group == group }) {
            // groups can be splitted, we want to insert in the first portion of that group
            if let lastItemOfThePortion = listItems.allItems.dropFirst(firstItemOfThatGroup).first(where: { $0.group != group }),
               let tabAfter = lastItemOfThePortion.tab, let insertIndex = tabs.firstIndex(of: tabAfter) {
                tabs.remove(at: index)
                tabs.insert(tab, at: insertIndex)
            }
        }

        Self.forcedTabsInGroup[tab.id] = group
        state?.startFocusOmnibox(fromTab: true)
        updateListItems()
    }

    func moveTabToGroup(_ tabID: UUID, group toGroup: TabClusteringGroup?) {
        guard let item = listItems.allItems.first(where: { $0.tab?.id == tabID }) else { return }
        guard let pageID = item.tab?.browsingTree.current.link else { return }
        let beWith: [ClusteringManager.PageID] = toGroup?.pageIDs ?? []
        let beApart: [ClusteringManager.PageID] = item.group?.pageIDs ?? []
        pauseListItemsUpdate = true
        if let toGroup = toGroup {
            Self.forcedTabsInGroup[tabID] = toGroup
            Self.forcedTabsOutOfGroup.removeValue(forKey: tabID)
        } else if let previousGroup = item.group {
            Self.forcedTabsOutOfGroup[tabID] = previousGroup
            Self.forcedTabsInGroup.removeValue(forKey: tabID)
        }
        state?.data.clusteringManager.shouldBeWithAndApart(pageId: pageID, beWith: beWith, beApart: beApart)
        // This assumes that clustering will give us new groups right away. It could be delayed so we need to force in and outs in the meantime.
        updateListItems()
        pauseListItemsUpdate = false
    }
}

// MARK: - Tests helpers
extension BrowserTabsManager {
    internal func _testSetTabsClusteringGroup(_ tabsClusteringGroups: [UUID: TabClusteringGroup]) {
        self.tabsClusteringGroups = tabsClusteringGroups
    }
}
