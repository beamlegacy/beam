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
    private var tabsAreVisible: Bool {
        self.delegate?.areTabsVisible(for: self) == true
    }

    private var data: BeamData
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
                currentTab?.startReading()
            }

            self.updateCurrentTabObservers()
            self.delegate?.tabsManagerDidChangeCurrentTab(currentTab)
        }
    }

    init(with data: BeamData) {
        self.data = data
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
                var text = ""
                var textForClustering = ""
                let tabTree = tab?.browsingTree.deepCopy()
                let currentTabTree = currentTab?.browsingTree.deepCopy()

                self.indexingQueue.async { [unowned self] in
                    let htmlNoteAdapter = HtmlNoteAdapter(url)
                    text = htmlNoteAdapter.convert(html: read.content)
                    textForClustering = htmlNoteAdapter.convertForClustering(html: read.content)

                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        let indexDocument = IndexDocument(source: url.absoluteString, title: read.title, contents: text)

                        let tabInformation: TabInformation? = TabInformation(url: url,
                                                                             tabTree: tabTree,
                                                                             currentTabTree: currentTabTree,
                                                                             parentBrowsingNode: tabTree?.current.parent,
                                                                             previousTabTree: self.latestCurrentTab,
                                                                             document: indexDocument,
                                                                             textContent: text,
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
            currentTab?.startReading()
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
        if let tabIndex = index, tabs.count > tabIndex, !setCurrent {
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
        AppDelegate.main.window?.makeFirstResponder(nil)
        if let currentTab = currentTab {
            DispatchQueue.main.async {
                currentTab.webView.window?.makeFirstResponder(currentTab.webView)
            }
        }
    }
}
