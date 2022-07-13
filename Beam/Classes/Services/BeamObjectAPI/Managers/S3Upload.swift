//
//  S3Upload.swift
//  Beam
//
//  Created by Adrian Tofan on 07/07/2022.
//

import Foundation
import AsyncHTTPClient
import NIOCore
import NIO

// Enqueues a upload task on the given task group
protocol S3Upload {
    func makeOperation(uploadUrl: String, headers: [String: String], data: Data) -> (@Sendable () async -> Error?)
    var kind: String {get}
}

extension S3Upload {
    static func new() -> S3Upload {
        (Configuration.directUploadNIO && Configuration.env != .test)  ?
        S3UploadURLNIO.init(concurrentHTTP1ConnectionsPerHostSoftLimit: 75):
        S3UploadURLSession.init()
    }
}

// Test recoding and playback used in tests does not work with NIO ¯\_(ツ)_/¯
// implements S3UploadTask by using NSURLSession via BeamObjectRequest
class S3UploadURLSession: S3Upload {
    let request: BeamObjectRequest
    let kind = "NSURLSession"

    init(request: BeamObjectRequest) {
        self.request = request
    }

    convenience init() {
        self.init(request: BeamObjectRequest.init())
    }

    func makeOperation(uploadUrl: String, headers: [String: String], data: Data) -> (@Sendable () async -> Error?) {
        let req = self.request
        return {
            do {
                try await req.sendDataToUrl(urlString: uploadUrl,
                                            putHeaders: headers,
                                            data: data)
                return nil
            } catch {
                return error
            }
        }
    }
}

// implements S3UploadTask by using NIO HTTPClient managed my NIOContextManager
class S3UploadURLNIO: S3Upload {
    let nioContextManager: NIOContextManager
    let kind = "NIOHTTPClient"

    init(context: NIOContextManager) {
        self.nioContextManager = context
    }

    convenience init(concurrentHTTP1ConnectionsPerHostSoftLimit: Int) {
        self.init(context: NIOContextManager.init(concurrentHTTP1ConnectionsPerHostSoftLimit: concurrentHTTP1ConnectionsPerHostSoftLimit))
    }

    func makeOperation(uploadUrl: String, headers: [String: String], data: Data) -> (@Sendable () async -> Error?) {
        let httpClient = self.nioContextManager.httpClient

        return {
            var request = HTTPClientRequest(url: uploadUrl)
            request.method = .PUT
            request.body = .bytes(data)
            for (header, value) in headers {
                request.headers.add(name: header, value: value)
            }

            do {
                let response = try await httpClient.execute(request, timeout: .seconds(30))
                if response.status != .ok {
                    return BeamObjectManagerError.saveError
                }
                return nil
            } catch {
                return error
            }
        }

    }
}

// NIOContextManager wraps a http client that runs on an internal managed MultiThreadedEventLoopGroup
class NIOContextManager {
    let httpClient: HTTPClient
    private var eventLoopGroup: MultiThreadedEventLoopGroup

    init(concurrentHTTP1ConnectionsPerHostSoftLimit: Int) {
        let newEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        eventLoopGroup = newEventLoopGroup
        var configuration = HTTPClient.Configuration()
        configuration.connectionPool = HTTPClient.Configuration.ConnectionPool.init(idleTimeout: .seconds(60), concurrentHTTP1ConnectionsPerHostSoftLimit: concurrentHTTP1ConnectionsPerHostSoftLimit)
        self.httpClient = HTTPClient(eventLoopGroupProvider: .shared(newEventLoopGroup), configuration: configuration)

    }

    deinit {
        let eventLoopGroup = eventLoopGroup
        let client = self.httpClient
        Task.detached {
            // swiftlint:disable force_try
            try! await client.shutdown()
            // swiftlint:disable force_try
            try! eventLoopGroup.syncShutdownGracefully()
        }
    }
}

// Used to keep one event loop for the entire runtime of the application
struct S3UploadManager {
    static let shared = S3UploadManager.build()
    // Test recoding and playback used in tests does not work with NIO ¯\_(ツ)_/¯
    private static func build() -> S3Upload {
        return (Configuration.directUploadNIO && Configuration.env != .test)  ?
        S3UploadURLNIO.init(concurrentHTTP1ConnectionsPerHostSoftLimit: 50) as S3Upload:
        S3UploadURLSession.init()
    }
}
