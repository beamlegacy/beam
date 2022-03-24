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

class FaviconProvider {

    static let shared = FaviconProvider()
    private static let cacheFileName = "favicons"
    private static let cachedIconFromURLLifetime: Int = 30 // 30 days
    private static let cachedIconFromWebViewLifetime: Int = 1 // 1 day
    typealias FaviconProviderHandler = (Favicon?) -> Void

    private let cache: Cache<String, Favicon>
    private var finder = FaviconProvider.Finder()

    private lazy var debouncedSaveToDisk: (() -> Void)? = {
        debounce(delay: .seconds(5)) { [weak self] in
            self?.saveCacheToDisk()
        }
    }()

    init() {
        cache = Cache.diskCache(filename: Self.cacheFileName, countLimit: 200)
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
        let fullURLFavicon = cache[cacheKeyForFullURL(url, size: size)]
        if let fullURLFavicon = fullURLFavicon, !isFaviconExpired(fullURLFavicon) {
            return fullURLFavicon
        }
        let hostFavicon = cache[cacheKeyForURLHost(url, size: size)]
        guard let hostFavicon = hostFavicon, !isFaviconExpired(hostFavicon) else {
            return fullURLFavicon
        }
        return hostFavicon
    }

    private func isFaviconExpired(_ favicon: Favicon) -> Bool {
        hasDateExceedLifetime(favicon.date,
                              lifetime: favicon.origin == .webView ? Self.cachedIconFromWebViewLifetime : Self.cachedIconFromURLLifetime)
    }

    public func registerFavicon(_ favicon: Favicon, for url: URL) {
        updateCache(withIcon: favicon, originURL: url, size: defaultScaledSize)
    }

    private func updateCache(withIcon: Favicon, originURL: URL, size: Int, useFullURL: Bool = false) {
        let cacheKey = useFullURL ? cacheKeyForFullURL(originURL, size: size) : cacheKeyForURLHost(originURL, size: size)
        self.cache[cacheKey] = withIcon
        self.debouncedSaveToDisk?()
    }

    public func clear() {
        cache.removeAllValues()
    }

    private func saveCacheToDisk() {
        Logger.shared.logInfo("FaviconProvider saved cache to disk", category: .favIcon)
        do {
            try self.cache.saveToDisk(withName: Self.cacheFileName)
        } catch {
            Logger.shared.logError("FaviconProvider couldn't save cache to disk. \(error.localizedDescription)", category: .favIcon)
        }
    }

    private let iconDefaultSize: Double = 16
    private var defaultScaledSize: Int {
        Int(CGFloat(iconDefaultSize) * screenScale)
    }

    func clearCache() {
        cache.removeAllValues()
        saveCacheToDisk()
    }

    private func hasDateExceedLifetime(_ date: Date, lifetime: Int) -> Bool {
        date < Calendar.current.date(byAdding: .day, value: -lifetime, to: BeamDate.now) ?? Date(timeIntervalSince1970: 0)
    }

    func favicon(fromURL url: URL, webView: WKWebView? = nil, cacheOnly: Bool = false, handler: @escaping FaviconProviderHandler) {
        let scaledSize = defaultScaledSize
        let cached = getCachedIcon(for: url, size: scaledSize)
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
                var useFullURL = false
                if currentCached != nil && favicon.url != currentCached?.url {
                    // we have a new favicon for this url. let's cache it.
                    useFullURL = true
                }
                if currentCached == nil || currentCached?.origin != .webView || favicon.url != currentCached?.url {
                    self.updateCache(withIcon: favicon, originURL: originURL, size: size, useFullURL: useFullURL)
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
    convenience init(withFinder finder: FaviconProvider.Finder) {
        self.init()
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
            FaviconFinder(url: url, preferredType: .html, preferences: [
                FaviconDownloadType.html: FaviconType.appleTouchIcon.rawValue,
                FaviconDownloadType.ico: "favicon.ico"
            ]).downloadFavicon { result in
                switch result {
                case .success(let icon):
                    let favicon = Favicon(url: icon.url, origin: .url, image: icon.image)
                    completion(.success(favicon))
                case .failure(let error):
                    Logger.shared.logDebug("FaviconFinder Package failure: \(error.localizedDescription)", category: .favIcon)
                    completion(.failure(.dataNotFound))
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

struct Favicon: Codable, Equatable {

    let url: URL
    let width: Double?
    let height: Double?
    let origin: FaviconOrigin
    var date = BeamDate.now
    var image: NSImage?

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
        case origin
        case date
    }

    init(url: URL, width: Double? = nil, height: Double? = nil, origin: FaviconOrigin, image: NSImage? = nil) {
        self.url = url
        self.width = width
        self.height = height
        self.origin = origin
        self.image = image
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        url = try values.decode(URL.self, forKey: .url)
        width = try? values.decode(Double.self, forKey: .width)
        height = try? values.decode(Double.self, forKey: .height)
        date = try values.decode(Date.self, forKey: .date)
        if let imageWrapper = try? values.decode(ImageCodableWrapper.self, forKey: .image) {
            image = imageWrapper.image
        }
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
    }
}
