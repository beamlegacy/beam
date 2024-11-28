//
//  FaviconProvider.swift
//  Beam
//
//  Created by Remi Santos on 12/03/2021.
//

import Foundation
import FaviconFinder
import BeamCore
import WebKit

/**
 * Manage favicon fetching and caching.
 *
 * Favicon can be of two different sources:
 * - from the webView html content that we loaded. Using JS Script.
 * - from a URL, using FaviconFinder.
 *
 * When caching a favicon for a URL, we can store it at three different levels: `host`, `path` or `full URL`.
 * Depending on what's already in the cache.
 */
final class FaviconProvider {

    private static let cacheFileName = "favicons"
    private static let cachedIconFromURLLifetime: Int = 30 // 30 days
    private static let cachedIconFromWebViewLifetime: Int = 1 // 1 day
    typealias FaviconProviderHandler = (Favicon?) -> Void

    private let cache: FaviconCache
    private var finder = FaviconProvider.Finder()

    private lazy var debouncedSaveToDisk: (() -> Void)? = {
        debounce(delay: .seconds(5)) { [weak self] in
            self?.saveCacheToDisk()
        }
    }()

    init(withCache cache: FaviconCache? = nil) {
        self.cache = cache ?? FaviconCache.diskCache(filename: Self.cacheFileName, countLimit: 10000)
    }

    private var screenScale: CGFloat {
        NSScreen.main?.backingScaleFactor ?? 2
    }

    private func cacheKeyForURLHost(_ url: URL, size: Int) -> String {
        return (url.host ?? url.urlStringWithoutScheme) + "-\(size)"
    }

    private func cacheKeyForFullURL(_ url: URL, size: Int) -> String {
        return url.urlStringWithoutScheme + "-\(size)"
    }

    private func getCachedIcon(for url: URL, size: Int) -> Favicon? {
        let keys = FaviconLevelsKeys(url: url, size: size)

        // Level 1: Full URL
        let fullURLFavicon = cache[keys.cacheKey(level: .full)]
        if let fullURLFavicon = fullURLFavicon, !isFaviconExpired(fullURLFavicon) {
            return fullURLFavicon
        }

        // Level 2: URL with Path
        let pathURLFavicon = cache[keys.cacheKey(level: .path)]
        if let pathURLFavicon = pathURLFavicon, !isFaviconExpired(pathURLFavicon) {
            return pathURLFavicon
        }

        // Level 3: Host only
        let hostFavicon = cache[keys.cacheKey(level: .host)]
        if let hostFavicon = hostFavicon, !isFaviconExpired(hostFavicon) {
            return hostFavicon
        }

        return fullURLFavicon ?? pathURLFavicon ?? hostFavicon
    }

    private func isFaviconExpired(_ favicon: Favicon) -> Bool {
        hasDateExceedLifetime(favicon.date,
                              lifetime: favicon.origin == .webView ? Self.cachedIconFromWebViewLifetime : Self.cachedIconFromURLLifetime)
    }

    private func updateCache(withIcon icon: Favicon, originURL: URL, size: Int) {
        var eraseFullKeyCache = false

        let keys = FaviconLevelsKeys(url: originURL, size: size)
        let hostKey = keys.cacheKey(level: .host)
        let pathKey = keys.cacheKey(level: .path)
        let fullKey = keys.cacheKey(level: .full)
        let newIconIsFromWebView = icon.origin == .webView

        defer {
            if eraseFullKeyCache {
                self.cache.removeValue(forKey: fullKey)
            }
            self.debouncedSaveToDisk?()
        }
        if fullKey == hostKey {
            if newIconIsFromWebView || self.cache[hostKey]?.origin != .webView {
                self.cache[hostKey] = icon
            }
            return
        }
        let cacheHost = self.cache[hostKey]
        if cacheHost == nil || cacheHost?.url == icon.url {
            eraseFullKeyCache = true
            self.cache[hostKey] = icon
            return
        }

        if fullKey == pathKey {
            if newIconIsFromWebView || self.cache[pathKey]?.origin != .webView {
                self.cache[pathKey] = icon
            }
            return
        }

        let cachePath = self.cache[pathKey]
        if cachePath == nil || cachePath?.url == icon.url {
            eraseFullKeyCache = true
            self.cache[pathKey] = icon
            return
        }

        if newIconIsFromWebView || self.cache[fullKey]?.origin != .webView {
            self.cache[fullKey] = icon
        }
    }

    public func clear() {
        cache.removeAllValues()
    }

    private func saveCacheToDisk() {
        do {
            try self.cache.saveToDisk(withName: Self.cacheFileName)
            Logger.shared.logInfo("FaviconProvider saved cache to disk", category: .favIcon)
        } catch {
            Logger.shared.logError("FaviconProvider couldn't save cache to disk. \(error.localizedDescription)", category: .favIcon)
        }
    }

    private let iconDefaultSize: Double = 16
    private var defaultScaledSize: Int {
        Int(CGFloat(iconDefaultSize) * screenScale)
    }

    func clearCache(_ afterDate: Date? = nil) {
        if let afterDate = afterDate {
            cache.allEntries.forEach { entry in
                if entry.value.date > afterDate {
                    cache.removeValue(forKey: entry.key)
                }
            }
        } else {
            cache.removeAllValues()
        }
        saveCacheToDisk()
    }

    private func hasDateExceedLifetime(_ date: Date, lifetime: Int) -> Bool {
        date < Calendar.current.date(byAdding: .day, value: -lifetime, to: BeamDate.now) ?? Date(timeIntervalSince1970: 0)
    }

    func favicon(fromURL url: URL, webView: WKWebView? = nil, cachePolicy: CachePolicy = .default, handler: @escaping FaviconProviderHandler) {
        let scaledSize = defaultScaledSize
        let cacheOnly = cachePolicy == .cacheOnly
        let cached = cachePolicy == .skipCache ? nil : getCachedIcon(for: url, size: scaledSize)
        if let cached = cached {
            handler(cached)
            if cacheOnly || (webView == nil && !hasDateExceedLifetime(cached.date, lifetime: Self.cachedIconFromURLLifetime)) {
                return
            }
        } else if cacheOnly {
            handler(nil)
            return
        }

        if let webView = webView {
            retrieveFavicon(fromWebView: webView, url: url, currentCached: cached) { f in
                if (f != nil && cached != f) || cached == nil {
                    handler(f)
                }
            }
        } else {
            retrieveFavicon(fromURL: url, handler: handler)
        }
    }

    // MARK: - From Web URL
    private func retrieveFavicon(fromURL url: URL, handler: @escaping FaviconProviderHandler) {
        let scaledSize = defaultScaledSize
        finder.find(with: url) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let favicon):
                self.updateCache(withIcon: favicon, originURL: url, size: scaledSize)
                handler(favicon)
            case .failure:
                handler(nil)
            }
        }
    }

    // MARK: - From WebView
    private func retrieveFavicon(fromWebView webView: WKWebView, url originURL: URL,
                                 currentCached: Favicon?,
                                 handler: @escaping FaviconProviderHandler) {
        let size = self.defaultScaledSize
        finder.find(with: webView, url: originURL, size: size) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let favicon):
                if currentCached == nil || currentCached?.origin != .webView || favicon.url != currentCached?.url {
                    self.updateCache(withIcon: favicon, originURL: originURL, size: size)
                }
                handler(favicon)
            case .failure:
                handler(nil)
            }
        }
    }
}

extension FaviconProvider {

    /// Provide a mock finder for tests
    convenience init(withCache cache: FaviconCache? = nil, withFinder finder: FaviconProvider.Finder) {
        self.init(withCache: cache)
        self.finder = finder
    }

    enum FinderError: Error {
        case urlNotFound
        case dataNotFound
    }

    /// Internal favicon getter from url or webview.
    /// Separated from Provider to allow mocking
    class Finder {

        func find(with url: URL, completion:  @escaping (Result<Favicon, FinderError>) -> Void) {
            Task {
                var url = url
                if url.scheme == nil {
                    url = URL(string: "https://\(url.absoluteString)") ?? url
                }
                let finder = FaviconFinder(url: url, configuration: .init(preferredSource: .html, preferences: [
                    FaviconSourceType.html: FaviconFormatType.appleTouchIcon.rawValue,
                    FaviconSourceType.ico: "favicon.ico"
                ]))
                do {
                    let urls = try await finder.fetchFaviconURLs()
                    if let url = urls.first {
                        let icon = try await url.download()
                        let favicon = Favicon(url: icon.url.source, origin: .url, image: icon.image?.image)
                        completion(.success(favicon))
                    } else {
                        completion(.failure(.urlNotFound))
                    }
                } catch {
                    Logger.shared.logError("FaviconFinder Package failure: \(error.localizedDescription)", category: .favIcon)
                    completion(.failure(.urlNotFound))
                }
            }
        }

        func find(with webView: WKWebView, url originURL: URL, size: Int, completion:  @escaping (Result<Favicon, FinderError>) -> Void) {
            webView.evaluateJavaScript(Self.GET_FAVICON_SCRIPT) { [weak self] (result, _) in
                guard let self = self, let faviconsDics = result as? [NSDictionary] else {
                    completion(.failure(.urlNotFound))
                    return
                }

                let favicons: [Favicon] = faviconsDics.compactMap { faviconDic in
                    guard let urlString = faviconDic["url"] as? String,
                          let url = URL(string: urlString, relativeTo: originURL)
                    else { return nil }
                    var width: Double?
                    var height: Double?
                    let sizeStrings = (faviconDic["sizes"] as? String)?.components(separatedBy: "x") ?? []
                    if sizeStrings.count == 2 {
                        width = Double(sizeStrings[0])
                        height = Double(sizeStrings[1])
                    }
                    return Favicon(url: url, width: width, height: height, origin: .webView)
                }

                guard let favicon = self.pickBestFavicon(favicons, forSize: size) else {
                    completion(.failure(.urlNotFound))
                    return
                }
                self.getData(from: favicon.url) { data, _, _ in
                    guard let data = data, let image = NSImage(data: data) else {
                        completion(.failure(.dataNotFound))
                        return
                    }
                    var updatedFavicon = favicon
                    updatedFavicon.image = image
                    completion(.success(updatedFavicon))
                }
            }
        }

        /**
         Policy to pick the best favicon as of 21/10/2021:
         - prefer a .png with the largest size not bigger than 3x the desired size
         - or an .ico with no size provided
         - or the last specified
         */
        func pickBestFavicon(_ favicons: [Favicon], forSize: Int) -> Favicon? {
            var bestICO: Favicon?
            var bestOther: Favicon?
            for f in favicons {
                switch f.type {
                case .ico:
                    if f.width == nil {
                        bestICO = f
                    }
                default:
                    guard let bestOtherWidth = bestOther?.width else {
                        if f.width != nil {
                            bestOther = f
                        }
                        continue
                    }
                    guard let fWidth = f.width, fWidth > bestOtherWidth, Int(fWidth) <= forSize * 3 else { continue }
                    bestOther = f
                }
            }
            return (bestOther?.width != nil ? bestOther : bestICO) ?? favicons.last
        }

        private func getData(from url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
            URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
        }

        private static let GET_FAVICON_SCRIPT = """
            var favicons = [];
            var nodeList = document.querySelectorAll("link[rel='icon'], link[rel='shortcut icon']")

            for (var i = 0; i < nodeList.length; i++) {
                const node = nodeList[i];
                favicons.push({
                    url: node.getAttribute('href'),
                    sizes: node.getAttribute('sizes')
                });
            }
            favicons;
        """
    }
}

extension FaviconProvider {
    enum CachePolicy {
        case cacheOnly
        case skipCache
        case `default`
    }
}

extension FaviconProvider {
    struct FaviconLevelsKeys {
        let url: URL
        let size: Int

        enum Level {
            case host, path, full
        }

        func cacheKey(level: Level) -> String {
            switch level {
            case .host: return cacheKeyForURLHost
            case .path: return cacheKeyForURLWithPath
            case .full: return cacheKeyForFullURL
            }
        }

        private func urlHost(_ url: URL) -> String {
            (url.urlWithScheme.host ?? url.urlStringWithoutScheme)
        }

        /// Includes URL host (both top level domain and subdomain)
        private var cacheKeyForURLHost: String {
            urlHost(url) + "-\(size)"
        }

        /// Includes URL host + path
        private var cacheKeyForURLWithPath: String {
            let url = url.urlWithScheme
            var path = url.path
            if !url.pathExtension.isEmpty {
                path = url.deletingLastPathComponent().path
            }
            if path == "/" {
                path = ""
            }
            return urlHost(url) + path + "-\(size)"
        }

        /// Using full URL, subdomain
        private var cacheKeyForFullURL: String {
            url.urlStringByRemovingUnnecessaryCharacters + "-\(size)"
        }
    }
}

struct Favicon: Codable, Equatable {

    var url: URL
    let width: Double?
    let height: Double?
    let origin: FaviconOrigin
    var date = BeamDate.now
    var image: NSImage? {
        didSet {
            guard image != nil && url.absoluteString.starts(with: "data:image"), let imageId = imageId else { return }
            // don't store base64 image in URL, image will be stored aside with imageId.
            // replacing with fake imageId URL
            self.url = URL(string: "data:favicon/png;\(imageId.uuidString)") ?? url
        }
    }
    /// derived from the url
    private(set) var imageId: UUID?

    enum FaviconOrigin: Int, Codable {
        case webView
        case url
    }

    enum ImageType {
        case png
        case ico
        case unknown
    }
    var type: ImageType {
        guard let ext = url.lastPathComponent.split(separator: ".").last else {
            return .unknown
        }
        switch ext.lowercased() {
        case "png":
            return .png
        case "ico":
            return .ico
        default:
            return .unknown
        }
    }

    private enum CodingKeys: CodingKey {
        case url
        case width
        case height
        case image
        case imageId
        case origin
        case date
    }

    init(url: URL, width: Double? = nil, height: Double? = nil, origin: FaviconOrigin,
         image: NSImage? = nil) {
        self.url = url
        self.width = width
        self.height = height
        self.origin = origin
        self.image = image
        self.imageId = UUID.v5(name: url.absoluteString, namespace: .url)
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        url = try values.decode(URL.self, forKey: .url)
        width = try values.decodeIfPresent(Double.self, forKey: .width)
        height = try values.decodeIfPresent(Double.self, forKey: .height)
        date = try values.decode(Date.self, forKey: .date)
        if let imageWrapper = try? values.decode(ImageCodableWrapper.self, forKey: .image) {
            image = imageWrapper.image
        }
        imageId = try values.decodeIfPresent(UUID.self, forKey: .imageId)
        origin = try values.decode(FaviconOrigin.self, forKey: .origin)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(origin, forKey: .origin)
        try container.encode(date, forKey: .date)
        if let width = width, let height = height {
            try container.encode(width, forKey: .width)
            try container.encode(height, forKey: .height)
        }
        if let image = image {
            try container.encode(ImageCodableWrapper(image: image), forKey: .image)
        }
        if let imageId = imageId {
            try container.encode(imageId, forKey: .imageId)
        }
    }
}
