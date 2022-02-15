//swiftlint:disable file_length
import Foundation
import BeamCore
import Combine
import WebKit

// swiftlint:disable file_length

/// Handles the list of file downloads triggered by webview navigation actions, and one-off image downloads from
/// Point-and-Shoot.
public class BeamDownloadManager: NSObject, DownloadManager, ObservableObject {

    private let ephemeralDownloadSession = URLSession(configuration: .ephemeral)
    private let fileManager = FileManager.default

    /// The list of downloads initiated by webview navigation actions.
    @Published private(set) var downloadList = DownloadList<DownloadItem>()

    // MARK: - P&S downloads
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func downloadURLs(_ urls: [URL], headers: [String: String], completion: @escaping ([DownloadManagerResult]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var results = [(index: Int, result: DownloadManagerResult)]()
        let addResult: (Int, DownloadManagerResult) -> Void = { (index: Int, result: DownloadManagerResult) in
            DispatchQueue.main.async {
                results.append((index: index, result: result))
            }
        }
        for (index, url) in urls.enumerated() {
            dispatchGroup.enter()
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            let task = ephemeralDownloadSession.dataTask(with: request) { data, response, error in
                defer {
                    dispatchGroup.leave()
                }
                guard error == nil else {
                    addResult(index, .error(error!))
                    return
                }
                guard let response = response else {
                    addResult(index, .error(DownloadManagerError.invalidResponse))
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 404 {
                        addResult(index, .error(DownloadManagerError.notFound))
                        return
                    }
                    guard (200...299).contains(httpResponse.statusCode) else {
                        addResult(index, .error(DownloadManagerError.serverError(code: httpResponse.statusCode)))
                        return
                    }
                }
                guard let data = data else {
                    addResult(index, .error(DownloadManagerError.emptyResponse))
                    return
                }
                let mimeType = response.mimeType ?? "application/octet-stream"
                let encoding: String.Encoding = {
                    if let textEncodingName = response.textEncodingName,
                       let parsedEncoding = parseStringEncoding(textEncodingName) {
                        return parsedEncoding
                    }
                    return .utf8
                }()
                if mimeType.starts(with: "text/") || mimeType == "application/json" {
                    guard let text = String(data: data, encoding: encoding) else {
                        addResult(index, .error(DownloadManagerError.invalidTextResponse))
                        return
                    }
                    addResult(index, .text(value: text, mimeType: mimeType, actualURL: response.url!))
                    return
                } else {
                    addResult(index, .binary(data: data, mimeType: mimeType, actualURL: response.url!))
                    return
                }
            }
            task.resume()
        }
        dispatchGroup.notify(queue: .main) {
            let sortedResults = results.sorted(by: { $0.index < $1.index }).map { $0.result }
            completion(sortedResults)
        }
    }

    func downloadURL(_ url: URL, headers: [String: String], completion: @escaping (DownloadManagerResult) -> Void) {
        downloadURLs([url], headers: headers) { results in
            completion(results.first!)
        }
    }

    func downloadImage(_ src: URL, pageUrl: URL, completion: @escaping ((Data, String)?) -> Void) {
        let headers = ["Referer": pageUrl.absoluteString]
        self.downloadURLs([src], headers: headers) { results in
            if let result = results.first {
                guard case .binary(let data, let mimeType, _) = result,
                      data.count > 0 else {
                    completion(nil)
                    return
                }
                completion((data, mimeType))
            }
        }
    }

    /// Downloads base64 image string
    /// `data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAoGCBYTExcVFRUYGBcZGxsaGhoaG`
    /// - Parameters:
    ///   - base64String: String including the type
    ///   - pageUrl: url of source page
    func downloadBase64(_ base64String: String, pageUrl: URL) -> (Data, String)? {
        let array = base64String.split(separator: ",")

        guard array.count >= 2 else {
            // only continue with 2 array parts
            return nil
        }

        let mimeType = array[0].replacingOccurrences(of: "data:", with: "", options: [.anchored])
        let base64 = String(array[1])

        guard let data = Data(base64Encoded: base64),
              data.count > 0 else {
            // return if we have no data
            return nil
        }

        return (data, mimeType)
    }

    // MARK: - File downloads control

    /// Monitors a download initiated by a webview navigation action, and write a download document to disk.
    func download(_ download: WKDownload) {
        guard let destinationDirectoryURL = destinationDirectoryURL() else {
            Logger.shared.logError("Can't retrieve a Downloads directory", category: .downloader)
            return
        }

        let downloadItem = DownloadItem(
            downloadProxy: WebKitDownloadProxy(download),
            destinationDirectoryURL: destinationDirectoryURL
        )

        downloadList.addDownload(downloadItem)

        // We dispatch after to make sure the UI have been updated and that thez download button have been displayed and it's coordinates acquired.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(16)) {
            (NSApp.delegate as? AppDelegate)?.window?.downloadAnimation()
        }
    }

    /// Attempts to restart a download from a download document.
    func downloadFile(from document: BeamDownloadDocument) throws {
        let downloadItem = try DownloadItem(
            downloadProxy: WebKitDownloadProxy(),
            downloadDocument: document
        )

        // Currently we don't explicitly cancel running downloads before quitting the app, meaning we don't retrieve
        // fresh resume data before downloads are interrupted. As a result, resuming those downloads later will
        // generate corrupted files.

        // Until downloads are canceled on quit, we need to delete the temporary downloaded files in cache when
        // opening download documents on disk. Therefore, we restart downloads instead of resuming them for now.

        // try downloadItem.resume()
        try downloadItem.restart()

        downloadList.addDownload(downloadItem)
    }

    private func destinationDirectoryURL() -> URL? {
        if let preferredDownloadDirectory = DownloadFolder(rawValue: PreferencesManager.selectedDownloadFolder)?.sandboxAccessibleUrl {
            return preferredDownloadDirectory
        }

        if let systemDownloadsDirectory = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            return systemDownloadsDirectory
        }

        return nil
    }

}

// MARK: - Content-Disposion parser from headers
extension BeamDownloadManager {

    enum ContentDisposition {
        case inline
        case attachment
    }

    enum ContentType {
        case forceDownload
    }

    static func contentDisposition(from headers: [AnyHashable: Any]) -> ContentDisposition? {

        guard let disposition = headers["Content-Disposition"] as? String else { return nil }
        if disposition.hasPrefix("inline") {
            return .inline
        } else if disposition.hasPrefix("attachment") {
            return .attachment
        } else {
            return nil
        }

    }

    static func contentType(from headers: [AnyHashable: Any]) -> ContentType? {
        guard let contentType = headers["Content-Type"] as? String else { return nil }
        if contentType.hasPrefix("application/force-download") {
            return .forceDownload
        }

        return nil
    }

}

// MARK: - Animation
extension BeamDownloadManager {
    static func flyingAnimationGroup(origin: CGPoint, destination: CGPoint) -> CAAnimationGroup {

        let positionX = CAKeyframeAnimation(keyPath: "position.x")
        positionX.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        positionX.values = [origin.x, origin.x, destination.x]
        positionX.keyTimes = [0.0, 0.16, 0.7]
        positionX.duration = 1.0

        let animationY = CAKeyframeAnimation(keyPath: "position.y")
        animationY.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animationY.values = [origin.y, destination.y]
        animationY.keyTimes = [0.0, 0.6]
        animationY.duration = 1.0

        let scale = CABasicAnimation(keyPath: "transform")
        scale.valueFunction = CAValueFunction(name: CAValueFunctionName.scale)
        scale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        scale.fromValue = [1.0, 1.0, 1.0]
        scale.toValue = [0.05, 0.05, 0.05]
        scale.duration = 1.0

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        fade.values = [1.0, 1.0, 0.0, 0.0]
        fade.keyTimes = [0.0, 0.6, 0.8, 1.0]
        fade.duration = 1.0

        let group = CAAnimationGroup()
        group.duration = 1.0
        group.animations = [positionX, animationY, scale, fade]

        return group
    }
}
