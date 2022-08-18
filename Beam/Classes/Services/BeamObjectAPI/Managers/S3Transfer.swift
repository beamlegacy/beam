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
import BeamCore

struct S3TransferConfiguration {
    static let requestTimeout: TimeAmount = .seconds(30)
    static let nioMaxBodyDownloadSize: Int = 1024 * 1024 * 10 /* 10 MB */
    static let concurrentHTTP1ConnectionsPerHostSoftLimit = 50
    static let nioConnectionPoolIdleTimeout:TimeAmount = .seconds(60)
}

// Enqueues a upload task on the given task group
protocol S3Transfer {
    func makeOperation(uploadUrl: String, headers: [String: String], data: Data) -> (@Sendable () async -> Error?)
    func makeOperation(downloadUrl: String, request: BeamObjectRequest, beamObject: BeamObject) -> (@Sendable () async throws -> Void)
    var kind: String {get}
}

// Test recoding and playback used in tests does not work with NIO ¯\_(ツ)_/¯
// implements S3UploadTask by using NSURLSession via BeamObjectRequest
class S3TransferURLSession: S3Transfer {
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

    func makeOperation(downloadUrl: String, request: BeamObjectRequest, beamObject: BeamObject) -> (@Sendable () async throws -> Void) {
        return {
            beamObject.data = try await request.fetchDataFromUrl(urlString: downloadUrl)
        }
    }
}

// implements S3UploadTask by using NIO HTTPClient managed my NIOContextManager
class S3TransferURLNIO: S3Transfer {
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
                let response = try await httpClient.execute(request, timeout: S3TransferConfiguration.requestTimeout)
                if response.status != .ok {
                    return BeamObjectManagerError.saveError
                }
                return nil
            } catch {
                return error
            }
        }

    }

    // request is not actually needed here, only used on the alternative code path
    func makeOperation(downloadUrl: String, request: BeamObjectRequest, beamObject: BeamObject) -> (@Sendable () async throws -> Void) {
        let httpClient = self.nioContextManager.httpClient

        return {
            let uploadRequest = HTTPClientRequest(url: downloadUrl)
            let response = try await httpClient.execute(uploadRequest, timeout: S3TransferConfiguration.requestTimeout)
            if response.status != .ok {
                // Probably should not be looged here, but there is no apparent logging at use site
                Logger.shared.logError("Failed to download beam object content from \(downloadUrl) \(response)", category: .sync)
                throw APIRequestError.error
            }
            // Throws if the body is bigger than asked
            let bodyBuffer = try await response.body.collect(upTo: S3TransferConfiguration.nioMaxBodyDownloadSize)
            beamObject.data = Data(buffer: bodyBuffer)
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
        configuration.connectionPool = HTTPClient.Configuration.ConnectionPool.init(idleTimeout: S3TransferConfiguration.nioConnectionPoolIdleTimeout, concurrentHTTP1ConnectionsPerHostSoftLimit: concurrentHTTP1ConnectionsPerHostSoftLimit)
        self.httpClient = HTTPClient(eventLoopGroupProvider: .shared(newEventLoopGroup), configuration: configuration)

    }

    deinit {
        let eventLoopGroup = eventLoopGroup
        let client = self.httpClient
        Task.detached {
            try! await client.shutdown()
            try! eventLoopGroup.syncShutdownGracefully()
        }
    }
}

// Used to keep one event loop for the entire runtime of the application
struct S3TransferManager {
    static let shared = S3TransferManager.build()
    // Test recoding and playback used in tests does not work with NIO ¯\_(ツ)_/¯
    private static func build() -> S3Transfer {
        return (Configuration.directUploadNIO && Configuration.env != .test)  ?
        S3TransferURLNIO.init(concurrentHTTP1ConnectionsPerHostSoftLimit: S3TransferConfiguration.concurrentHTTP1ConnectionsPerHostSoftLimit) as S3Transfer:
        S3TransferURLSession.init()
    }
}
