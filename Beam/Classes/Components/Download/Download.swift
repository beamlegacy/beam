//
//  Download.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 26/05/2021.
//

import Foundation
import Combine
import BeamCore

class Download: Identifiable, ObservableObject, Codable {

    let downloadURL: URL
    let downloadDate: Date
    let suggestedFileName: String

    let id: UUID
    var fileSystemURL: URL

    private(set) var downloadTask: URLSessionDownloadTask?

    var downloadDocument: BeamDownloadDocument?
    var downloadDocumentFileURL: URL {
        fileSystemURL.appendingPathExtension(BeamDownloadDocument.downloadDocumentFileExtension)
    }

    var fakeState: URLSessionTask.State?

    var state: URLSessionTask.State {

        if let fakeState = fakeState {
            return fakeState
        }

        return downloadTask?.state ?? .completed
    }

    @Published private(set) var progress: Double = 0.0
    @Published private(set) var remainingTime: TimeInterval = 0.0
    @Published private(set) var totalByteCount: String?
    @Published private(set) var localizedProgressString: String?
    @Published private(set) var errorMessage: String?

    private var scope: Set<AnyCancellable> = []
    private lazy var byteFormatter = ByteCountFormatter()

    init(downloadURL: URL, fileSystemURL: URL, suggestedFileName: String, downloadTask: URLSessionDownloadTask? = nil) {
        self.downloadURL = downloadURL
        self.fileSystemURL = fileSystemURL
        self.suggestedFileName = suggestedFileName

        self.id = UUID()
        self.downloadDate = BeamDate.now

        self.byteFormatter.allowedUnits = [.useGB, .useMB, .useKB]
        self.byteFormatter.countStyle = .file

        if let task = downloadTask {
            setDownloadTask(task)
        }

        do {
            downloadDocument = try BeamDownloadDocument(with: self)
            saveDownloadDocument()
        } catch {
            Logger.shared.logError("Can't serialize download in download document: \(error)", category: .downloader)
        }
    }

    private enum CodingKeys: String, CodingKey { case downloadURL, downloadDate, fileSystemURL, suggestedFileName, id }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        downloadURL = try container.decode(URL.self, forKey: .downloadURL)
        downloadDate = try container.decode(Date.self, forKey: .downloadDate)
        suggestedFileName = try container.decode(String.self, forKey: .suggestedFileName)
        fileSystemURL = try container.decode(URL.self, forKey: .fileSystemURL)
        id = try container.decode(UUID.self, forKey: .id)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(downloadURL, forKey: .downloadURL)
        try container.encode(downloadDate, forKey: .downloadDate)
        try container.encode(suggestedFileName, forKey: .suggestedFileName)
        try container.encode(fileSystemURL, forKey: .fileSystemURL)
        try container.encode(id, forKey: .id)
    }

    func setDownloadTask(_ task: URLSessionDownloadTask) {
        scope.removeAll()
        setErrorMessage(nil)

        self.downloadTask = task

        if let task = downloadTask {
            task.progress
                .publisher(for: \.fractionCompleted)
                .throttle(for: 1, scheduler: RunLoop.main, latest: true)
                .receive(on: RunLoop.main)
                .sink(receiveValue: { [downloadDocumentFileURL, weak self] p in
                    self?.progress = p
                    if let total = task.progress.userInfo[ProgressUserInfoKey("NSProgressByteTotalCountKey")] as? Int64 {
                        self?.setDownloadTotalSizeCount(size: total)
                        self?.localizedProgressString = task.progress.localizedAdditionalDescription
                    }
                    BeamDownloadDocument.setProgress(p, onFileAt: downloadDocumentFileURL)
                })
                .store(in: &scope)
        }
    }

    func setDownloadTotalSizeCount(size: Int64) {
        guard size != -1 else { return }
        DispatchQueue.main.async {
            self.totalByteCount = self.byteFormatter.string(fromByteCount: size)
        }
    }

    func setErrorMessage(_ error: String?) {
        DispatchQueue.main.async {
            self.errorMessage = error
        }
    }

    func saveDownloadDocument() {
            downloadDocument?.save(to: downloadDocumentFileURL, ofType: "co.beamapp.download", for: .saveOperation) { _ in }
    }
}

extension Download: Hashable {

    static func == (lhs: Download, rhs: Download) -> Bool {
        lhs.downloadDate == rhs.downloadDate &&
            lhs.downloadURL == rhs.downloadURL &&
            lhs.fileSystemURL == rhs.fileSystemURL &&
            lhs.suggestedFileName == rhs.suggestedFileName &&
            lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(downloadDate)
        hasher.combine(downloadURL)
        hasher.combine(fileSystemURL)
        hasher.combine(suggestedFileName)
        hasher.combine(id)
    }
}
