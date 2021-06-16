import Foundation
import BeamCore
import Combine

/**
 This is derived from FavIcon's download code
 */
public class BeamDownloadManager: NSObject, DownloadManager, ObservableObject {

    private let ephemeralDownloadSession = URLSession(configuration: .ephemeral)
    private var fileDownloadSession: URLSession!

    @Published private(set) var downloads: [Download]
    @Published private(set) var fractionCompleted: Double
    @Published private(set) var ongoingDownload: Bool

    var overallProgress: Progress
    private(set) var scope: Set<AnyCancellable>
    private let fileManager = FileManager.default
    private var taskDownloadAssociation: [URLSessionDownloadTask: Download]

    override init() {
        downloads = []
        fractionCompleted = 0.0
        overallProgress = Progress()
        scope = []
        taskDownloadAssociation = [:]
        ongoingDownload = false
        super.init()

        fileDownloadSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        setProgressPublisher()
    }

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

    func downloadFile(at url: URL, headers: [String: String], destinationFoldedURL: URL? = nil) {

        let destinationFolder: URL
        if let desiredFolder = destinationFoldedURL {
            destinationFolder = desiredFolder
        } else {
            guard let downloadFolder = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }
            destinationFolder = downloadFolder
        }

        let downloadedFileName = url.lastPathComponent
        let fileInDownloadURL = destinationFolder.appendingPathComponent(downloadedFileName)

        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let task = fileDownloadSession.downloadTask(with: request)

        objectWillChange.send()

        let newDownload = Download(downloadURL: url, fileSystemURL: fileInDownloadURL, downloadTask: task)
        downloads.append(newDownload)

        if overallProgress.isFinished {
            overallProgress = Progress()
            setProgressPublisher()
        }
        overallProgress.totalUnitCount += task.progress.totalUnitCount
        overallProgress.addChild(task.progress, withPendingUnitCount: task.progress.totalUnitCount)

        taskDownloadAssociation[task] = newDownload

        task
            .publisher(for: \.state)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let running = self?.downloads.filter({ $0.state == .running }) else { return }
                if running.isEmpty {
                    self?.ongoingDownload = false
                } else {
                    self?.ongoingDownload = true
                }
            }.store(in: &scope)

        task.resume()
    }

    func clearFileDownloads() {
        downloads.removeAll { d in
            d.state != .running
        }
    }

    private func downloadDirectoryURL() throws -> URL {
        guard let downloadFolder = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            throw DownloadManagerError.fileError
        }
        return downloadFolder
    }

    private func moveFile(sourceDownload: Download, from source: URL, to destination: URL) {

        let originalFileName = sourceDownload.fileSystemURL.lastPathComponent
        let updatedFileName = nonExistingFilename(for: originalFileName, at: destination)
        let fileWithNameAtDestination = destination.appendingPathComponent(updatedFileName)

        sourceDownload.fileSystemURL = fileWithNameAtDestination

        do {
            try fileManager.moveItem(at: source, to: fileWithNameAtDestination)
        } catch {
            Logger.shared.logDebug(error.localizedDescription)
        }
    }

    private func nonExistingFilename(for initialName: String, at destination: URL) -> String {

        var completeURL = destination.appendingPathComponent(initialName)
        guard fileManager.fileExists(atPath: completeURL.path) else { return initialName }

        let nameWithoutExtension = completeURL.deletingPathExtension().lastPathComponent
        let fileExtension = completeURL.pathExtension

        var count = 0
        var newName: String

        repeat {
            count += 1
            newName = "\(nameWithoutExtension)-\(count)"
            completeURL = destination.appendingPathComponent(newName).appendingPathExtension(fileExtension)
        }
        while fileManager.fileExists(atPath: completeURL.path)

        return "\(newName).\(fileExtension)"
    }

    private func download(for task: URLSessionDownloadTask) -> Download? {
        return taskDownloadAssociation[task]
    }

    private func setProgressPublisher() {
        overallProgress
            .publisher(for: \.fractionCompleted)
            .throttle(for: 1, scheduler: RunLoop.current, latest: true)
            .receive(on: RunLoop.main)
            .assign(to: \.fractionCompleted, on: self)
            .store(in: &scope)
    }
}

extension BeamDownloadManager: URLSessionDelegate, URLSessionDownloadDelegate {

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? URLSessionDownloadTask,
              let download = taskDownloadAssociation[downloadTask] else { return }
        download.errorMessage = error?.localizedDescription
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }

        guard let download = taskDownloadAssociation[downloadTask] else { return }
        guard let downloadDirectory = try? downloadDirectoryURL() else { return }

        moveFile(sourceDownload: download, from: location, to: downloadDirectory)
    }
}
