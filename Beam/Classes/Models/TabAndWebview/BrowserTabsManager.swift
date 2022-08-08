//
//  BrowserTabsManager.swift
//  Beam
//
//  Created by Remi Santos on 30/04/2021.
//

import Foundation
import Combine
import SwiftSoup
import BeamCore

protocol BrowserTabsManagerDelegate: AnyObject {

    func areTabsVisible(for manager: BrowserTabsManager) -> Bool

    func tabsManagerDidUpdateTabs(_ tabs: [BrowserTab])
    func tabsManagerDidChangeCurrentTab(_ currentTab: BrowserTab?, previousTab: BrowserTab?)
    func tabsManagerCurrentTabDidChangeDisplayInformation(_ currentTab: BrowserTab?)
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
                updateClusteringOpenPages()
                updateTabsClusteringGroupsAfterTabsChange(withTabs: tabs)
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

    /// Dictionary of `key`: BrowserTab.TabID, `value`: Group to which this tab belongs
    /// Only inside this TabsManager, aka only for the window it belongs to.
    @Published private var localTabsGroup = [BrowserTab.TabID: TabGroup]()

    /// We collapsed only the tabs visible when collapsing a group.
    /// If a tab is added to the group while it is collapsed, it will still be displayed.
    private var collapsedTabsInGroup = [TabGroup.GroupID: [BrowserTab.TabID]]()

    /// Groups of tabs by interactions, to help know where to insert new tabs. *Not related to Clustering*
    private var tabsNeighborhoods: [BrowserTab.TabID: [BrowserTab.TabID]] = [:]

    @Published private(set) var currentTab: BrowserTab? {
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
    @Published var isCurrentTabPlaying = false

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
            .scan(([], [])) { ($0.1.map({ $0.id }), $1) } // getting the previous pinned tabs ids to avoid leaks (BE-4882)
            .sink { [weak self] (previousPinnedTabsIds, newPinnedTabs) in
                guard self?.isModifyingPinnedTabs == false else { return }
                let newPinnedTabsIds = newPinnedTabs.map { $0.id }
                guard previousPinnedTabsIds != newPinnedTabsIds else { return }
                // receiving updated pinned tabs from another window
                let previousTabs = self?.tabs
                var tabs = previousTabs ?? []
                let statePinnedTabs = tabs.filter { $0.isPinned || previousPinnedTabsIds.contains($0.id) }
                guard statePinnedTabs != newPinnedTabs else { return }
                tabs.removeAll { previousPinnedTabsIds.contains($0.id) }
                tabs.insert(contentsOf: newPinnedTabs, at: 0)
                self?.tabs = tabs
                self?.changeCurrentTabIfNotVisible(previousTabsList: previousTabs)
        }.store(in: &dataScope)
    }

    private func updateCurrentTabObservers() {
        currentTabScope.removeAll()
        currentTab?.$canGoBack.receive(on: DispatchQueue.main).sink { [weak self]  v in
            guard let tab = self?.currentTab else { return }
            self?.delegate?.tabsManagerBrowsingHistoryChanged(canGoBack: v, canGoForward: tab.canGoForward)
        }.store(in: &currentTabScope)
        currentTab?.$canGoForward.receive(on: DispatchQueue.main).sink { [weak self] v in
            guard let tab = self?.currentTab else { return }
            self?.delegate?.tabsManagerBrowsingHistoryChanged(canGoBack: tab.canGoBack, canGoForward: v)
        }.store(in: &currentTabScope)
        currentTab?.$title.receive(on: DispatchQueue.main).removeDuplicates()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main).sink { [weak self] _ in
                self?.delegate?.tabsManagerCurrentTabDidChangeDisplayInformation(self?.currentTab)
        }.store(in: &currentTabScope)
        currentTab?.$url.receive(on: DispatchQueue.main).removeDuplicates()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main).sink { [weak self] _ in
                self?.delegate?.tabsManagerCurrentTabDidChangeDisplayInformation(self?.currentTab)
        }.store(in: &currentTabScope)
        currentTab?.$mediaPlayerController.removeDuplicates(by: { $0?.isPlaying == $1?.isPlaying }).dropFirst()
            .sink {  [unowned self] mediaController in
                self.isCurrentTabPlaying = mediaController?.isPlaying ?? false
        }.store(in: &currentTabScope)
    }

    private class ItemsSegment {
        var group: TabGroup?
        var tabs: [BrowserTab] = []
        var displayGroupCapsule = false
        var pinned = false
        init(pinned: Bool = false) {
            self.pinned = pinned
        }
    }
    private func updateListItems() {
        var sections = TabsListItemsSections()
        let groups = localTabsGroup
        var previousGroup: TabGroup?
        var alreadyAddedGroups: [UUID: Int] = [:]
        let pinnedSegment = ItemsSegment(pinned: true)
        var segments = [ItemsSegment]()

        // We first create segments of tabs, by group/kind.
        tabs.forEach { tab in
            if tab.isPinned {
                pinnedSegment.tabs.append(tab)
                return
            }

            // Get the suggested or manual group
            let forcedGroups = tabGroupingManager.forcedTabsGroup[tab.id]
            let suggestedGroup = groups[tab.id]
            var currentGroup: TabGroup?
            if forcedGroups?.inGroup != nil {
                currentGroup = forcedGroups?.inGroup
            } else if forcedGroups?.outOfGroup == nil, let suggestedGroup = suggestedGroup {
                currentGroup = suggestedGroup
            }

            let segment: ItemsSegment
            if let lastSegment = segments.last, currentGroup == previousGroup {
                segment = lastSegment
            } else {
                segment = ItemsSegment()
                segments.append(segment)
            }

            if let currentGroup = currentGroup {
                segment.group = currentGroup
                if currentGroup != previousGroup && alreadyAddedGroups[currentGroup.id] == nil {
                    segment.displayGroupCapsule = true
                }
                alreadyAddedGroups[currentGroup.id, default: 0] += 1
            }
            if currentGroup?.collapsed != true || collapsedTabsInGroup[currentGroup?.id ?? UUID()]?.contains(tab.id) != true {
                segment.tabs.append(tab)
            }
            previousGroup = currentGroup
        }

        // Then we compile them into actual list of items next to each other.
        var visibleTabs: [BrowserTab] = []
        let pinnedItems: [TabsListItem] = pinnedSegment.tabs.map {
            visibleTabs.append($0)
            return TabsListItem(tab: $0, group: nil)
        }
        let unpinnedItems = segments.reduce(into: [TabsListItem]()) { result, portion in
            var groupForTabs: TabGroup?
            if let group = portion.group {
                let tabsCountInThatGroup = alreadyAddedGroups[group.id] ?? group.pageIds.count
                let isForced = tabGroupingManager.forcedTabsGroup.contains { $0.value.inGroup == group }
                if group.shouldBePersisted || group.isLocked || tabsCountInThatGroup > 1 || isForced {
                    groupForTabs = group
                    if portion.displayGroupCapsule {
                        let item = TabsListItem(group: group, count: tabsCountInThatGroup)
                        result.append(item)
                    }
                }
            }
            let tabsItems: [TabsListItem] = portion.tabs.map {
                visibleTabs.append($0)
                return TabsListItem(tab: $0, group: groupForTabs)
            }
            result.append(contentsOf: tabsItems)
        }
        sections.pinnedItems = pinnedItems
        sections.unpinnedItems = unpinnedItems
        sections.allItems = pinnedItems + unpinnedItems
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
        if var tabIndex = index, tabIndex >= 0, tabs.count > tabIndex {
            if !tab.isPinned, tabIndex < tabs.count - 1, tabs[tabIndex].isPinned {
                // Adding inside pinned tabs is impossible, moving to first unpinned
                tabIndex = tabs.firstIndex { !$0.isPinned } ?? tabIndex
            }
            tabs.insert(tab, at: tabIndex)
        } else {
            tabs.append(tab)
        }
        if setCurrent || currentTab == nil {
            currentTab = tab
        }
        updateLocalTabsGroups(withTabs: tabs, pagesGroups: tabGroupingManager.builtPagesGroups)
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

        let at = tabIndex ?? indexForNewTabInNeighborhood
        addNewTab(tab, setCurrent: setCurrent, withURLRequest: request, at: at)

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

    /// selects the tab at the visual index in the list of visible tabs.
    func setCurrentTab(atAbsoluteIndex absoluteIndex: Int) {
        guard absoluteIndex < visibleTabs.count else {
            if !visibleTabs.isEmpty {
                setCurrentTab(visibleTabs.last)
            }
            return
        }
        let tab = visibleTabs[absoluteIndex]
        setCurrentTab(tab)
    }

    /// selects the tab at the index in the list of all tabs (including hidden tabs)
    func setCurrentTab(at index: Int) {
        var index = index
        guard tabs.count > 0, var tab = index < tabs.count ? tabs[index] : tabs.last else {
            Logger.shared.logError("Couldn't select a tab at index \(index)", category: .web)
            currentTab = nil
            return
        }
        guard !visibleTabs.isEmpty else { return }
        while !visibleTabs.contains(tab) && index < tabs.count-1 {
            index += 1
            tab = tabs[index]
        }
        if index == tabs.count - 1 && !visibleTabs.contains(tab) {
            tab = visibleTabs[0]
        }
        currentTab = tab
    }

    func setCurrentTab(_ tab: BrowserTab?) {
        if let tab = tab, !visibleTabs.contains(tab) {
            // tab is not in the visible ones, we need to select another one.
            Logger.shared.logError("Couldn't select tab '\(tab.title)'. It might be hidden.", category: .web)
            let index = tabs.firstIndex(of: tab) ?? 0
            setCurrentTab(at: index)
            return
        }
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

    func moveListItem(atListIndex: Int, toListIndex: Int, changeGroup destinationGroup: TabGroup?) {

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
            if !tab.isPinned && toListIndex < listItems.pinnedItems.count {
                pinTab(tab)
            } else if tab.isPinned && toListIndex >= listItems.pinnedItems.count {
                unpinTab(tab)
            }
        }
        if destinationGroup != movedItem.group {
            moveTabToGroup(tab.id, group: destinationGroup)
        } else if let destinationGroup = destinationGroup {
            tabGroupingManager.pageWasMovedInsideSameGroup(pageId: tab.pageId, group: destinationGroup)
        }
    }

    public func removeTab(tabId: BrowserTab.TabID, suggestedNextCurrentTab: BrowserTab? = nil) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        let tab = tabs[index]
        tabs.remove(at: index)
        let nextTabIdFromNeighborhood = removeFromTabNeighborhood(tabId: tabId)
        let nextTabIndex = min(index, tabs.count - 1)

        guard currentTab?.id == tabId else { return }
        var newCurrentTab: BrowserTab?

        if let suggestedNextCurrentTab = suggestedNextCurrentTab {
            if visibleTabs.contains(suggestedNextCurrentTab) {
                newCurrentTab = suggestedNextCurrentTab
            } else {
                Logger.shared.logError("Suggested new current tab is not visible", category: .web)
            }
        } else {

            // If the tab is in a group, stay in the group if possible:
            if let nextTabIdFromNeighborhood = nextTabIdFromNeighborhood {
                newCurrentTab = visibleTabs.first(where: { $0.id == nextTabIdFromNeighborhood })
            } else {
                switch tab.browsingTreeOrigin {
                case .browsingNode(_, _, _, let rootId):
                    // If user cmd+click from a tab we want to go back to this tab
                    newCurrentTab = visibleTabs.first(where: { !$0.isPinned && $0.browsingTree.rootId == rootId })
                case .searchBar(_, referringRootId: let referringRootId):
                    // If user cmd+T from a current tab we want to comeback to that origin tab
                    newCurrentTab = visibleTabs.first(where: { !$0.isPinned && $0.browsingTree.rootId == referringRootId })
                default:
                    break
                }
            }
        }
        if let newCurrentTab = newCurrentTab {
            setCurrentTab(newCurrentTab)
        } else {
            setCurrentTab(at: nextTabIndex)
        }
    }
}

// MARK: - Tabs Interactions Neighborhoods
extension BrowserTabsManager {

    private var currentTabNeighborhoodValue: [BrowserTab.TabID]? {
        guard let currentTabId = self.currentTab?.id, tabsNeighborhoods[currentTabId] != nil else {
            return tabsNeighborhoods.first(where: { $1.contains(where: { $0 == currentTab?.id }) })?.value
        }
        return tabsNeighborhoods[currentTabId]
    }

    public var currentTabNeighborhoodKey: BrowserTab.TabID? {
        guard let currentTabId = self.currentTab?.id, tabsNeighborhoods[currentTabId] != nil else {
            return tabsNeighborhoods.first(where: { $1.contains(where: { $0 == currentTab?.id }) })?.key
        }
        return currentTabId
    }

    public func createNewNeighborhood(for tabId: BrowserTab.TabID, with tabs: [BrowserTab.TabID] = []) {
        tabsNeighborhoods[tabId] = tabs
    }

    /// Remove the TabId from the Neighborhood and return the next TabId to show
    @discardableResult
    public func removeFromTabNeighborhood(tabId: BrowserTab.TabID) -> BrowserTab.TabID? {
        guard let neighborhoodKey = currentTabNeighborhoodKey else { return nil }
        if tabId == neighborhoodKey {
            guard var neighborhood = tabsNeighborhoods.removeValue(forKey: neighborhoodKey), !neighborhood.isEmpty else { return nil }
            let firstTabId = neighborhood.removeFirst()
            tabsNeighborhoods[firstTabId] = neighborhood
            return firstTabId
        } else {
            guard var tabNeighborhood = tabsNeighborhoods[neighborhoodKey],
                  let index = tabNeighborhood.firstIndex(of: tabId)
            else { return nil }
            tabNeighborhood.removeAll(where: {$0 == tabId})
            let nextTabToGo = nextTabToGo(from: index, in: tabNeighborhood)

            if tabNeighborhood.isEmpty {
                tabsNeighborhoods.removeValue(forKey: neighborhoodKey)
            } else {
                tabsNeighborhoods[neighborhoodKey] = tabNeighborhood
            }

            return nextTabToGo ?? neighborhoodKey
        }
    }

    private func nextTabToGo(from index: Int, in neighborhood: [BrowserTab.TabID]) -> BrowserTab.TabID? {
        let afterIdx = min(neighborhood.count - 1, index)
        guard afterIdx >= 0 else { return nil }
        return neighborhood[afterIdx]

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

    var tabGroupingManager: TabGroupingManager {
        data.tabGroupingManager
    }

    private func updateTabsClusteringGroupsAfterTabsChange(withTabs tabs: [BrowserTab]) {
        self.localTabsGroup = localTabsGroup.filter { (key, _) in
            guard let tab = tabs.first(where: { $0.id == key }) else { return false }
            return !tab.isPinned
        }
    }

    private func updateLocalTabsGroups(withTabs tabs: [BrowserTab], pagesGroups: [ClusteringManager.PageID: TabGroup]) {
        let tabsPerPageId = Dictionary(grouping: tabs, by: { $0.pageId })
        var tabsGroups = [BrowserTab.TabID: TabGroup]()
        pagesGroups.forEach { (pageId, group) in
            tabsPerPageId[pageId]?.forEach { tab in
                guard !tab.isPinned else { return }
                tabsGroups[tab.id] = group
            }
        }
        if localTabsGroup != tabsGroups {
            localTabsGroup = tabsGroups
            updateListItems()
        }
    }

    private func setupTabsClustering() {
        tabGroupingManager.$builtPagesGroups.receive(on: DispatchQueue.main).sink { [weak self] pagesGroups in
            guard let self = self else { return }
            self.updateLocalTabsGroups(withTabs: self.tabs, pagesGroups: pagesGroups)
        }.store(in: &dataScope)
    }

    private func tabsIds(inGroup group: TabGroup) -> [BrowserTab.TabID] {
        let clusteringTabs: [BrowserTab.TabID] = localTabsGroup.compactMap { (key: BrowserTab.TabID, value: TabGroup) in
            guard tabGroupingManager.forcedTabsGroup[key]?.outOfGroup != value else { return nil }
            return value.id == group.id ? key : nil
        }
        let forcedTabs = tabGroupingManager.forcedTabsGroup.filter { $0.value.inGroup?.id == group.id }.keys
        return clusteringTabs + forcedTabs
    }

    private func tabs(inGroup group: TabGroup) -> [BrowserTab] {
        let tabsIDs = tabsIds(inGroup: group)
        return tabs.filter { tabsIDs.contains($0.id) }
    }

    func group(for tab: BrowserTab) -> TabGroup? {
        localTabsGroup[tab.id]
    }

    func describingTitle(forGroup group: TabGroup, truncated: Bool = false) -> String {
        let tabs = tabs(inGroup: group)
        return TabGroupingStoreManager.suggestedDefaultTitle(for: group, withTabs: tabs, truncated: truncated)
    }

    private func updateClusteringOpenPages() {
        var openTabs: [ClusteringManager.BrowsingTreeOpenInTab] = []
        for tab in tabs where !tab.isPinned {
            openTabs.append(ClusteringManager.BrowsingTreeOpenInTab(browsingTree: tab.browsingTree, browserTabManagerId: self.browserTabManagerId))
        }
        data.clusteringManager.openBrowsing.allOpenBrowsingTrees = (data.clusteringManager.openBrowsing.allOpenBrowsingTrees.filter { $0.browserTabManagerId != self.browserTabManagerId }) + openTabs
    }

    func renameGroup(_ group: TabGroup, title: String) {
        tabGroupingManager.renameGroup(group, title: title)
        updateListItems()
    }

    func changeGroupColor(_ group: TabGroup, color: TabGroupingColor) {
        tabGroupingManager.changeGroupColor(group, color: color)
        updateListItems()
    }

    private func gatherTabsInGroupTogether(_ group: TabGroup) {
        let tabsInGroup = tabsIds(inGroup: group)
        var tabsIndexToMove = IndexSet()
        tabs.enumerated().forEach { (index, tab) in
            if tabsInGroup.contains(tab.id) {
                tabsIndexToMove.insert(index)
            }
        }
        guard let firstIndexOfGroup = tabsIndexToMove.first else { return }
        tabs.move(fromOffsets: tabsIndexToMove, toOffset: firstIndexOfGroup)
    }

    func toggleGroupCollapse(_ group: TabGroup) {
        tabGroupingManager.toggleCollapse(group)

        if group.collapsed {
            groupTabsInGroup(group)
        } else {
            collapsedTabsInGroup.removeValue(forKey: group.id)
            updateListItems()
        }
    }

    func groupTabsInGroup(_ group: TabGroup) {
        let tabsInGroup = tabsIds(inGroup: group)
        pauseListItemsUpdate = true
        defer { pauseListItemsUpdate = false }
        collapsedTabsInGroup[group.id] = tabsInGroup
        gatherTabsInGroupTogether(group)
        updateListItems()
        if let currentTab = currentTab, tabsInGroup.contains(currentTab.id) {
            changeCurrentTabIfNotVisible(previousTabsList: tabs)
        }
    }

    func ungroupTabsInGroup(_ group: TabGroup) {
        pauseListItemsUpdate = true
        let tabs = tabs(inGroup: group)
        let beWith: [ClusteringManager.PageID] = []
        let beApart: [ClusteringManager.PageID] = group.pageIds
        let clusteringManager = state?.data.clusteringManager
        tabs.forEach { tab in
            tabGroupingManager.moveTab(tab, inGroup: nil, outOfGroup: group)
        }
        beApart.forEach { pageId in
            clusteringManager?.shouldBeWithAndApart(pageId: pageId, beWith: beWith, beApart: beApart)
        }
        tabGroupingManager.ungroup(group)
        updateListItems()
        pauseListItemsUpdate = false
    }

    func closeTabsInGroup(_ group: TabGroup) {
        let tabs = tabs(inGroup: group)
        state?.closeTabs(tabs, groupName: "CloseTabsInGroup")
    }

    func moveGroupToNewWindow(_ group: TabGroup) {
        let tabsIDs = tabsIds(inGroup: group)
        let tabs = tabs.filter { tabsIDs.contains($0.id) }
        tabsIDs.forEach { tabID in
            self.removeTab(tabId: tabID, suggestedNextCurrentTab: nil)
        }
        AppDelegate.main.createWindow(withTabs: tabs, at: .zero)
    }

    func createNewTab(inGroup group: TabGroup) {
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

        tabGroupingManager.moveTab(tab, inGroup: group)

        state?.startFocusOmnibox(fromTab: true)
        updateListItems()
    }

    func createNewGroup(withTabs tabs: [BrowserTab]) {
        let group = tabGroupingManager.createNewGroup()
        tabs.forEach {
            moveTabToGroup($0.id, group: group)
        }
    }

    func moveTabToGroup(_ tabId: BrowserTab.TabID, group toGroup: TabGroup?, reorderInList: Bool = false) {
        guard let item = listItems.allItems.first(where: { $0.tab?.id == tabId }), let tab = item.tab else { return }
        guard let pageId = item.tab?.pageId else { return }
        let beWith: [ClusteringManager.PageID] = toGroup?.pageIds ?? []
        let beApart: [ClusteringManager.PageID] = item.group?.pageIds ?? []
        pauseListItemsUpdate = true

        tabGroupingManager.moveTab(tab, inGroup: toGroup, outOfGroup: item.group)
        tabGroupingManager.pageWasMoved(pageId: pageId, fromGroup: item.group, toGroup: toGroup)

        state?.data.clusteringManager.shouldBeWithAndApart(pageId: pageId, beWith: beWith, beApart: beApart)
        if let toGroup = toGroup, reorderInList {
            gatherTabsInGroupTogether(toGroup)
        }
        updateListItems()
        pauseListItemsUpdate = false
    }

    func reopenGroup(_ group: TabGroup, withTabs tabs: [BrowserTab]) {
        pauseListItemsUpdate = true
        let group = tabGroupingManager.existingGroup(forGroupID: group.id) ?? group
        tabs.forEach { tab in
            tabGroupingManager.moveTab(tab, inGroup: group)
        }
        updateListItems()
        pauseListItemsUpdate = false
    }
}

extension BrowserTab {
    var pageId: ClusteringManager.PageID {
        browsingTree.current.link
    }
}

// MARK: - Tests helpers
extension BrowserTabsManager {
    internal func _testSetLocalTabsGroups(_ tabsGroups: [BrowserTab.TabID: TabGroup]) {
        self.localTabsGroup = tabsGroups
        self.updateListItems()
    }
}
