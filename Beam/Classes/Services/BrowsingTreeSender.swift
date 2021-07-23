//
//  BrowsingTreeSender.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 29/06/2021.
//

import Foundation
import BeamCore

struct BrowsingTreeSendData: Codable {
    let rootCreatedAt: Double //seconds since 1970
    let rootId: UUID
    let userId: UUID
    let data: BrowsingTree

    enum CodingKeys: String, CodingKey {
            case rootCreatedAt = "root_created_at"
            case rootId = "root_id"
            case userId = "user_id"
            case data = "data"
        }
}

typealias DataTaskResult = (Data?, URLResponse?, Error?) -> Void

protocol URLSessionUploadTaskProtocol {
    func resume()
}
extension URLSessionUploadTask: URLSessionUploadTaskProtocol { }

protocol URLSessionProtocol {
    func mockableUploadTask(with: URLRequest, from: Data?, completionHandler: @escaping DataTaskResult) -> URLSessionUploadTaskProtocol
}

extension URLSession: URLSessionProtocol {
    func mockableUploadTask(with: URLRequest, from: Data?, completionHandler: @escaping DataTaskResult) -> URLSessionUploadTaskProtocol {
        return uploadTask(with: with, from: from, completionHandler: completionHandler)
    }
}

struct BrowsingTreeSenderConfig {
    let dataStoreUrl: String
    let dataStoreApiToken: String
}

class BrowsingTreeSender {
    var session: URLSessionProtocol
    var encoder: JSONEncoder
    var url: URL
    private let config: BrowsingTreeSenderConfig

    init?(session: URLSessionProtocol = URLSession.shared, config: BrowsingTreeSenderConfig) {
        guard config.dataStoreApiToken != "$(BROWSING_TREE_ACCESS_TOKEN)",
              config.dataStoreUrl != "$(BROWSING_TREE_URL)",
              let url = URL(string: config.dataStoreUrl)
        else {
            Logger.shared.logError("Browsing tree sender credential issue", category: .general)
            return nil
        }
        self.config = config
        self.url = url
        self.session = session
        encoder = JSONEncoder()
    }

    private var request: URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.dataStoreApiToken, forHTTPHeaderField: "access_token")
        return request
    }

    var userId: UUID {
        if let userIdString = Persistence.BrowsingTree.userId,
           let userId = UUID(uuidString: userIdString) {
            return userId
        }
        let userId = UUID()
        Persistence.BrowsingTree.userId = userId.uuidString
        return userId
    }

    private func payload(browsingTree: BrowsingTree) -> Data? {
        guard let rootFirstEvent = browsingTree.root.events.first else {
            return nil
        }
        let data = BrowsingTreeSendData(
            rootCreatedAt: rootFirstEvent.date.timeIntervalSince1970,
            rootId: browsingTree.root.id,
            userId: userId,
            data: browsingTree
        )
        return try? encoder.encode(data)
    }

    func blockingSend(browsingTree: BrowsingTree) {
        let sem = DispatchSemaphore(value: 0)
        send(browsingTree: browsingTree) {sem.signal()}
        sem.wait()
    }

    func send(browsingTree: BrowsingTree, completion:  @escaping () -> Void = {}) {
        guard let payload = payload(browsingTree: browsingTree),
              !PreferencesManager.isPrivacyFilterEnabled else { return }
        let task = session.mockableUploadTask(with: request, from: payload) { data, response, error in
            if let error = error {
                Logger.shared.logError("Browsing Tree sender Error: \(error)", category: .general)
                completion()
                return
                }
            guard let response = response as? HTTPURLResponse,
                (200...299).contains(response.statusCode) else {
                Logger.shared.logError("Remote data store server error", category: .general)
                completion()
                return
            }
            if let mimeType = response.mimeType,
                mimeType == "application/json",
                let data = data,
                let dataString = String(data: data, encoding: .utf8) {
                Logger.shared.logInfo("Remote data store response \(dataString)", category: .general)
            }
            completion()
        }
        task.resume()
    }
}
