//
//  PublicServerRequest.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 20/09/2021.
//

import Foundation
import BeamCore

enum PublicServerError: Error {
    case notAuthenticated
    case notAllowed
    case notFound
    case wrongFormat
    case serverError
    case parsingError
    case noDataReceived
}

class PublicServer {

    enum Request {
        case publishNote(note: BeamNote)
        case unpublishNote(noteId: UUID)

        func bodyParameters() throws -> (Data, String)? {
            switch self {
            case .publishNote(let note):
                return createBody(for: note)
            case .unpublishNote:
                return nil
            }
        }

        var route: String {
            switch self {
            case .publishNote(_):
                return "/note"
            case .unpublishNote(let noteId):
                return "/note/\(noteId)"
            }
        }

        var requiresAuthentication: Bool {
            return true
        }

        var httpMethod: String {
            switch self {
            case .publishNote(_):
                return "POST"
            case .unpublishNote(_):
                return "DELETE"
            }
        }

        func error(for responseCode: Int) -> PublicServerError? {
            switch responseCode {
            case 200...299:
                return nil
            case 401:
                return .notAuthenticated
            case 403:
                return .notAllowed
            case 404:
                return .notFound
            case 422:
                return .wrongFormat
            default:
                return .serverError
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
                return (data, "multipart/form-data; boundary=\(PublicServer.multipartBoundary)")
            }
        }

        private func multipart(encodedPublicNote: Data, richContent: [BeamElement]) -> Data? {
            let boundary = PublicServer.multipartBoundary
            let lineBreak = "\r\n"

            let body = NSMutableData()
            guard let fileDB = try? BeamFileDB(path: BeamData.fileDBPath) else { return nil }

            let note = createMultipartBody(data: encodedPublicNote, documentName: "note", fileNameAndExtension: nil, mimetype: "application/json")
            body.append(note)
            for content in richContent {
                switch content.kind {
                case .image(let fileId, _):
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
            let boundary = PublicServer.multipartBoundary
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
    }

    let baseURL = URL(string: "https://public.beamapp.co")!
    static let multipartBoundary = "WebAppBoundary"

    func request<T: Decodable>(publicServerRequest: Request, completion: @escaping (Result<T, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let urlRequest: URLRequest
            do {
                urlRequest = try self.createUrlRequest(request: publicServerRequest)
            } catch {
                completion(.failure(error))
                return
            }

            let task = BeamURLSession.shared.dataTask(with: urlRequest) { data, urlResponse, error in
                guard error == nil else {
                    completion(.failure(error!))
                    return
                }

                if let response = urlResponse as? HTTPURLResponse, let serverError = publicServerRequest.error(for: response.statusCode) {
                    completion(.failure(serverError))
                    return
                }

                let jsonDecoder = JSONDecoder()
                jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
                guard let data = data else {
                    completion(.failure(PublicServerError.noDataReceived))
                    return
                }

                do {
                    let response = try jsonDecoder.decode(T.self, from: data)
                    completion(.success(response))
                } catch {
                    completion(.failure(PublicServerError.parsingError))
                }
            }
            task.resume()
        }
    }

    private func createUrlRequest(request: Request) throws -> URLRequest {

        let url = baseURL.appendingPathComponent(request.route)
        var urlRequest = URLRequest(url: url)

        if request.requiresAuthentication {
            AuthenticationManager.shared.updateAccessTokenIfNeeded()
            guard AuthenticationManager.shared.isAuthenticated, let accessToken = AuthenticationManager.shared.accessToken else {
                throw PublicServerError.notAuthenticated
            }
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        urlRequest.httpMethod = request.httpMethod
        if let (body, contentType) = try request.bodyParameters() {
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = body
        }

        return urlRequest
    }
}

extension NSMutableData {
    func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
