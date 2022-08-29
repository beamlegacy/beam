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

    private let indexingQueue = DispatchQueue(label: "WebIndexing", target: .userInitiated)
    private var clusteringManager: ClusteringManagerProtocol
    private weak var previousTabBrowsingTree: BrowsingTree?
    private let signpost = SignPost("WebIndexingController")
    private var delayedReadOperations: [UUID: DelayedReadWebViewOperation] = [:]

    /// the delay before re-reading the page for better content
    var betterContentReadDelay: TimeInterval = 4

    weak var delegate: WebIndexControllerDelegate?

    init(clusteringManager: ClusteringManagerProtocol) {
        self.clusteringManager = clusteringManager
    }

    private func appendToClustering(url: URL, tabIndexingInfo: TabIndexingInfo, readabilityResult: Readability) {

        self.indexingQueue.async { [weak self] in
            var finalTabInfo = tabIndexingInfo
            finalTabInfo.cleanedTextContentForClustering = readabilityResult.textContentForClustering
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

    private func indexNavigation(to url: URL, tabIndexingInfo: TabIndexingInfo, read: Readability? = nil,
                                 browsingTree: BrowsingTree, isLinkActivation: Bool, startReading: Bool) {

        let title = tabIndexingInfo.document.title
        indexAliasURLIfNeeded(requestedURL: tabIndexingInfo.requestedURL, currentURL: url, title: title)

        guard let read = read else { return }
        browsingTree.update(for: url.absoluteString, readCount: tabIndexingInfo.textContent.count)

        let browsingTreeCopy = browsingTree.deepCopy()
        var tabIndexingInfo = tabIndexingInfo
        tabIndexingInfo.tabTree = browsingTreeCopy

        if tabIndexingInfo.shouldBeIndexed {
            Logger.shared.logInfo("Indexing navigation to: '\(tabIndexingInfo.url)', title: '\(tabIndexingInfo.document.title)'", category: .webIndexing)


            _ = LinkStore.shared.visit(tabIndexingInfo.url.string, title: tabIndexingInfo.document.title, content: tabIndexingInfo.textContent)
            appendToClustering(url: url, tabIndexingInfo: tabIndexingInfo, readabilityResult: read)
        }
        delegate?.webIndexingController(self, didIndexPageForURL: tabIndexingInfo.url)
    }

    /// handle the case where a redirection happened and we never get a title for the original url
    ///
    /// Returns `true` if the requestedURL was indexed.
    private func indexAliasURLIfNeeded(requestedURL: URL?, currentURL: URL, title: String?) {
        guard let requestedURL = requestedURL, isRequestedURL(requestedURL, anAliasFor: currentURL) else { return }

        Logger.shared.logInfo("Indexing alias '\(requestedURL)', redirecting to: '\(currentURL)', title: '\(title ?? "")'", category: .webIndexing)
        let urlToIndex = requestedURL.absoluteString

        // helps in notion case, when domain alias redirects to a sub page
        // and we want domain alias frecency to be the same as domain frecency
        let destinationURL = requestedURL.isDomain ? (currentURL.domain ?? currentURL) : currentURL

        let link = LinkStore.shared.visit(urlToIndex, title: title, content: nil, destination: destinationURL.absoluteString)
        ExponentialFrecencyScorer(storage: LinkStoreFrecencyUrlStorage())
            .update(id: link.id, value: 1.0, eventType: .webDomainIncrement, date: BeamDate.now, paramKey: .webVisit30d0)
    }

    private func isRequestedURL(_ requestedURL: URL?, anAliasFor url: URL) -> Bool {
        // this checks in case last url redirected just contains a /
        if  let requestedURL = requestedURL, requestedURL != url,
            url.absoluteString.prefix(url.absoluteString.count - 1) != requestedURL.absoluteString {
            return true
        }
        return false
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
                        shouldWaitForBetterContent: Bool, isLinkActivation: Bool, keepSameParent: Bool = false,
                        currentTab: BrowserTab?) {

        let webView = tab.webView
        let tabID = tab.id
        let fallbackTitle = webView.title
        let startReading = tab == currentTab
        let browsingTree = tab.browsingTree
        let currentTabBrowsingTree = currentTab?.browsingTree.deepCopy()
        let shouldIndexUserRequestedURL = isRequestedURL(originalRequestedURL, anAliasFor: url)

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
        if keepSameParent { browsingTree.goBack(startReading: false) }
        browsingTree.navigateTo(url: url.absoluteString, title: indexDocument.title, startReading: startReading, isLinkActivation: isLinkActivation)

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
                Logger.shared.logError("Error while indexing navigation: \(error)", category: .webIndexing)
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
                    guard let self = self else { return }
                    let delayedReadOperation = DelayedReadWebViewOperation(url: url, webView: webView, delay: self.betterContentReadDelay,
                                                                           firstRead: read, finishBlock: finishBlock)
                    self.delayedReadOperations[tabID] = delayedReadOperation
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
    private let delay: TimeInterval

    override var isAsynchronous: Bool {
        true
    }

    init(url: URL, webView: WKWebView, delay: TimeInterval, firstRead: Readability?, finishBlock: @escaping (Readability?) -> Void) {
        self.url = url
        self.firstRead = firstRead
        self.webView = webView
        self.delay = delay
        self.finishBlock = finishBlock
        super.init()
    }

    private weak var dispatchedMainWorkItem: DispatchWorkItem?
    private var hasFinishedAlready = false
    override var isFinished: Bool {
        hasFinishedAlready
    }

    private func callFinishBlock(with read: Readability?) {
        hasFinishedAlready = true
        finishBlock(read)
    }

    override func start() {
        let workItem = DispatchWorkItem(block: main)
        dispatchedMainWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(delay * 1000)), execute: workItem)
    }

    override func main() {
        guard !isFinished else { return }
        hasFinishedAlready = true
        guard !isCancelled, let webView = webView, webView.url == url else {
            callFinishBlock(with: firstRead)
            return
        }
        Readability.read(webView) { [weak self] result2 in
            var readabilityResultToUse = self?.firstRead
            switch result2 {
            case let .failure(error):
                Logger.shared.logError("Error while indexing web page on 2nd read: \(error), fallback to first read", category: .webIndexing)
            case let .success(read2):
                if read2 != self?.firstRead, let webViewURL = webView.url, webViewURL == self?.url {
                    readabilityResultToUse = read2
                }
            }
            self?.callFinishBlock(with: readabilityResultToUse)
        }
    }

    func cancel(sendFirstRead: Bool) {
        if sendFirstRead && !isFinished {
            callFinishBlock(with: firstRead)
        }
        self.cancel()
    }

    override func cancel() {
        dispatchedMainWorkItem?.cancel()
    }
}
