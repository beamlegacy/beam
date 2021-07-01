//
//  Download.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 26/05/2021.
//

import Foundation
import Combine

class Download: Identifiable, ObservableObject {

    let downloadURL: URL
    let downloadDate: Date = Date()
    let id: UUID = UUID()

    var fileSystemURL: URL
    var downloadTask: URLSessionDownloadTask?

    var fakeState: URLSessionTask.State?

    var state: URLSessionTask.State {

        if let fakeState = fakeState {
            return fakeState
        }

        return downloadTask?.state ?? .completed
    }

    @Published var progress: Double = 0.0
    @Published var remainingTime: TimeInterval = 0.0
    @Published var totalCount: String?
    @Published var localizedProgressString: String?
    @Published var errorMessage: String?

    private var scope: Set<AnyCancellable> = []
    private lazy var byteFormatter = ByteCountFormatter()

    init(downloadURL: URL, fileSystemURL: URL, downloadTask: URLSessionDownloadTask? = nil) {
        self.downloadURL = downloadURL
        self.fileSystemURL = fileSystemURL
        self.downloadTask = downloadTask
        self.byteFormatter.allowedUnits = [.useGB, .useMB]
        self.byteFormatter.countStyle = .file

        if let task = downloadTask {
            task.progress
                .publisher(for: \.fractionCompleted)
                .throttle(for: 1, scheduler: RunLoop.main, latest: true)
                .receive(on: RunLoop.main)
                .sink(receiveValue: { p in
                    self.progress = p
                    if let total = task.progress.userInfo[ProgressUserInfoKey("NSProgressByteTotalCountKey")] as? Int64 {
                        self.totalCount = self.byteFormatter.string(fromByteCount: total)
                        self.localizedProgressString = task.progress.localizedAdditionalDescription
                    }
                })
                .store(in: &scope)
        }
    }
}

extension Download: Hashable {

    static func == (lhs: Download, rhs: Download) -> Bool {
        lhs.downloadDate == rhs.downloadDate &&
        lhs.downloadURL == rhs.downloadURL &&
        lhs.fileSystemURL == rhs.fileSystemURL
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(downloadDate)
        hasher.combine(downloadURL)
        hasher.combine(fileSystemURL)
    }
}
