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

struct TabInformation {
    var url: URL
    var shouldBeIndexed: Bool = true
    weak var tabTree: BrowsingTree?
    weak var currentTabTree: BrowsingTree?
    weak var parentBrowsingNode: BrowsingNode?
    weak var previousTabTree: BrowsingTree?
    var document: IndexDocument
    var textContent: String
    var cleanedTextContentForClustering: String
}

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
        }
    }
    public var tabHistory: [Data] = []
    private weak var latestCurrentTab: BrowsingTree?
    @Published var currentTab: BrowserTab? {
        didSet {
            if tabsAreVisible {
                latestCurrentTab = oldValue?.browsingTree
                oldValue?.switchToOtherTab()
                currentTab?.startReading(withState: state)
            }

            self.updateCurrentTabObservers()
            self.delegate?.tabsManagerDidChangeCurrentTab(currentTab)
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
        }.store(in: &tabScope)
        currentTab?.$canGoForward.sink { [unowned self]  v in
            guard let tab = self.currentTab else { return }
            self.delegate?.tabsManagerBrowsingHistoryChanged(canGoBack: tab.canGoBack, canGoForward: v)
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
                var textForClustering = ""
                let tabTree = tab.browsingTree.deepCopy()
                let currentTabTree = currentTab?.browsingTree.deepCopy()

                self.indexingQueue.async { [unowned self] in
                    let htmlNoteAdapter = HtmlNoteAdapter(url)
                    textForClustering = htmlNoteAdapter.convertForClustering(html: read.content)

                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        let indexDocument = IndexDocument(source: url.absoluteString, title: read.title, contents: read.textContent)
                        let tabInformation: TabInformation? = TabInformation(url: url,
                                                                             shouldBeIndexed: tab.responseStatusCode == 200,
                                                                             tabTree: tabTree,
                                                                             currentTabTree: currentTabTree,
                                                                             parentBrowsingNode: tabTree?.current.parent,
                                                                             previousTabTree: self.latestCurrentTab,
                                                                             document: indexDocument,
                                                                             textContent: read.textContent,
                                                                             cleanedTextContentForClustering: textForClustering)
                        self.data.tabToIndex = tabInformation
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
            currentTab?.startReading(withState: state)
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

    func addNewTab(_ tab: BrowserTab, setCurrent: Bool = true, withURL url: URL? = nil, at index: Int? = nil) {
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
