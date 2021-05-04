//
//  BrowserTabsManager.swift
//  Beam
//
//  Created by Remi Santos on 30/04/2021.
//

import Foundation
import Combine
import SwiftSoup

protocol BrowserTabsManagerDelegate: AnyObject {

    func areTabsVisible(for manager: BrowserTabsManager) -> Bool

    func tabsManagerDidUpdateTabs(_ tabs: [BrowserTab])
    func tabsManagerDidChangeCurrentTab(_ currentTab: BrowserTab?)
    func tabsManagerBrowsingHistoryChanged(canGoBack: Bool, canGoForward: Bool)
}

class BrowserTabsManager: ObservableObject {

    weak var delegate: BrowserTabsManagerDelegate?

    private var tabScope = Set<AnyCancellable>()
    private var index: Index
    private var tabsAreVisible: Bool {
        self.delegate?.areTabsVisible(for: self) == true
    }

    @Published public var tabs: [BrowserTab] = [] {
        didSet {
            self.updateTabsHandlers()
            self.delegate?.tabsManagerDidUpdateTabs(tabs)
        }
    }

    @Published var currentTab: BrowserTab? {
        didSet {
            if tabsAreVisible {
                oldValue?.switchToOtherTab()
                currentTab?.startReading()
            }

            self.updateCurrentTabObservers()
            self.delegate?.tabsManagerDidChangeCurrentTab(currentTab)
        }
    }

    init(with data: BeamData) {
        self.index = data.index
    }

    private func updateCurrentTabObservers() {
        tabScope.removeAll()
        currentTab?.$canGoBack.sink { [weak self]  v in
            guard let self = self, let tab = self.currentTab else { return }
            self.delegate?.tabsManagerBrowsingHistoryChanged(canGoBack: v, canGoForward: tab.canGoForward)
        }.store(in: &tabScope)
        currentTab?.$canGoForward.sink { [weak self]  v in
            guard let self = self, let tab = self.currentTab else { return }
            self.delegate?.tabsManagerBrowsingHistoryChanged(canGoBack: tab.canGoBack, canGoForward: v)
        }.store(in: &tabScope)
    }

    private func updateTabsHandlers() {
        for tab in tabs {
            guard tab.onNewTabCreated == nil else { continue }
            
            tab.onNewTabCreated = { [weak self] newTab in
                guard let self = self else { return }
                self.tabs.append(newTab)
                // if var note = self.currentNote {
                // TODO bind visited sites with note contents:
                //                        if note.searchQueries.contains(newTab.originalQuery) {
                //                            if let url = newTab.url {
                //                                note.visitedSearchResults.append(VisitedPage(originalSearchQuery: newTab.originalQuery, url: url, date: Date(), duration: 0))
                //                                self.currentNote = note
                //                            }
                //                        }
                //                    }
            }

            tab.appendToIndexer = { [weak self] url, read in
                guard let self = self else { return }
                guard let doc = try? SwiftSoup.parse(read.content, url.absoluteString) else { return }
                let text: String = html2Text(url: url, doc: doc)
                self.index.append(document: IndexDocument(source: url.absoluteString, title: read.title, contents: text))
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
                currentTab?.switchToNewSearch()
            default:
                break
            }
        }
    }

    func addNewTab(_ tab: BrowserTab, setCurrent: Bool = true, withURL url: URL? = nil) {
        if let url = url {
            tab.load(url: url)
        }
        tabs.append(tab)
        if setCurrent {
            currentTab = tab
        }
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

    func closeCurrentTab() -> Bool {
        guard tabsAreVisible, let tab = currentTab else { return false }
        tab.cancelObservers()

        if let i = tabs.firstIndex(of: tab) {
            tabs.remove(at: i)
            let nextTabIndex = min(i, tabs.count - 1)
            if nextTabIndex >= 0 {
                currentTab = tabs[nextTabIndex]
            } else {
                currentTab = nil
            }
            return true
        }
        return false
    }

    func reloadCurrentTab() {
        currentTab?.webView.reload()
    }

    @discardableResult
    func removeTab(_ index: Int) -> Bool {
        let tab = tabs[index]
        guard currentTab !== tab else { return closeCurrentTab() }

        tab.cancelObservers()
        tabs.remove(at: index)

        return true
    }
}
