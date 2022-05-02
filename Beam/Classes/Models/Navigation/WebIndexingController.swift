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
    private var delayedReadOperations: [UUID: DelayedReadWebViewOperation] = [:]

    weak var delegate: WebIndexControllerDelegate?

    init(clusteringManager: ClusteringManager) {
        self.clusteringManager = clusteringManager
    }

    private func appendToClustering(url: URL, tabIndexingInfo: TabIndexingInfo, readabilityResult: Readability) {

        self.indexingQueue.async { [unowned self] in
            var finalTabInfo = tabIndexingInfo
            let htmlNoteAdapter = HtmlNoteAdapter(url)
            finalTabInfo.cleanedTextContentForClustering = htmlNoteAdapter.convertForClustering(html: readabilityResult.content)

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.signpost.begin("indexTab")
                defer { self.signpost.end("indexTab") }

                var currentId: UUID?
                var parentId: UUID?
                (currentId, parentId) = self.clusteringManager.getIdAndParent(tabToIndex: finalTabInfo)
                guard let id = currentId else { return }

                self.clusteringManager.addPage(id: id, parentId: parentId, value: finalTabInfo)
            }
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

    private func indexNavigation(to url: URL, tabIndexingInfo: TabIndexingInfo, read: Readability? = nil,
                                 browsingTree: BrowsingTree, isLinkActivation: Bool, startReading: Bool) {

        // Always update the browsingTree, event if we were not able to read the content
        let title = tabIndexingInfo.document.title
        browsingTree.navigateTo(url: url.absoluteString, title: title,
                                startReading: startReading,
                                isLinkActivation: isLinkActivation,
                                readCount: tabIndexingInfo.textContent.count)

        guard let read = read else { return }

        let browsingTreeCopy = browsingTree.deepCopy()
        var tabIndexingInfo = tabIndexingInfo
        tabIndexingInfo.tabTree = browsingTreeCopy

        if tabIndexingInfo.shouldBeIndexed {
            _ = LinkStore.shared.visit(tabIndexingInfo.url.string, title: tabIndexingInfo.document.title, content: tabIndexingInfo.textContent)
            appendToClustering(url: url, tabIndexingInfo: tabIndexingInfo, readabilityResult: read)
        }
        delegate?.webIndexingController(self, didIndexPageForURL: tabIndexingInfo.url)
    }

    /// handle the case where a redirection happened and we never get a title for the original url
    ///
    /// Returns `true` if the requestedURL was indexed.
    private func indexRedirectedURLIfNeeded(requestedURL: URL?, currentURL: URL, title: String?) -> Bool {
        guard let requestedURL = requestedURL else { return false }

        // this checks in case last url redirected just contains a /
        guard requestedURL != currentURL && currentURL.absoluteString.prefix(currentURL.absoluteString.count - 1) != requestedURL.absoluteString else {
            return false
        }

        Logger.shared.logInfo("Mark original request of navigation as visited with resulting title \(requestedURL) - \(String(describing: title))")
        let urlToIndex = requestedURL.absoluteString

        // helps in notion case, when domain alias redirects to a sub page
        // and we want domain alias frecency to be the same as domain frecency
        let destinationURL = requestedURL.isDomain ? (currentURL.domain ?? currentURL) : currentURL

        let link = LinkStore.shared.visit(urlToIndex, title: title, content: nil, destination: destinationURL.absoluteString)
        ExponentialFrecencyScorer(storage: LinkStoreFrecencyUrlStorage())
            .update(id: link.id, value: 1.0, eventType: .webDomainIncrement, date: BeamDate.now, paramKey: .webVisit30d0)
        return true
    }

    /// Once we received some Readbility result from the webView, the tab indexing info can be more precise.
    private func updateTabIndexingInfo(_ tabIndexingInfo: TabIndexingInfo, withReadabilityResult read: Readability?) -> TabIndexingInfo {
        var result = tabIndexingInfo
        if let read = read {
            let title = read.title
            let indexDocument = IndexDocument(source: tabIndexingInfo.url.absoluteString, title: title, contents: read.textContent)
            result.document = indexDocument
            result.textContent = read.textContent
        }
        return result
    }
}

struct TabIndexingInfo {
    let url: URL
    private(set) var requestedURL: URL?
    private(set) var shouldBeIndexed: Bool = true
    fileprivate(set) var tabTree: BrowsingTree?
    private(set) var currentTabTree: BrowsingTree?
    private(set) var previousTabTree: BrowsingTree?
    fileprivate(set) var document: IndexDocument
    fileprivate(set) var textContent: String = ""
    fileprivate(set) var cleanedTextContentForClustering: [String] = []
    private(set) var isPinnedTab: Bool = false
}

// MARK: - Public Methods
extension WebIndexingController {

    // MARK: Navigation events

    func tabDidNavigate(_ tab: BrowserTab, toURL url: URL, originalRequestedURL: URL?,
                        shouldWaitForBetterContent: Bool, isLinkActivation: Bool, currentTab: BrowserTab?) {

        let webView = tab.webView
        let tabID = tab.id
        let fallbackTitle = webView.title
        let startReading = tab == currentTab
        let browsingTree = tab.browsingTree
        let currentTabBrowsingTree = currentTab?.browsingTree.deepCopy()
        let shouldIndexUserRequestedURL = indexRedirectedURLIfNeeded(requestedURL: originalRequestedURL, currentURL: url, title: fallbackTitle)

        let indexDocument = IndexDocument(source: url.absoluteString, title: fallbackTitle ?? "", contents: "")

        var tabIndexingInfo = TabIndexingInfo(url: url,
                                              requestedURL: shouldIndexUserRequestedURL ? originalRequestedURL : nil,
                                              shouldBeIndexed: tab.responseStatusCode == 200,
                                              tabTree: browsingTree.deepCopy(),
                                              currentTabTree: currentTabBrowsingTree?.deepCopy(),
                                              previousTabTree: previousTabBrowsingTree?.deepCopy(),
                                              document: indexDocument,
                                              isPinnedTab: tab.isPinned)

        previousTabBrowsingTree = nil

        let finishBlock: (Readability?) -> Void = { [weak self] readabilityResultToUse in
            tabIndexingInfo = self?.updateTabIndexingInfo(tabIndexingInfo, withReadabilityResult: readabilityResultToUse) ?? tabIndexingInfo
            self?.indexNavigation(to: url, tabIndexingInfo: tabIndexingInfo, read: readabilityResultToUse,
                                  browsingTree: browsingTree, isLinkActivation: isLinkActivation, startReading: startReading)
        }
        if let delayedRead = delayedReadOperations[tabID] {
            delayedRead.cancel(sendFirstRead: true)
            delayedReadOperations.removeValue(forKey: tabID)
        }
        Readability.read(webView) { [weak self] result in
            switch result {
            case let .failure(error):
                Logger.shared.logError("Error while indexing web page: \(error)", category: .web)
                finishBlock(nil)
            case let .success(read):
                if !shouldWaitForBetterContent {
                    finishBlock(read)
                } else {
                    // For some contexts, we perform another read of the webview content after a moment
                    // in hope that the content is fully loaded.
                    // Typically a JS navigation could seem instant from a webview perspective while the website still layouts its content.
                    //
                    // We put the 2nd content read in an async task to be performed after a delay.
                    // In the meantime, if the tab receives another navigation, or the webView changes URL,
                    // we cancel the task and just use whatever we had at first read.

                    let delayedReadOperation = DelayedReadWebViewOperation(url: url, webView: webView, firstRead: read, finishBlock: finishBlock)
                    self?.delayedReadOperations[tabID] = delayedReadOperation
                    delayedReadOperation.start()
                }
            }
        }
    }

    // MARK: UI Changes that the indexing should be aware
    func currentTabDidChange(_ currentTab: BrowserTab?, previousCurrentTab: BrowserTab?) {
        previousTabBrowsingTree = previousCurrentTab?.browsingTree
    }

    func tabDidClose(_ tab: BrowserTab) {
        let tabID = tab.id
        if let delayedRead = delayedReadOperations[tabID] {
            delayedRead.cancel(sendFirstRead: true)
            delayedReadOperations.removeValue(forKey: tabID)
        }
    }
}

protocol WebIndexControllerDelegate: AnyObject {
    func webIndexingController(_ controller: WebIndexingController, didIndexPageForURL url: URL)
}

/// Perfoms a readability read of the webview after a delay.
///
/// The operation can be stopped before the end of the delay,
/// to not perform the second read while still sending the information of the first read.
private final class DelayedReadWebViewOperation: Operation {

    private let url: URL
    private let firstRead: Readability?
    private let finishBlock: (Readability?) -> Void
    private weak var webView: WKWebView?

    /// Delay in seconds
    private let delay = 4
    override var isAsynchronous: Bool {
        true
    }

    init(url: URL, webView: WKWebView, firstRead: Readability?, finishBlock: @escaping (Readability?) -> Void) {
        self.url = url
        self.firstRead = firstRead
        self.webView = webView
        self.finishBlock = finishBlock
        super.init()
    }

    private var dispatchedMainWorkItem: DispatchWorkItem?
    private var hasFinishedAlready = false
    override var isFinished: Bool {
        hasFinishedAlready
    }

    private func finish(with read: Readability?) {
        guard !isFinished else { return }
        hasFinishedAlready = true
        finishBlock(read)
    }

    override func start() {
        let workItem = DispatchWorkItem(block: main)
        dispatchedMainWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay), execute: workItem)
    }

    override func main() {
        guard !isFinished else { return }
        hasFinishedAlready = true
        guard !isCancelled, let webView = webView, webView.url == url else {
            finish(with: firstRead)
            return
        }
        Readability.read(webView) { [weak self] result2 in
            var readabilityResultToUse = self?.firstRead
            switch result2 {
            case let .failure(error):
                Logger.shared.logError("Error while indexing web page on 2nd read: \(error), fallback to first read", category: .web)
            case let .success(read2):
                if read2 != self?.firstRead, let webViewURL = webView.url, webViewURL == self?.url {
                    readabilityResultToUse = read2
                }
            }
            self?.finish(with: readabilityResultToUse)
        }
    }

    func cancel(sendFirstRead: Bool) {
        if sendFirstRead && !isFinished {
            finish(with: firstRead)
        }
        self.cancel()
    }

    override func cancel() {
        dispatchedMainWorkItem?.cancel()
    }
}
