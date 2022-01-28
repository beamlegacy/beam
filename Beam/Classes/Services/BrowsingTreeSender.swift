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
    let appSessionId: UUID
    let data: FlatennedBrowsingTree

    enum CodingKeys: String, CodingKey {
            case rootCreatedAt = "root_created_at"
            case rootId = "root_id"
            case userId = "user_id"
            case appSessionId = "app_session_id"
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
    let waitTimeOut: Double
}

class BrowsingTreeSender {
    var session: URLSessionProtocol
    var encoder: JSONEncoder
    var url: URL
    private let config: BrowsingTreeSenderConfig
    let appSessionId: UUID
    public let group = DispatchGroup()

    init?(session: URLSessionProtocol = URLSession.shared, config: BrowsingTreeSenderConfig, appSessionId: UUID) {
        guard config.dataStoreApiToken != "$(BROWSING_TREE_ACCESS_TOKEN)",
              config.dataStoreUrl != "$(BROWSING_TREE_URL)",
              let url = URL(string: config.dataStoreUrl)
        else {
            Logger.shared.logError("Sender credential issue", category: .browsingTreeSender)
            return nil
        }
        self.config = config
        self.url = url
        self.session = session
        self.appSessionId = appSessionId
        encoder = JSONEncoder()
        Logger.shared.logDebug("Sender successful instanciation", category: .browsingTreeSender)
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
        let dataToSend = BrowsingTreeSendData(
            rootCreatedAt: rootFirstEvent.date.timeIntervalSince1970,
            rootId: browsingTree.root.id,
            userId: userId,
            appSessionId: appSessionId,
            data: browsingTree.anonymized.flattened
        )
        return try? encoder.encode(dataToSend)
    }

    func groupSend(browsingTree: BrowsingTree) {
        group.enter()
        send(browsingTree: browsingTree) { [weak self] in self?.group.leave() }
    }

    func groupWait() -> DispatchTimeoutResult {
        let result = group.wait(timeout: .now() + config.waitTimeOut)
        switch result {
        case .timedOut: Logger.shared.logWarning("Some browsing trees may not have been transmitted before timeout", category: .browsingTreeSender)
        case .success: Logger.shared.logInfo("All browsing trees transmitted before timeout", category: .browsingTreeSender)
        }
        return result
    }

    func send(browsingTree: BrowsingTree, completion:  @escaping () -> Void = {}) {
        Logger.shared.logDebug("Browsing tree sending start for tree id: \(browsingTree.root.id)", category: .browsingTreeSender)
        guard let payload = payload(browsingTree: browsingTree),
              !PreferencesManager.isPrivacyFilterEnabled else {
            completion()
            return
        }
        let task = session.mockableUploadTask(with: request, from: payload) { data, response, error in
            if let error = error {
                Logger.shared.logError("Sender error for tree id: \(browsingTree.root.id). \(error.localizedDescription)", category: .browsingTreeSender)
                completion()
                return
                }
            guard let response = response as? HTTPURLResponse,
                (200...299).contains(response.statusCode) else {
                Logger.shared.logError("Remote data store server error for tree id: \(browsingTree.root.id)", category: .browsingTreeSender)
                completion()
                return
            }
            if let mimeType = response.mimeType,
                mimeType == "application/json",
                let data = data,
                let dataString = String(data: data, encoding: .utf8) {
                Logger.shared.logInfo("Remote data store response \(dataString) for tree id: \(browsingTree.root.id)", category: .browsingTreeSender)
            }
            completion()
        }
        task.resume()
    }
}
