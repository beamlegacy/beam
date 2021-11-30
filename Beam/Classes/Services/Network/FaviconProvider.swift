//
//  FaviconProvider.swift
//  Beam
//
//  Created by Remi Santos on 12/03/2021.
//

import Foundation
import FavIcon
import BeamCore

final class FaviconProvider {

    static let shared = FaviconProvider()
    private static let cacheFileName = "favicons"
    private static let cachedIconFromURLLifetime: Int = 30 // 30 days
    private static let cachedIconFromWebViewLifetime: Int = 1 // 1 day
    typealias FaviconProviderHandler = (NSImage?) -> Void

    private let cache: Cache<String, Favicon>

    private lazy var debouncedSaveToDisk: (() -> Void)? = {
        debounce(delay: .seconds(5)) { [weak self] in
            self?.saveCacheToDisk()
        }
    }()

    init() {
        if let recoveredCache = try? Cache<String, Favicon>.recoverFromDisk(withName: Self.cacheFileName) {
            cache = recoveredCache
        } else {
            cache = Cache<String, Favicon>(countLimit: 200)
        }
    }

    private var screenScale: CGFloat {
        NSScreen.main?.backingScaleFactor ?? 2
    }

    private func cacheKeyForURL(_ url: URL, size: Int) -> String {
        return (url.host ?? url.urlStringWithoutScheme) + "-\(size)"
    }

    private func updateCache(withIcon: Favicon, for cacheKey: String) {
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
        let cacheKey = cacheKeyForURL(url, size: scaledSize)
        var handlerWasCalled = false
        if let cached = cache[cacheKey] {
            handlerWasCalled = true
            handler(cached.image)
            // if cached is old or not from webView, let's still retrieve a new one
            var cacheShouldBeReplaced = false
            if webView != nil {
                cacheShouldBeReplaced = cached.origin != .webView || hasDateExceedLifetime(cached.date, lifetime: Self.cachedIconFromWebViewLifetime)
            } else if hasDateExceedLifetime(cached.date, lifetime: Self.cachedIconFromURLLifetime) {
                cacheShouldBeReplaced = true
            }
            if !cacheShouldBeReplaced {
                return
            }
        } else if cacheOnly {
            handler(nil)
            return
        }
        if let webView = webView {
            retrieveFavicon(fromWebView: webView) { image in
                if image != nil || !handlerWasCalled {
                    handler(image)
                }
            }
        } else {
            retrieveFavicon(fromURL: url, handler: handler)
        }
    }

    // MARK: - From Web URL
    private func retrieveFavicon(fromURL url: URL, handler: @escaping FaviconProviderHandler) {
        let scaledSize = defaultScaledSize
        do {
            try FavIcon.downloadPreferred(url, width: scaledSize, height: scaledSize) { [weak self] result in
                if case let .success(image) = result {
                    guard let self = self else { return }
                    let cacheKey = self.cacheKeyForURL(url, size: scaledSize)
                    let icon = Favicon(url: url, origin: .url, image: image)
                    self.updateCache(withIcon: icon, for: cacheKey)
                    handler(image)
                    return
                } else if case let .failure(error) = result {
                    Logger.shared.logDebug("FaviconProvider failure: \(error.localizedDescription)", category: .favIcon)
                }
                handler(nil)
            }
        } catch let error {
            Logger.shared.logDebug("FaviconProvider error: \(error.localizedDescription)", category: .favIcon)
            handler(nil)
        }
    }

    // MARK: - From WebView
    private func retrieveFavicon(fromWebView webView: WKWebView, handler: @escaping FaviconProviderHandler) {

        let originUrl = webView.url
        webView.evaluateJavaScript(Self.GET_FAVICON_SCRIPT) { [weak self] (result, _) in
            guard let self = self, let faviconsDics = result as? [NSDictionary] else {
                handler(nil)
                return
            }

            let favicons: [Favicon] = faviconsDics.compactMap { faviconDic in
                guard let urlString = faviconDic["url"] as? String,
                let url = URL(string: urlString, relativeTo: originUrl)
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

            let size = self.defaultScaledSize
            guard let favicon = self.pickBestFavicon(favicons, forSize: size), let originUrl = originUrl else {
                handler(nil)
                return
            }
            self.getData(from: favicon.url) { [weak self] data, _, _ in
                guard let self = self, let data = data, let image = NSImage(data: data) else {
                    handler(nil)
                    return
                }
                let cacheKey = self.cacheKeyForURL(originUrl, size: size)
                var updatedFavicon = favicon
                updatedFavicon.image = image
                self.updateCache(withIcon: updatedFavicon, for: cacheKey)
                handler(image)
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
        var nodeList = document.getElementsByTagName('link');
        for (var i = 0; i < nodeList.length; i++) {
            if((nodeList[i].getAttribute('rel').toLowerCase() == 'icon')||(nodeList[i].getAttribute('rel').toLowerCase() == 'shortcut icon')) {
                const node = nodeList[i];
                favicons.push({
                    url: node.getAttribute('href'),
                    sizes: node.getAttribute('sizes')
                });
            }
        }
        favicons;
    """
}

struct Favicon: Codable {

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
