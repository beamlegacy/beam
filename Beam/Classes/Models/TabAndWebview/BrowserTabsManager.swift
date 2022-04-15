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
    func tabsManagerBrowsingHistoryChanged(canGoBack: Bool, canGoForward: Bool)
}

class BrowserTabsManager: ObservableObject {

    weak var delegate: BrowserTabsManagerDelegate?

    private var tabScope = Set<AnyCancellable>()
    private var dataScope = Set<AnyCancellable>()
    private var tabsAreVisible: Bool {
        self.delegate?.areTabsVisible(for: self) == true
    }

    var browserTabManagerId = UUID()
    private var data: BeamData
    private weak var state: BeamState?
    @Published public var tabs: [BrowserTab] = [] {
        didSet {
            self.delegate?.tabsManagerDidUpdateTabs(tabs)

            guard let state = state, !state.isIncognito else { return }
            self.autoSave()
            self.updateClusteringOpenPages()
        }
    }
    private var tabPinSuggester = TabPinSuggester(storage: DomainPath0TreeStatsStorage())

    /// Dictionary of `key`: BrowserTab.id, `value`: Group to which this tab belongs
    @Published private(set) var tabsClusteringGroups = [UUID: TabClusteringGroup]()

    /// Groups of tabs by interactions, to help know where to insert new tabs. *Not related to Clustering*
    private var tabsGroup: [UUID: [UUID]] = [:]

    public var tabHistory: [Data] = []
    private weak var latestCurrentTab: BrowsingTree?
    @Published var currentTab: BrowserTab? {
        didSet {
            if tabsAreVisible {
                oldValue?.switchToOtherTab()
                currentTab?.tabDidAppear(withState: state)
            }

            self.updateCurrentTabObservers()
            self.delegate?.tabsManagerDidChangeCurrentTab(currentTab, previousTab: oldValue)
            self.autoSave()
        }
    }
    @Published var currentTabUIFrame: CGRect?

    init(with data: BeamData, state: BeamState) {
        self.data = data
        self.state = state
        tabs.append(contentsOf: data.pinnedTabs)
        setupPinnedTabObserver()
        currentTab = tabs.first
        setupTabsColoring()
    }

    private var isModifyingPinnedTabs = false
    private func setupPinnedTabObserver() {
        data.$pinnedTabs
            .dropFirst()
            .scan(([], [])) { ($0.1, $1) }
            .sink { [weak self] (previousPinnedTab, newPinnedTabs) in
                guard self?.isModifyingPinnedTabs == false else { return }
                // receiving updated pinned tabs from another window
                var tabs = self?.tabs ?? []
                let previousIds = previousPinnedTab.map { $0.id }
                let statePinnedTabs = tabs.filter { $0.isPinned || previousIds.contains($0.id) }
                guard statePinnedTabs != newPinnedTabs else { return }
                tabs.removeAll { previousIds.contains($0.id) }
                tabs.insert(contentsOf: newPinnedTabs, at: 0)
                self?.tabs = tabs
        }.store(in: &dataScope)
    }

    private func updateCurrentTabObservers() {
        tabScope.removeAll()
        currentTab?.$canGoBack.sink { [unowned self]  v in
            guard let tab = self.currentTab else { return }
            self.delegate?.tabsManagerBrowsingHistoryChanged(canGoBack: v, canGoForward: tab.canGoForward)
            self.autoSave()
        }.store(in: &tabScope)
        currentTab?.$canGoForward.sink { [unowned self]  v in
            guard let tab = self.currentTab else { return }
            self.delegate?.tabsManagerBrowsingHistoryChanged(canGoBack: tab.canGoBack, canGoForward: v)
            self.autoSave()
        }.store(in: &tabScope)
    }

    private func updateClusteringOpenPages() {
        var openTabs: [ClusteringManager.BrowsingTreeOpenInTab] = []
        for tab in tabs where !tab.isPinned {
            openTabs.append(ClusteringManager.BrowsingTreeOpenInTab(browsingTree: tab.browsingTree, browserTabManagerId: self.browserTabManagerId))
        }
        self.data.clusteringManager.openBrowsing.allOpenBrowsingTrees = (self.data.clusteringManager.openBrowsing.allOpenBrowsingTrees.filter { $0.browserTabManagerId != self.browserTabManagerId }) + openTabs
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

    private var indexForNewTabInGroup: Int? {
        guard let currentTabGroupValue = currentTabGroupValue,
              let currentTabIndex = tabs.firstIndex(where: {$0.id == currentTab?.id}) else { return nil }
        if let lastTabIndex = tabs.firstIndex(where: {$0.id == currentTabGroupValue.last}), lastTabIndex > currentTabIndex {
            return lastTabIndex + 1
        } else {
            return currentTabIndex + 1
        }
    }

    // This is now the only entry point to add a tab
    func addNewTabAndGroup(_ tab: BrowserTab, setCurrent: Bool = true, withURL url: URL? = nil, at tabIndex: Int? = nil) {
        if tabIndex == nil {
            addNewTab(tab, setCurrent: setCurrent, withURL: url, at: indexForNewTabInGroup)
        } else {
            addNewTab(tab, setCurrent: setCurrent, withURL: url, at: tabIndex)
        }

        guard !tab.isPinned else { return }
        if let currentTabGroupKey = currentTabGroupKey, (url != nil || tab.preloadUrl != nil) {
            tabsGroup[currentTabGroupKey]?.append(tab.id)
        } else {
            createNewGroup(for: tab.id)
        }
    }

    private func addNewTab(_ tab: BrowserTab, setCurrent: Bool = true, withURL url: URL? = nil, at index: Int? = nil) {
        if let url = url {
            tab.load(url: url)
        }
        if let tabIndex = index, tabs.count > tabIndex {
            tabs.insert(tab, at: tabIndex)
        } else {
            tabs.append(tab)
        }
        if setCurrent {
            currentTab = tab
        }
        data.sessionLinkRanker.addTree(tree: tab.browsingTree)
    }

    func showNextTab() {
        guard let tab = currentTab, let i = tabs.firstIndex(of: tab) else { return }
        let index = (i + 1) % tabs.count
        currentTab = tabs[index]
    }

    func showPreviousTab() {
        guard let tab = currentTab, let i = tabs.firstIndex(of: tab) else { return }
        let index = i - 1 < 0 ? tabs.count - 1 : i - 1
        currentTab = tabs[index]
    }

    func showTab(at index: Int) {
        currentTab = tabs[index]
    }

    func reOpenedClosedTabFromHistory() -> Bool {
        if !tabHistory.isEmpty {
            let decoder = BeamJSONDecoder()
            let lastClosedTabData = tabHistory.removeLast()
            guard let lastClosedTab = try? decoder.decode(BrowserTab.self, from: lastClosedTabData) else { return false }
            lastClosedTab.id = UUID()
            addNewTab(lastClosedTab, setCurrent: true, withURL: nil)
            return true
        }
        return false
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
            window?.makeFirstResponder(nil)
        }
        if let currentTab = currentTab {
            DispatchQueue.main.async {
                currentTab.webView.window?.makeFirstResponder(currentTab.webView)
            }
        }
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
        removeFromTabGroup(tabId: tabToPin.id)
    }

    func unpinTab(_ tabToUnpin: BrowserTab) {
        tabToUnpin.unPin()
        updateIsPinned(for: tabToUnpin, isPinned: false)
        createNewGroup(for: tabToUnpin.id)
    }
}

// State tabs auto save
extension BrowserTabsManager {
    func autoSave() {
        if tabs.contains(where: { !$0.isPinned }) {
            AppDelegate.main.saveCloseTabsCmd(onExit: false)
        }
    }
}

// MARK: - Tabs Interactions Groups
extension BrowserTabsManager {

    private var currentTabGroupValue: [UUID]? {
        guard let currentTabId = self.currentTab?.id, tabsGroup[currentTabId] != nil else {
            return tabsGroup.first(where: { $1.contains(where: { $0 == currentTab?.id }) })?.value
        }
        return tabsGroup[currentTabId]
    }

    public var currentTabGroupKey: UUID? {
        guard let currentTabId = self.currentTab?.id, tabsGroup[currentTabId] != nil else {
            return tabsGroup.first(where: { $1.contains(where: { $0 == currentTab?.id }) })?.key
        }
        return currentTabId
    }

    public func createNewGroup(for tabId: UUID, with tabs: [UUID] = []) {
        tabsGroup[tabId] = tabs
    }

    @discardableResult
    // Remove the TabId from the Group and return the next TabId to show
    public func removeFromTabGroup(tabId: UUID) -> UUID? {
        guard let groupKey = currentTabGroupKey else { return nil }
        if tabId == groupKey {
            guard var group = tabsGroup.removeValue(forKey: groupKey), !group.isEmpty else { return nil }
            let firstTabId = group.removeFirst()
            tabsGroup[firstTabId] = group
            return firstTabId
        } else {
            guard let index = tabsGroup[groupKey]?.firstIndex(of: tabId),
                  let tabGroup = tabsGroup[groupKey] else { return nil }
            let nextTabToGo = nextTabToGo(from: index, of: tabGroup)

            tabsGroup[groupKey]?.removeAll(where: {$0 == tabId})
            if let group = tabsGroup[groupKey], group.isEmpty {
                tabsGroup.removeValue(forKey: groupKey)
            }
            return nextTabToGo ?? groupKey
        }
    }

    private func nextTabToGo(from index: Int, of group: [UUID]) -> UUID? {
        let afterIdx = group.index(after: index)
        let beforeIdx = group.index(before: index)
        if afterIdx < group.count {
            return group[afterIdx]
        } else if beforeIdx < group.count && beforeIdx >= 0 {
            return group[beforeIdx]
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
    private func setupTabsColoring() {
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
}
