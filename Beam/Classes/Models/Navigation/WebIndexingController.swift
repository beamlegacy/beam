//
//  WebIndexingController.swift
//  Beam
//
//  Created by Remi Santos on 31/03/2022.
//

import Foundation
import BeamCore

/**
 * WebIndexingController is the one dispatching web events to different indexings and analysis.
 *
 * Owner needs to call the relevant public methods accordingly to notify of UI changes and navigation events.
 */
class WebIndexingController {

    private var indexingQueue = DispatchQueue(label: "WebIndexing", qos: .userInitiated)
    private var clusteringManager: ClusteringManager
    private weak var previousTabBrowsingTree: BrowsingTree?
    private let signpost = SignPost("WebIndexingController")

    init(clusteringManager: ClusteringManager) {
        self.clusteringManager = clusteringManager
    }

    // Copied from BrowserTab.appendToIndexer block
    private func appendToIndexer(url: URL, title: String, readabilityResult: Readability,
                                 originalRequestedURL: URL?,
                                 tab: BrowserTab, currentTabBrowsingTree: BrowsingTree?) {

        var textForClustering = [""]
        let tabTree = tab.browsingTree.deepCopy()
        let currentTabTree = currentTabBrowsingTree?.deepCopy()

        self.indexingQueue.async { [unowned self] in
            let htmlNoteAdapter = HtmlNoteAdapter(url)
            textForClustering = htmlNoteAdapter.convertForClustering(html: readabilityResult.content)

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                let indexDocument = IndexDocument(source: url.absoluteString, title: title, contents: readabilityResult.textContent)
                var shouldIndexUserTypedUrl = originalRequestedURL != nil && originalRequestedURL != tab.url

                // this check in case last url redirected just contains a /
                if let url = tab.url, let userTypedUrl = originalRequestedURL {
                    if url.absoluteString.prefix(url.absoluteString.count - 1) == userTypedUrl.absoluteString {
                        shouldIndexUserTypedUrl = false
                    }
                }

                let tabInfo = TabIndexingInfo(url: url,
                                              requestedURL: shouldIndexUserTypedUrl ? originalRequestedURL : nil,
                                              shouldBeIndexed: tab.responseStatusCode == 200,
                                              tabTree: tabTree,
                                              currentTabTree: currentTabTree,
                                              parentBrowsingNode: tabTree?.current.parent,
                                              previousTabTree: self.previousTabBrowsingTree,
                                              document: indexDocument,
                                              textContent: readabilityResult.textContent,
                                              cleanedTextContentForClustering: textForClustering,
                                              isPinnedTab: tab.isPinned)
                self.indexTabInfo(tabInfo)
                self.previousTabBrowsingTree = nil
            }
        }
    }

    // Copied from BeamData.tabToIndex.sink
    private func indexTabInfo(_ tabInfo: TabIndexingInfo) {
        signpost.begin("indexTab")
        defer { signpost.end("indexTab") }
        var currentId: UUID?
        var parentId: UUID?
        (currentId, parentId) = self.clusteringManager.getIdAndParent(tabToIndex: tabInfo)
        guard let id = currentId else { return }
        if tabInfo.shouldBeIndexed {
            self.clusteringManager.addPage(id: id, parentId: parentId, value: tabInfo)
            _ = LinkStore.shared.visit(tabInfo.url.string, title: tabInfo.document.title, content: tabInfo.textContent)
        }
    }

    /// Unused. We let the LinkStore do its job.
    /// This was commented out in January 2022 with commit f405554
    /// It used to be in BeamData.tabToIndex
    private func updateHistoryRecordDirectly(urlId: UUID, _ tabInfo: TabIndexingInfo) {
        do {
            if tabInfo.shouldBeIndexed {
                try GRDBDatabase.shared._insertHistoryUrl(urlId: urlId,
                                                          url: tabInfo.url.string,
                                                          aliasDomain: tabInfo.requestedURL?.absoluteString,
                                                          title: tabInfo.document.title,
                                                          content: nil)
            }
        } catch {
            Logger.shared.logError("unable to save history url \(tabInfo.url.string)", category: .search)
        }
    }

    // swiftlint will be fixed in upcoming MR. To simplify the first refactor MR
    // swiftlint:disable:next function_parameter_count
    private func indexNavigation(to url: URL, isLinkActivation: Bool, startReading: Bool,
                                 browsingTree: BrowsingTree, read: Readability? = nil, fallbackTitle: String?,
                                 originalRequestedURL: URL?,
                                 tab: BrowserTab, currentTab: BrowserTab?) {

        // Alway index the visit, event if we were not able to read the content
        let title = read?.title ?? fallbackTitle ?? ""
        browsingTree.navigateTo(url: url.absoluteString, title: title,
                                startReading: startReading,
                                isLinkActivation: isLinkActivation,
                                readCount: read?.content.count ?? 0)

        guard let read = read else { return }

        try? TextSaver.shared?.save(nodeId: browsingTree.current.id, text: read)

        appendToIndexer(url: url, title: title, readabilityResult: read, originalRequestedURL: originalRequestedURL,
                        tab: tab, currentTabBrowsingTree: currentTab?.browsingTree)
    }

    /// handle the case where a redirection happened and we never get a title for the original url
    private func indexRedirectedURLIfNeeded(requestedURL: URL?, currentURL: URL, title: String?) {
        guard let requestedURL = requestedURL, requestedURL != currentURL else { return }
        Logger.shared.logInfo("Mark original request of navigation as visited with resulting title \(requestedURL) - \(String(describing: title))")
        let urlToIndex = requestedURL.absoluteString

        // helps in notion case, when domain alias redirects to a sub page
        // and we want domain alias frecency to be the same as domain frecency
        let destinationURL = requestedURL.isDomain ? (currentURL.domain ?? currentURL) : currentURL

        let link = LinkStore.shared.visit(urlToIndex, title: title, content: nil, destination: destinationURL.absoluteString)
        ExponentialFrecencyScorer(storage: LinkStoreFrecencyUrlStorage())
            .update(id: link.id, value: 1.0, eventType: .webDomainIncrement, date: BeamDate.now, paramKey: .webVisit30d0)
    }

}

struct TabIndexingInfo {
    let url: URL
    private(set) var requestedURL: URL?
    private(set) var shouldBeIndexed: Bool = true
    weak var tabTree: BrowsingTree?
    weak var currentTabTree: BrowsingTree?
    weak var parentBrowsingNode: BrowsingNode?
    weak private(set) var previousTabTree: BrowsingTree?
    let document: IndexDocument
    let textContent: String
    let cleanedTextContentForClustering: [String]
    private(set) var isPinnedTab: Bool = false
}

// MARK: - Public Methods
extension WebIndexingController {

    // MARK: Navigation events

    // swiftlint will be fixed in upcoming MR. To simplify the first refactor MR
    // swiftlint:disable:next function_parameter_count
    func tabDidNavigate(_ tab: BrowserTab, toURL url: URL, inWebView webView: WKWebView, originalRequestedURL: URL?,
                        shouldWaitForBetterContent: Bool, isLinkActivation: Bool, currentTab: BrowserTab?) {
        let fallbackTitle = webView.title
        let startReading = tab == currentTab
        let browsingTree = tab.browsingTree
        indexRedirectedURLIfNeeded(requestedURL: originalRequestedURL, currentURL: url, title: fallbackTitle)

        Readability.read(webView) { [weak self] result in
            guard let self = self else { return }
            var readabilityResultToUse: Readability?
            switch result {
            case let .success(read):
                readabilityResultToUse = read

                // This is ugly, and should be refactored using new async syntax when possible
                // But it's needed to try to index the good content when navigating from JS
                if shouldWaitForBetterContent {
                    let reIndexDelay = 4
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(reIndexDelay)) {
                        Readability.read(webView) { [weak self, weak webView] result2 in
                            switch result2 {
                            case let .success(read2):
                                if read2 != read, let webViewURL = webView?.url, webViewURL == url {
                                    readabilityResultToUse = read2
                                }
                            case let .failure(error):
                                Logger.shared.logError("Error while indexing web page on 2nd read: \(error)", category: .web)
                            }
                            self?.indexNavigation(to: url, isLinkActivation: isLinkActivation, startReading: startReading,
                                                  browsingTree: browsingTree, read: readabilityResultToUse, fallbackTitle: fallbackTitle, originalRequestedURL: originalRequestedURL,
                                                  tab: tab, currentTab: currentTab)
                        }
                    }
                } else {
                    self.indexNavigation(to: url, isLinkActivation: isLinkActivation, startReading: startReading,
                                         browsingTree: browsingTree, read: readabilityResultToUse, fallbackTitle: fallbackTitle, originalRequestedURL: originalRequestedURL,
                                         tab: tab, currentTab: currentTab)
                }
            case let .failure(error):
                Logger.shared.logError("Error while indexing web page: \(error)", category: .web)
                self.indexNavigation(to: url, isLinkActivation: isLinkActivation, startReading: startReading,
                                     browsingTree: browsingTree, fallbackTitle: fallbackTitle, originalRequestedURL: originalRequestedURL,
                                     tab: tab, currentTab: currentTab)
            }
        }
    }

    // MARK: UI Changes that the indexing should be aware
    func currentTabDidChange(_ currentTab: BrowserTab?, previousCurrentTab: BrowserTab?) {
        previousTabBrowsingTree = previousCurrentTab?.browsingTree
    }
}
