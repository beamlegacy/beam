//
//  FaviconProviderTests.swift
//  BeamTests
//
//  Created by Remi Santos on 27/10/2021.
//

import XCTest
@testable import Beam
import WebKit

class FaviconProviderTests: XCTestCase {

    override class func setUp() {
        FaviconProvider().clearCache()
    }

    override class func tearDown() {
        FaviconProvider().clearCache()
    }
    
    func testPickBestFaviconWithBestSizePNG() {
        
        let icons = [
            Favicon(url: URL(string: "f.co/icon.png?s=16")!, width: 16, height: 16, origin: .webView),
            Favicon(url: URL(string: "f.co/icon.png?s=32")!, width: 32, height: 32, origin: .webView),
            Favicon(url: URL(string: "f.co/icon.png?s=96")!, width: 96, height: 96, origin: .webView),
            Favicon(url: URL(string: "f.co/icon.png?s=256")!, width: 256, height: 256, origin: .webView),
            Favicon(url: URL(string: "f.co/icon.png?s=512")!, width: 512, height: 512, origin: .webView),
            Favicon(url: URL(string: "f.co/icon.ico")!, origin: .webView)
        ]
        let finder = FaviconProvider.Finder()
        let resultFor16 = finder.pickBestFavicon(icons, forSize: 16)
        XCTAssertNotNil(resultFor16)
        XCTAssertEqual(resultFor16?.width, 32)
        XCTAssertEqual(resultFor16?.url.absoluteString, "f.co/icon.png?s=32")

        let resultFor32 = finder.pickBestFavicon(icons, forSize: 32)
        XCTAssertNotNil(resultFor32)
        XCTAssertEqual(resultFor32?.width, 96)
        XCTAssertEqual(resultFor32?.url.absoluteString, "f.co/icon.png?s=96")

        let resultFor34 = finder.pickBestFavicon(icons, forSize: 34)
        XCTAssertNotNil(resultFor34)
        XCTAssertEqual(resultFor34?.width, 96)
        XCTAssertEqual(resultFor34?.url.absoluteString, "f.co/icon.png?s=96")
    }

    func testPickBestFaviconWithICO() {

        let icons = [
            Favicon(url: URL(string: "f.co/icon.ico?s=256")!, width: 96, height: 96, origin: .webView),
            Favicon(url: URL(string: "f.co/icon.ico?s=128")!, width: 128, height: 128, origin: .webView),
            Favicon(url: URL(string: "f.co/icon.ico?s=nil")!, origin: .webView)
        ]

        let resultFor32 = FaviconProvider.Finder().pickBestFavicon(icons, forSize: 32)
        XCTAssertNotNil(resultFor32)
        XCTAssertNil(resultFor32?.width)
        XCTAssertEqual(resultFor32?.url.absoluteString, "f.co/icon.ico?s=nil")
    }


    func testURLLevels() {
        let url = URL(string: "https://app.beamapp.co/another/path/page.html")!
        var keys = FaviconProvider.FaviconLevelsKeys(url: url, size: 32)

        XCTAssertEqual(keys.cacheKey(level: .full), "app.beamapp.co/another/path/page.html-32")
        XCTAssertEqual(keys.cacheKey(level: .path), "app.beamapp.co/another/path-32")
        XCTAssertEqual(keys.cacheKey(level: .host), "app.beamapp.co-32")

        let urlWithoutScheme = URL(string: "app.beamapp.co/another/path/page.html")!
        keys = FaviconProvider.FaviconLevelsKeys(url: urlWithoutScheme, size: 32)

        XCTAssertEqual(keys.cacheKey(level: .full), "app.beamapp.co/another/path/page.html-32")
        XCTAssertEqual(keys.cacheKey(level: .path), "app.beamapp.co/another/path-32")
        XCTAssertEqual(keys.cacheKey(level: .host), "app.beamapp.co-32")
    }

    func testURLLevelsForPath() {
        let url = URL(string: "https://app.beamapp.co/another/path/")!
        var keys = FaviconProvider.FaviconLevelsKeys(url: url, size: 32)

        XCTAssertEqual(keys.cacheKey(level: .full), "app.beamapp.co/another/path-32")
        XCTAssertEqual(keys.cacheKey(level: .path), keys.cacheKey(level: .full))
        XCTAssertEqual(keys.cacheKey(level: .host), "app.beamapp.co-32")

        let urlWithoutScheme = URL(string: "app.beamapp.co/another/path/")!
        keys = FaviconProvider.FaviconLevelsKeys(url: urlWithoutScheme, size: 32)

        XCTAssertEqual(keys.cacheKey(level: .full), "app.beamapp.co/another/path-32")
        XCTAssertEqual(keys.cacheKey(level: .path), keys.cacheKey(level: .full))
        XCTAssertEqual(keys.cacheKey(level: .host), "app.beamapp.co-32")
    }

    func testURLLevelsForHost() {
        let url = URL(string: "https://app.beamapp.co/")!
        var keys = FaviconProvider.FaviconLevelsKeys(url: url, size: 32)

        XCTAssertEqual(keys.cacheKey(level: .full), "app.beamapp.co-32")
        XCTAssertEqual(keys.cacheKey(level: .path), keys.cacheKey(level: .full))
        XCTAssertEqual(keys.cacheKey(level: .host), keys.cacheKey(level: .full))

        let urlWithoutScheme = URL(string: "app.beamapp.co/")!
        keys = FaviconProvider.FaviconLevelsKeys(url: urlWithoutScheme, size: 32)

        XCTAssertEqual(keys.cacheKey(level: .full), "app.beamapp.co-32")
        XCTAssertEqual(keys.cacheKey(level: .path), keys.cacheKey(level: .full))
        XCTAssertEqual(keys.cacheKey(level: .host), keys.cacheKey(level: .full))
    }

    private func retrieveFavicon(provider: FaviconProvider, url: URL, webView: WKWebView? = nil,
                                 cachePolicy: FaviconProvider.CachePolicy = .default, waitCount: Int = 1) async -> Favicon? {
        await withCheckedContinuation { continuation in
            var waitCount = waitCount
            provider.favicon(fromURL: url, webView: webView, cachePolicy: cachePolicy) { favicon in
                waitCount -= 1
                if waitCount == 0 {
                    continuation.resume(with: .success(favicon))
                }
            }
        }
    }

    func testGetCacheIconLevelsPriority() async {
        let url = URL(string: "app.beamapp.co/another/path/page.html")!
        let keys = FaviconProvider.FaviconLevelsKeys(url: url, size: 32)
        let cache = FaviconCache(countLimit: 100)
        let faviconFullURL = Favicon(url: URL(string: "beamapp.co/asset/icon.png#full")!, origin: .webView)
        let faviconPath = Favicon(url: URL(string: "beamapp.co/asset/icon.png#path")!, origin: .webView)
        let faviconHost = Favicon(url: URL(string: "beamapp.co/asset/icon.png#host")!, origin: .webView)
        cache.insert(faviconFullURL, forKey: keys.cacheKey(level: .full))
        cache.insert(faviconPath, forKey: keys.cacheKey(level: .path))
        cache.insert(faviconHost, forKey: keys.cacheKey(level: .host))

        let provider = FaviconProvider(withCache: cache)

        // priority to full
        let icon1 = await retrieveFavicon(provider: provider, url: url, cachePolicy: .cacheOnly)
        XCTAssertEqual(icon1?.url, faviconFullURL.url)

        // then path
        cache.removeValue(forKey: keys.cacheKey(level: .full))
        let icon2 = await retrieveFavicon(provider: provider, url: url, cachePolicy: .cacheOnly)
        XCTAssertEqual(icon2?.url, faviconPath.url)

        // then host
        cache.removeValue(forKey: keys.cacheKey(level: .path))
        let icon3 = await retrieveFavicon(provider: provider, url: url, cachePolicy: .cacheOnly)
        XCTAssertEqual(icon3?.url, faviconHost.url)
    }

    @MainActor
    func testUpdateFaviconLevelsPriority() async {
        let url = URL(string: "app.beamapp.co/another/path/page.html")!
        let pathURL = URL(string: "app.beamapp.co/another/path")!
        let hostURL = URL(string: "app.beamapp.co")!
        let keys = FaviconProvider.FaviconLevelsKeys(url: url, size: 32)
        let cache = FaviconCache(countLimit: 100)
        let faviconFullURL = Favicon(url: URL(string: "beamapp.co/asset/icon.png#full")!, origin: .webView)
        let faviconPath = Favicon(url: URL(string: "beamapp.co/asset/icon.png#path")!, origin: .webView)
        let faviconHost = Favicon(url: URL(string: "beamapp.co/asset/icon.png#host")!, origin: .webView)        
        let finder = MockFinder()
        let webView = MockWebView()
        let provider = FaviconProvider(withCache: cache, withFinder: finder)

        XCTAssertEqual(cache.numberOfValues, 0)

        // Skipping cache to test the retrieval of a new favicon

        // 1. load url. empty, updated the host with full icon
        finder.faviconFromWebview = faviconFullURL
        _ = await retrieveFavicon(provider: provider, url: url, webView: webView, cachePolicy: .skipCache)
        XCTAssertEqual(cache.numberOfValues, 1)
        XCTAssertEqual(cache.value(forKey: keys.cacheKey(level: .host))?.url, faviconFullURL.url)

        // 2. load url again. nothing updated
        finder.faviconFromWebview = faviconFullURL
        _ = await retrieveFavicon(provider: provider, url: url, webView: webView, cachePolicy: .skipCache)
        XCTAssertEqual(cache.numberOfValues, 1)
        XCTAssertEqual(cache.value(forKey: keys.cacheKey(level: .host))?.url, faviconFullURL.url)

        // 3. load host url. host is updated
        finder.faviconFromWebview = faviconHost
        _ = await retrieveFavicon(provider: provider, url: hostURL, webView: webView, cachePolicy: .skipCache)
        XCTAssertEqual(cache.numberOfValues, 1)
        XCTAssertEqual(cache.value(forKey: keys.cacheKey(level: .host))?.url, faviconHost.url)

        // 4. load url again. path is updated, host is kept
        finder.faviconFromWebview = faviconFullURL
        _ = await retrieveFavicon(provider: provider, url: url, webView: webView, cachePolicy: .skipCache)
        XCTAssertEqual(cache.numberOfValues, 2)
        XCTAssertEqual(cache.value(forKey: keys.cacheKey(level: .host))?.url, faviconHost.url)
        XCTAssertEqual(cache.value(forKey: keys.cacheKey(level: .path))?.url, faviconFullURL.url)

        // 5. load path url. path is updated
        finder.faviconFromWebview = faviconPath
        _ = await retrieveFavicon(provider: provider, url: pathURL, webView: webView, cachePolicy: .skipCache)
        XCTAssertEqual(cache.numberOfValues, 2)
        XCTAssertEqual(cache.value(forKey: keys.cacheKey(level: .host))?.url, faviconHost.url)
        XCTAssertEqual(cache.value(forKey: keys.cacheKey(level: .path))?.url, faviconPath.url)

        // 6. load url again. full is updated, path is kept, host is kept
        finder.faviconFromWebview = faviconFullURL
        _ = await retrieveFavicon(provider: provider, url: url, webView: webView, cachePolicy: .skipCache)
        XCTAssertEqual(cache.numberOfValues, 3)
        XCTAssertEqual(cache.value(forKey: keys.cacheKey(level: .host))?.url, faviconHost.url)
        XCTAssertEqual(cache.value(forKey: keys.cacheKey(level: .path))?.url, faviconPath.url)
        XCTAssertEqual(cache.value(forKey: keys.cacheKey(level: .full))?.url, faviconFullURL.url)
    }

    // MARK: - Retrievals Tests
    class MockFinder: FaviconProvider.Finder {

        var faviconFromURL: Favicon?
        var faviconFromWebview: Favicon?

        var findFromWebViewCalled: Int = 0
        var findFromURLCalled: Int = 0
        override func find(with url: URL, completion: @escaping (Result<Favicon, FaviconProvider.FinderError>) -> Void) {
            findFromURLCalled += 1
            guard let faviconToReturn = faviconFromURL else {
                completion(.failure(.dataNotFound))
                return
            }
            completion(.success(faviconToReturn))
        }

        override func find(with webView: WKWebView, url originURL: URL, size: Int,
                           completion:  @escaping (Result<Favicon, FaviconProvider.FinderError>) -> Void) {
            findFromWebViewCalled += 1
            guard let faviconToReturn = faviconFromWebview else {
                completion(.failure(.dataNotFound))
                return
            }
            completion(.success(faviconToReturn))
        }

    }

    class MockWebView: WKWebView {
        var forcedURL: URL?
        override var url: URL? {
            forcedURL
        }
    }

    func buildMockProvider() -> (FaviconProvider, MockFinder) {
        let finder = MockFinder()
        return (FaviconProvider(withFinder: finder), finder)
    }

    func buildMockWebView() -> MockWebView {
        let webView = MockWebView()
        let url = URL(string: "https://beamapp.co")!
        webView.forcedURL = url
        return webView
    }

    func testFaviconFromWebView() throws {
        let webView = buildMockWebView()
        let url = webView.forcedURL!
        let (provider, finder) = buildMockProvider()
        finder.faviconFromWebview = .init(url: url, origin: .webView, image: nil)

        var result: Favicon?
        let exp1 = expectation(description: "get favicon")
        // ask with webview
        provider.favicon(fromURL: url, webView: webView) { f in
            result = f
            exp1.fulfill()
        }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(result, finder.faviconFromWebview)
        XCTAssertEqual(finder.findFromWebViewCalled, 1)
        XCTAssertEqual(finder.findFromURLCalled, 0)
        let exp2 = expectation(description: "get favicon again")
        // ask again with webview
        // should be called once
        provider.favicon(fromURL: url, webView: webView) { f in
            result = f
            exp2.fulfill()
        }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(result, finder.faviconFromWebview)
        XCTAssertEqual(finder.findFromWebViewCalled, 2)
        XCTAssertEqual(finder.findFromURLCalled, 0)
    }

    func testFaviconFromURL() throws {
        let (provider, finder) = buildMockProvider()
        let webView = buildMockWebView()
        let url = webView.forcedURL!
        finder.faviconFromURL = .init(url: url, origin: .url, image: nil)

        var result: Favicon?
        let exp1 = expectation(description: "get favicon")
        // ask from url
        provider.favicon(fromURL: url, webView: nil) { f in
            result = f
            exp1.fulfill()
        }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(result, finder.faviconFromURL)
        XCTAssertEqual(finder.findFromURLCalled, 1)
        let exp2 = expectation(description: "get favicon again")
        // ask again from url
        // should be called once
        provider.favicon(fromURL: url, webView: nil) { f in
            result = f
            exp2.fulfill()
        }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(result, finder.faviconFromURL)
        XCTAssertEqual(finder.findFromURLCalled, 1)
    }

    func testFaviconFromURLThenWebView() throws {
        let (provider, finder) = buildMockProvider()
        let url = URL(string: "https://something.com")!
        finder.faviconFromURL = .init(url: url, origin: .url, image: nil)

        var result: Favicon?
        let exp1 = expectation(description: "get favicon")
        // ask without webview
        provider.favicon(fromURL: url, webView: nil) { f in
            result = f
            exp1.fulfill()
        }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(result, finder.faviconFromURL)
        XCTAssertEqual(finder.findFromURLCalled, 1)

        let webView = buildMockWebView()
        finder.faviconFromWebview = .init(url: url, origin: .webView, image: nil)
        let exp2 = expectation(description: "get favicon again")
        // ask again with webview.
        provider.favicon(fromURL: url, webView: webView) { f in
            guard f != result  else { return }
            result = f
            exp2.fulfill()
        }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(result, finder.faviconFromWebview)
        XCTAssertEqual(finder.findFromWebViewCalled, 1)

        let exp3 = expectation(description: "get favicon again without url")
        // ask again without webview, cache is used.
        provider.favicon(fromURL: url, webView: nil) { f in
            result = f
            exp3.fulfill()
        }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(result, finder.faviconFromWebview)
        XCTAssertEqual(finder.findFromWebViewCalled, 1)
        XCTAssertEqual(finder.findFromURLCalled, 1)
    }

    func testFaviconFromWebViewThenURL() {
        let (provider, finder) = buildMockProvider()
        let url = URL(string: "https://something.com")!
        let webView = buildMockWebView()
        finder.faviconFromWebview = .init(url: url, origin: .webView, image: nil)
        finder.faviconFromURL = .init(url: url, origin: .url, image: nil)

        var result: Favicon?
        let exp1 = expectation(description: "get favicon")
        // ask with webview
        provider.favicon(fromURL: url, webView: webView) { f in
            result = f
            exp1.fulfill()
        }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(result, finder.faviconFromWebview)
        XCTAssertEqual(finder.findFromWebViewCalled, 1)

        let exp2 = expectation(description: "get favicon again")
        // ask again without webview.
        provider.favicon(fromURL: url, webView: nil) { f in
            result = f
            exp2.fulfill()
        }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(result, finder.faviconFromWebview)
        XCTAssertEqual(finder.findFromWebViewCalled, 1)
        XCTAssertEqual(finder.findFromURLCalled, 0)
    }

    func testFaviconFromWebViewWithSubURLs() {
        let mainWebView = buildMockWebView()
        let mainURL = URL(string: "https://beamapp.co/")!
        let mainFavicon = Favicon(url: mainURL, origin: .webView, image: nil)
        mainWebView.forcedURL = mainURL
        let subWebView = buildMockWebView()
        let subURL = URL(string: "https://beamapp.co/some/path/below")!
        let subFavicon = Favicon(url: subURL, origin: .webView, image: nil)
        subWebView.forcedURL = subURL

        let (provider, finder) = buildMockProvider()
        finder.faviconFromWebview = mainFavicon

        var result: Favicon?
        let exp1 = expectation(description: "get main favicon")
        // ask with main webview
        provider.favicon(fromURL: mainURL, webView: mainWebView) { f in
            result = f
            exp1.fulfill()
        }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(result, mainFavicon)
        XCTAssertEqual(finder.findFromWebViewCalled, 1)

        let exp2 = expectation(description: "get sub favicon")
        // ask with sub webview
        // should be called twice. 1. with main favicon, 2. with sub favicon
        finder.faviconFromWebview = subFavicon
        provider.favicon(fromURL: subURL, webView: subWebView) { f in
            result = f
            if f?.url == subURL {
                exp2.fulfill()
            }
        }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(result, subFavicon)
        XCTAssertEqual(finder.findFromWebViewCalled, 2)

        let exp3 = expectation(description: "get sub favicon again")
        // ask again with sub webview
        // should be called once with sub favicon
        finder.faviconFromWebview = subFavicon
        provider.favicon(fromURL: subURL, webView: subWebView) { f in
            result = f
            exp3.fulfill()
        }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(result, subFavicon)
        XCTAssertEqual(finder.findFromWebViewCalled, 3)

        let exp4 = expectation(description: "get main favicon again")
        // ask again with main webview
        // should still return main favicon
        finder.faviconFromWebview = mainFavicon
        provider.favicon(fromURL: mainURL, webView: mainWebView) { f in
            result = f
            exp4.fulfill()
        }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(result, mainFavicon)
        XCTAssertEqual(finder.findFromWebViewCalled, 4)

        let exp5 = expectation(description: "get another sub favicon")
        // ask with another sub url
        // should return the main favicon
        let anotherSubURL = URL(string: "https://beamapp.co/another/path/below")!
        subWebView.forcedURL = anotherSubURL
        finder.faviconFromWebview = mainFavicon
        provider.favicon(fromURL: anotherSubURL, webView: subWebView) { f in
            result = f
            exp5.fulfill()
        }
        waitForExpectations(timeout: 1)
        XCTAssertEqual(result, mainFavicon)
        XCTAssertEqual(finder.findFromWebViewCalled, 5)
        XCTAssertEqual(finder.findFromURLCalled, 0)
    }
}
