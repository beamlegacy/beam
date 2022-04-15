//
//  SocialTitle.swift
//  Beam
//
//  Created by Stef Kors on 03/03/2022.
//

import Foundation
import BeamCore

struct SocialTitle: Codable, Equatable {
    var url: URL
    var title: String
}

class SocialTitleFetcher {
    static var shared = SocialTitleFetcher()
    enum SocialTitleFetcherError: Error {
        case parsingCachedItem
        case failedRequest
    }

    func fetch(for url: URL, completion: @escaping (Result<SocialTitle?, SocialTitleFetcherError>) -> Void) {
        let apiServer = RestAPIServer()
        let request = RestAPIServer.Request.embed(url: url)
        apiServer.request(serverRequest: request) { (result: Result<[SocialTitle], Error>) in
            let value = result
                .map { $0.first }
                .mapError { _ in SocialTitleFetcherError.failedRequest }
            completion(value)
        }
    }

    func fetch(for url: URL) async -> SocialTitle? {
        await withCheckedContinuation { continuation in
            fetch(for: url) { result  in
                continuation.resume(returning: try? result.get())
            }
        }
    }
}
