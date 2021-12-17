//
//  RestAPIServer.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 20/09/2021.
//

import Foundation
import BeamCore

/// Manage requests to additional beam apis server like publishing and embeds
class RestAPIServer {

    enum Request {
        case publishNote(note: BeamNote)
        case unpublishNote(noteId: UUID)
        case embed(url: URL)
        case providers

        func bodyParameters() throws -> (Data, String)? {
            switch self {
            case .publishNote(let note):
                return createBody(for: note)
            case .unpublishNote:
                return nil
            case .embed:
                return nil
            case .providers:
                return nil
            }
        }

        var baseURL: URL {
            switch self {
            case .publishNote, .unpublishNote:
                return URL(string: EnvironmentVariables.PublicAPI.publishServer)!
            case .embed:
                return URL(string: EnvironmentVariables.PublicAPI.embed)!
            case .providers:
                return URL(string: EnvironmentVariables.PublicAPI.embed)!
            }
        }

        var route: String {
            switch self {
            case .publishNote:
                return "/note"
            case .unpublishNote(let noteId):
                return "/note/\(noteId)"
            case .embed:
                return "/parseContent"
            case .providers:
                return "/providers"
            }
        }

        var queryParameters: [String: String]? {
            switch self {
            case .publishNote, .unpublishNote, .providers:
                return nil
            case .embed(let url):
                let content = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url.absoluteString
                return ["content": content]
            }
        }

        /// Authentication required for all request types except .embed and .providers requests
        var requiresAuthentication: Bool {
            switch self {
            case .embed(url: _), .providers:
                return false
            default:
                return true
            }
        }

        var httpMethod: String {
            switch self {
            case .publishNote:
                return "POST"
            case .unpublishNote:
                return "DELETE"
            case .embed, .providers:
                return "GET"
            }
        }

        func error(for responseCode: Int, data: Data?) -> RestAPIServer.Error? {
            switch responseCode {
            case 200...299:
                return nil
            case 401:
                return .notAuthenticated
            case 403:
                return .notAllowed
            case 404:
                return .notFound
            case 412:
                return .noUsername
            case 422:
                return .wrongFormat
            default:
                let error = errorMessage(from: data)
                return .serverError(error: error)
            }
        }

        private func createBody(for note: BeamNote) -> (Data, String)? {
            let richContent = note.richContent

            let publicNote = PublicNote(note: note)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let encodedNote = try? encoder.encode(publicNote) else { return nil }

            if richContent.isEmpty {
                return (encodedNote, "application/json")
            } else {
                guard let data = multipart(encodedPublicNote: encodedNote, richContent: richContent) else { return nil }
                return (data, "multipart/form-data; boundary=\(RestAPIServer.multipartBoundary)")
            }
        }

        private func multipart(encodedPublicNote: Data, richContent: [BeamElement]) -> Data? {
            let boundary = RestAPIServer.multipartBoundary
            let lineBreak = "\r\n"

            let body = NSMutableData()
            guard let fileDB = try? BeamFileDB(path: BeamData.fileDBPath) else { return nil }

            let note = createMultipartBody(data: encodedPublicNote, documentName: "note", fileNameAndExtension: nil, mimetype: "application/json")
            body.append(note)
            for content in richContent {
                switch content.kind {
                case .image(let fileId, _, _):
                    if let fileRecord = try? fileDB.fetch(uid: fileId) {
                        let resourceData = fileRecord.data
                        let resourcePart = createMultipartBody(data: resourceData, documentName: fileRecord.uid.uuidString, fileNameAndExtension: fileRecord.name, mimetype: fileRecord.type)
                        body.appendString(lineBreak)
                        body.append(resourcePart)
                    }
                default:
                    break
                }
            }
            body.appendString(lineBreak)
            body.appendString("--\(boundary)--\(lineBreak)")

            return body as Data
        }

        private func createMultipartBody(data: Data, documentName: String, fileNameAndExtension: String?, mimetype: String) -> Data {
            let body = NSMutableData()
            let boundary = RestAPIServer.multipartBoundary
            let lineBreak = "\r\n"
            let boundaryPrefix = "--\(boundary)\r\n"
            body.appendString(boundaryPrefix)
            body.appendString("Content-Disposition: form-data; name=\"\(documentName)\"")
            if let fileNameAndExtension = fileNameAndExtension {
                body.appendString("; filename=\"\(fileNameAndExtension)\"")
            }
            body.appendString("\(lineBreak)")
            body.appendString("Content-Type: \(mimetype)\(lineBreak)\(lineBreak)")
            body.append(data)
            return body as Data
        }

        private func errorMessage(from data: Data?) -> String? {
            guard let data = data else { return nil }
            let decoder = JSONDecoder()
            let error = try? decoder.decode(RestAPIServer.ErrorMessage.self, from: data)
            return error?.message
        }
    }

    static let multipartBoundary = "WebAppBoundary"

    func request<T: Decodable>(serverRequest: Request, completion: @escaping (Result<T, Swift.Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let urlRequest: URLRequest
            do {
                urlRequest = try self.createUrlRequest(request: serverRequest)
            } catch {
                completion(.failure(error))
                return
            }

            let task = BeamURLSession.shared.dataTask(with: urlRequest) { data, urlResponse, error in
                guard error == nil else {
                    completion(.failure(error!))
                    return
                }

                if let response = urlResponse as? HTTPURLResponse, let serverError = serverRequest.error(for: response.statusCode, data: data) {
                    completion(.failure(serverError))
                    return
                }

                let jsonDecoder = JSONDecoder()
                guard let data = data else {
                    completion(.failure(RestAPIServer.Error.noDataReceived))
                    return
                }

                do {
                    let response = try jsonDecoder.decode(T.self, from: data)
                    completion(.success(response))
                } catch {
                    completion(.failure(RestAPIServer.Error.parsingError))
                }
            }
            task.resume()
        }
    }

    private func createUrlRequest(request: Request) throws -> URLRequest {

        var urlComponents = URLComponents(url: request.baseURL.appendingPathComponent(request.route), resolvingAgainstBaseURL: false)
        if let queryParameters = request.queryParameters {
            var queryItems = [URLQueryItem]()
            queryParameters.forEach { (key, value) in
                queryItems.append(.init(name: key, value: value))
            }
            urlComponents?.queryItems = queryItems
        }
        guard let url = urlComponents?.url else { throw RestAPIServer.Error.invalidURL }
        var urlRequest = URLRequest(url: url)

        if request.requiresAuthentication {
            AuthenticationManager.shared.updateAccessTokenIfNeeded()
            guard AuthenticationManager.shared.isAuthenticated, let accessToken = AuthenticationManager.shared.accessToken else {
                throw RestAPIServer.Error.notAuthenticated
            }
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.setValue("native.beamapp.co", forHTTPHeaderField: "Origin")

        urlRequest.httpMethod = request.httpMethod
        if let (body, contentType) = try request.bodyParameters() {
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = body
        }

        return urlRequest
    }
}

extension RestAPIServer {
    enum Error: Swift.Error, Equatable {
        case invalidURL
        case notAuthenticated
        case notAllowed
        case notFound
        case wrongFormat
        case serverError(error: String?)
        case parsingError
        case noDataReceived
        case noUsername
    }

    struct ErrorMessage: Decodable {
        let message: String?
    }
}

extension NSMutableData {
    func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
