//swiftlint:disable file_length
import Foundation
import BeamCore
import Combine

// swiftlint:disable file_length

public class BeamDownloadManager: NSObject, DownloadManager, ObservableObject {

    private let ephemeralDownloadSession = URLSession(configuration: .ephemeral)
    private var fileDownloadSession: URLSession!

    @Published private(set) var downloads: [Download] = []
    @Published private(set) var fractionCompleted: Double = 0.0
    @Published private(set) var ongoingDownload: Bool = false
    @Published var showAlertFileNotFoundForDownload: Download?

    var overallProgress = Progress()
    private(set) var scope = Set<AnyCancellable>()
    private let fileManager = FileManager.default
    private var taskDownloadAssociation = [URLSessionDownloadTask: Download]()

    override init() {
        super.init()
        fileDownloadSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        setProgressPublisher()
    }

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

    func downloadFile(at url: URL, headers: [String: String], suggestedFileName: String?, destinationFoldedURL: URL? = nil) {

        let destinationFolder: URL
        if let desiredFolder = destinationFoldedURL {
            destinationFolder = desiredFolder
        } else {
            guard let downloadFolder = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }
            destinationFolder = downloadFolder
        }

        let downloadedFileName = suggestedFileName ?? url.lastPathComponent
        let fixedName = nonExistingFilename(for: downloadedFileName, at: destinationFolder, shouldAlsoCheckDownloadDoc: true)
        let fileInDownloadURL = destinationFolder.appendingPathComponent(fixedName)

        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        objectWillChange.send()

        _ = destinationFolder.startAccessingSecurityScopedResource()
        let task = fileDownloadSession.downloadTask(with: request)
        let newDownload = Download(downloadURL: url, fileSystemURL: fileInDownloadURL, suggestedFileName: downloadedFileName, downloadTask: task)
        downloads.insert(newDownload, at: 0)

        configure(downloadTask: task, for: newDownload)
        destinationFolder.stopAccessingSecurityScopedResource()

            // We dispatch after to make sure the UI have been updated and that thez download button have been displayed and it's coordinates acquired.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(16)) {
            (NSApp.delegate as? AppDelegate)?.window?.downloadAnimation()
        }
    }

    func downloadFile(from document: BeamDownloadDocument) throws {
        let decoder = PropertyListDecoder()
        guard let downloadData = document.downloadData,
              let recoveredDownload = try? decoder.decode(Download.self, from: downloadData) else { throw BeamDownloadDocumentError.incompleteDownloadDocument }

        if let existingDownloadIndex = downloads.firstIndex(of: recoveredDownload) {
            let existingDownload = downloads[existingDownloadIndex]
            existingDownload.downloadDocument = document
            resume(existingDownload)
        } else {
            downloadFile(at: recoveredDownload.downloadURL, headers: [:], suggestedFileName: recoveredDownload.suggestedFileName)
            if let url = document.fileURL {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    func clearAllFileDownloads() {
        downloads.removeAll { d in
            d.state != .running
        }
    }

    @discardableResult
    func clearFileDownload(_ download: Download) -> Download? {
        guard download.state != .running else { return nil }
        if let index = downloads.firstIndex(of: download) {
            return downloads.remove(at: index)
        }
        return nil
    }

    /// If we can get resume data from the download's document, resume with it. Else, we create a brand new task from scratch
    func resume(_ download: Download) {

        let resumeData = download.downloadDocument?.resumeData
        let resumedTask: URLSessionDownloadTask

        if let resumeData = resumeData {
            resumedTask = fileDownloadSession.downloadTask(withResumeData: resumeData)
        } else {
            resumedTask = fileDownloadSession.downloadTask(with: download.downloadURL)
        }

        download.setDownloadTask(resumedTask)
        configure(downloadTask: resumedTask, for: download)
    }

    /// Cancels the specified download and store the resumeData in the download file if available
    func cancel(_ download: Download) {
        download.downloadTask?.cancel(byProducingResumeData: { resumeData in
            download.downloadDocument?.resumeData = resumeData
            download.saveDownloadDocument()
        })
    }

    func showInFinder(_ download: Download) {
        let downloadedFileURL = download.fileSystemURL
        let tempFileURL = download.downloadDocumentFileURL

        if downloadedFileURL.isFileURL, FileManager.default.fileExists(atPath: downloadedFileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([downloadedFileURL])
        } else if tempFileURL.isFileURL, FileManager.default.fileExists(atPath: tempFileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([tempFileURL])
        } else {
            showAlertFileNotFoundForDownload = download
        }
    }

    func openFile(_ download: Download) {
        let url = download.fileSystemURL
        guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else {
            showAlertFileNotFoundForDownload = download
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - File downloads private funcs

    private func downloadDirectoryURL() throws -> URL {

        if let folder = DownloadFolder(rawValue: PreferencesManager.selectedDownloadFolder)?.sandboxAccessibleUrl {
            return folder
        }
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

    private func nonExistingFilename(for initialName: String, at destination: URL, shouldAlsoCheckDownloadDoc checksDownloadDoc: Bool = false) -> String {

        var completeURL = destination.appendingPathComponent(initialName)
        var completeDownloadDocURL = completeURL.appendingPathExtension(BeamDownloadDocument.downloadDocumentFileExtension)

        let downloadExists = fileManager.fileExists(atPath: completeURL.path)
        let downloadDocumentExists = fileManager.fileExists(atPath: completeDownloadDocURL.path)

        // If we don't have any existing file, use the initial name
        if checksDownloadDoc {
            if !downloadExists && !downloadDocumentExists {
                return initialName
            }
        } else {
            if !downloadExists {
                return initialName
            }
        }

        // If a file with a name already exists, find the first available name
        let nameWithoutExtension = completeURL.deletingPathExtension().lastPathComponent
        let fileExtension = completeURL.pathExtension

        var count = 0
        var newName: String

        repeat {
            count += 1
            newName = "\(nameWithoutExtension)-\(count)"
            completeURL = destination.appendingPathComponent(newName).appendingPathExtension(fileExtension)
            completeDownloadDocURL = completeURL.appendingPathExtension(BeamDownloadDocument.downloadDocumentFileExtension)
        }
        while (fileManager.fileExists(atPath: completeURL.path) || (checksDownloadDoc && fileManager.fileExists(atPath: completeDownloadDocURL.path)))

        return "\(newName).\(fileExtension)"
    }

    private func download(for task: URLSessionDownloadTask) -> Download? {
        return taskDownloadAssociation[task]
    }

    private func addTaskToProgress(task: URLSessionDownloadTask) {
        if overallProgress.isFinished {
            overallProgress = Progress()
            setProgressPublisher()
        }
        overallProgress.totalUnitCount += task.progress.totalUnitCount
        overallProgress.addChild(task.progress, withPendingUnitCount: task.progress.totalUnitCount)
    }

    private func setProgressPublisher() {
        overallProgress
            .publisher(for: \.fractionCompleted)
            .throttle(for: 1, scheduler: RunLoop.current, latest: true)
            .receive(on: RunLoop.main)
            .assign(to: \.fractionCompleted, on: self)
            .store(in: &scope)
    }

    private func setStatePublisher(for task: URLSessionDownloadTask) {
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
    }

    private func configure(downloadTask: URLSessionDownloadTask, for download: Download) {
        addTaskToProgress(task: downloadTask)
        setStatePublisher(for: downloadTask)
        taskDownloadAssociation[downloadTask] = download
        downloadTask.resume()
    }
}

// MARK: - URLSession and download delegates
extension BeamDownloadManager: URLSessionDelegate, URLSessionDownloadDelegate {

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? URLSessionDownloadTask,
              let download = taskDownloadAssociation[downloadTask] else { return }

        if let error = error {
            download.setErrorMessage(error.localizedDescription)
        } else {
            _ = try? downloadDirectoryURL().startAccessingSecurityScopedResource()
            try? fileManager.removeItem(at: download.downloadDocumentFileURL)
            try? downloadDirectoryURL().stopAccessingSecurityScopedResource()
            download.downloadDocument = nil
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }

        guard let download = taskDownloadAssociation[downloadTask] else { return }
        guard let downloadDirectory = try? downloadDirectoryURL() else { return }

        _ = downloadDirectory.startAccessingSecurityScopedResource()
        moveFile(sourceDownload: download, from: location, to: downloadDirectory)
        downloadDirectory.stopAccessingSecurityScopedResource()

        //At the end of the download, re-set the total size of the download.
        //This is to avoid missing size for very small and fast downloads
        download.setDownloadTotalSizeCount(size: downloadTask.countOfBytesReceived)
    }
}

// MARK: - Content-Disposion parser from headers
extension BeamDownloadManager {

    enum ContentDisposition {
        case inline
        case attachment
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
