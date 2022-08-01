import Foundation
import BeamCore

extension BeamObjectRequest {
    enum BeamObjectRequestError: Error {
        case malformattedURL
        case not200
        case noData
        case privateKeyError(validObjects: [BeamObject], invalidObjects: [BeamObject])
    }

    @discardableResult
    public func fetchDataFromUrl(urlString: String,
                                 _ completionHandler: @escaping (Result<Data, Error>) -> Void) throws -> URLSessionDataTask {

        guard let url = URL(string: urlString) else {
             throw BeamObjectRequestError.malformattedURL
        }
        var request = URLRequest(url: url)
        let headers: [String: String] = [
            "User-Agent": "Beam client, \(Information.appVersionAndBuild)"
        ]

        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        let session = BeamURLSession.shared
        // swiftlint:disable:next date_init
        let localTimer = Date()
        let task = session.dataTask(with: request) { (data, response, error) -> Void in
            #if DEBUG
            // This is not an API call on our servers but since it's tightly coupled, I still store analytics there
            APIRequest.networkCallFilesLock {
                APIRequest.networkCallFiles.append("direct_download")
            }
            #endif

            APIRequest.callsCount += 1

            // I only enable those log manually, they're very verbose!
            Logger.shared.logDebug("[\(data?.count.byteSize ?? "-")] \((response as? HTTPURLResponse)?.statusCode ?? 0) download \(urlString)",
                                   category: .network,
                                   localTimer: localTimer)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                      completionHandler(.failure(error ?? BeamObjectRequestError.not200))

                      return
                  }

            completionHandler(.success(data))
        }

        task.resume()
        return task
    }

    @discardableResult
    func sendDataToUrl(urlString: String,
                       putHeaders: [String: String],
                       data: Data,
                       _ completionHandler: @escaping (Swift.Result<Bool, Error>) -> Void) throws -> URLSessionDataTask {
        guard let url = URL(string: urlString) else {
             throw BeamObjectRequestError.malformattedURL
        }
        var request = URLRequest(url: url)

        var headers = putHeaders
        headers["User-Agent"] = "Beam client, \(Information.appVersionAndBuild)"
        headers["Content-Length"] = String(data.count)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.allHTTPHeaderFields = headers

        let session = BeamURLSession.shared
        // swiftlint:disable:next date_init
        let localTimer = Date()

        let task = session.dataTask(with: request) { (responseData, response, error) -> Void in
            #if DEBUG
            // This is not an API call on our servers but since it's tightly coupled, I still store analytics there
            APIRequest.networkCallFilesLock {
                APIRequest.networkCallFiles.append("direct_upload")
            }
            #endif

            APIRequest.callsCount += 1

            // I only enable those log manually, they're very verbose!
            Logger.shared.logDebug("[\(data.count.byteSize)] \((response as? HTTPURLResponse)?.statusCode ?? 0) upload \(urlString)",
                                   category: .network,
                                   localTimer: localTimer)

            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(.failure(error ?? BeamObjectRequestError.not200))
                return
            }

            /*
             S3 direct upload returns 0 byte for `data` (now named `_`), Vinyl will not store it at all. Don't match on it as:

             `data != nil == true` on the first call, but false when going through Vinyl
             */

            guard [200, 204].contains(httpResponse.statusCode) else {
                Logger.shared.logError("Error while uploading data: \(httpResponse.statusCode)", category: .network)
                if let responseData = responseData, let responseString = responseData.asString {
                    dump(responseString)
                }

                Logger.shared.logDebug("Sent headers: \(headers)", category: .network)
                completionHandler(.failure(error ?? BeamObjectRequestError.not200))

                return
            }

            completionHandler(.success(true))
        }

        task.resume()
        return task
    }
}
