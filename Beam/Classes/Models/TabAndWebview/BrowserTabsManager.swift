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
    func tabsManagerDidChangeCurrentTab(_ currentTab: BrowserTab?)
    func tabsManagerBrowsingHistoryChanged(canGoBack: Bool, canGoForward: Bool)
}

class BrowserTabsManager: ObservableObject {

    weak var delegate: BrowserTabsManagerDelegate?

    private var tabScope = Set<AnyCancellable>()
    private var dataScope = Set<AnyCancellable>()
    private var tabsAreVisible: Bool {
        self.delegate?.areTabsVisible(for: self) == true
    }

    private var data: BeamData
    private weak var state: BeamState?
    @Published public var tabs: [BrowserTab] = [] {
        didSet {
            self.updateTabsHandlers()
            self.delegate?.tabsManagerDidUpdateTabs(tabs)
            self.autoSave()
        }
    }

    private var tabsGroup: [Int: [UUID]] = [:]

    private var currentTabGroupValue: [UUID]? {
        guard let groupKey = tabsGroup.first(where: { $1.contains(where: { $0 == currentTab?.id }) })?.key else { return nil }
        return tabsGroup[groupKey]
    }

    private var currentTabGroupKey: Int? {
        tabsGroup.first(where: { $1.contains(where: { $0 == currentTab?.id }) })?.key
    }

    public func createNewGroup(for tabId: UUID) {
        var newGroupNbr = 0
        if let lastGroupNbr = Array(tabsGroup.keys).last {
            newGroupNbr = lastGroupNbr + 1
        }
        tabsGroup[newGroupNbr] = [tabId]
    }

    public func removeTabFromGroup(tabId: UUID) {
        guard let groupKey = currentTabGroupKey else { return }
        tabsGroup[groupKey]?.removeAll(where: {$0 == tabId})
        if let group = tabsGroup[groupKey], group.isEmpty {
            tabsGroup.removeValue(forKey: groupKey)
        }
    }

    public var tabHistory: [Data] = []
    private weak var latestCurrentTab: BrowsingTree?
    @Published var currentTab: BrowserTab? {
        didSet {
            if tabsAreVisible {
                latestCurrentTab = oldValue?.browsingTree
                oldValue?.switchToOtherTab()
                currentTab?.tabDidAppear(withState: state)
            }

            self.updateCurrentTabObservers()
            self.delegate?.tabsManagerDidChangeCurrentTab(currentTab)
            self.autoSave()
        }
    }

    init(with data: BeamData, state: BeamState) {
        self.data = data
        self.state = state
        tabs.append(contentsOf: data.pinnedTabs)
        setupPinnedTabObserver()
        currentTab = tabs.first
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

    private var indexingQueue = DispatchQueue(label: "indexing")

    private func updateTabsHandlers() {
        for tab in tabs {
            guard tab.onNewTabCreated == nil else { continue }

            tab.onNewTabCreated = { [unowned self] newTab in
                self.tabs.append(newTab)
                // if var note = self.currentNote {
                // TODO bind visited sites with note contents:
                //                        if note.searchQueries.contains(newTab.originalQuery) {
                //                            if let url = newTab.url {
                //                                note.visitedSearchResults.append(VisitedPage(originalSearchQuery: newTab.originalQuery, url: url, date: BeamDate.now, duration: 0))
                //                                self.currentNote = note
                //                            }
                //                        }
                //                    }
            }

            tab.appendToIndexer = { [unowned self, weak tab] url, read in
                guard let tab = tab else { return }
                var textForClustering = [""]
                let tabTree = tab.browsingTree.deepCopy()
                let currentTabTree = currentTab?.browsingTree.deepCopy()

                self.indexingQueue.async { [unowned self] in
                    let htmlNoteAdapter = HtmlNoteAdapter(url)
                    textForClustering = htmlNoteAdapter.convertForClustering(html: read.content)

                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        let indexDocument = IndexDocument(source: url.absoluteString, title: read.title, contents: read.textContent)
                        var shouldIndexUserTypedUrl = tab.userTypedDomain != nil && tab.userTypedDomain != tab.url

                        // this check is case last url redirected just contains a /
                        if let url = tab.url, let userTypedUrl = tab.userTypedDomain {
                            if url.absoluteString.prefix(url.absoluteString.count - 1) == userTypedUrl.absoluteString {
                                shouldIndexUserTypedUrl = false
                            }
                        }

                        let tabInformation: TabInformation? = TabInformation(url: url,
                                                                             userTypedUrl: shouldIndexUserTypedUrl ? tab.userTypedDomain : nil,
                                                                             shouldBeIndexed: tab.responseStatusCode == 200,
                                                                             tabTree: tabTree,
                                                                             currentTabTree: currentTabTree,
                                                                             parentBrowsingNode: tabTree?.current.parent,
                                                                             previousTabTree: self.latestCurrentTab,
                                                                             document: indexDocument,
                                                                             textContent: read.textContent,
                                                                             cleanedTextContentForClustering: textForClustering,
                                                                             isPinnedTab: tab.isPinned)
                        self.data.tabToIndex = tabInformation
                        self.currentTab?.userTypedDomain = nil
                        self.latestCurrentTab = nil
                    }
                }
            }
        }
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

    // This is now the only entry point to add a tab
    func addNewTabAndGroup(_ tab: BrowserTab, setCurrent: Bool = true, withURL url: URL? = nil) {
        if let index = tabs.firstIndex(where: {$0.id == currentTabGroupValue?.last}) {
            addNewTab(tab, setCurrent: setCurrent, withURL: url, at: index + 1)
        } else {
            addNewTab(tab, setCurrent: setCurrent, withURL: url)
        }

        guard !tab.isPinned else { return }
        if let currentTabGroupKey = currentTabGroupKey, url != nil {
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
            let decoder = JSONDecoder()
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
        if let currentTab = currentTab, let webView = currentTab.webView {
            DispatchQueue.main.async {
                webView.window?.makeFirstResponder(currentTab.webView)
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
        updateIsPinned(for: tabToPin, isPinned: true)
    }

    func unpinTab(_ tabToUnpin: BrowserTab) {
        updateIsPinned(for: tabToUnpin, isPinned: false)
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

struct TabInformation {
    var url: URL
    var userTypedUrl: URL?
    var shouldBeIndexed: Bool = true
    weak var tabTree: BrowsingTree?
    weak var currentTabTree: BrowsingTree?
    weak var parentBrowsingNode: BrowsingNode?
    weak var previousTabTree: BrowsingTree?
    var document: IndexDocument
    var textContent: String
    var cleanedTextContentForClustering: [String]
    var isPinnedTab: Bool = false
}
