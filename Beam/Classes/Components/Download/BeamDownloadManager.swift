import Foundation

/**
 This is derived from FavIcon's download code
 */
public class BeamDownloadManager: DownloadManager {

    private let downloadSession = URLSession(configuration: .ephemeral)

    init() {}

    func downloadURLs(_ urls: [URL], headers: [String: String], completion: @escaping ([DownloadManagerResult]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var results = [(index: Int, result: DownloadManagerResult)]()
        let addResult: (Int, DownloadManagerResult) -> Void = { (index: Int, result: DownloadManagerResult) in
            DispatchQueue.main.async {
                results.append((index: index, result: result))
            }
        }
        for (index, url) in urls.enumerated() {
            dispatchGroup.enter()
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            let task = downloadSession.dataTask(with: request) { data, response, error in
                defer {
                    dispatchGroup.leave()
                }
                guard error == nil else {
                    addResult(index, .error(error!))
                    return
                }
                guard let response = response else {
                    addResult(index, .error(DownloadManagerError.invalidResponse))
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 404 {
                        addResult(index, .error(DownloadManagerError.notFound))
                        return
                    }
                    guard (200...299).contains(httpResponse.statusCode) else {
                        addResult(index, .error(DownloadManagerError.serverError(code: httpResponse.statusCode)))
                        return
                    }
                }
                guard let data = data else {
                    addResult(index, .error(DownloadManagerError.emptyResponse))
                    return
                }
                let mimeType = response.mimeType ?? "application/octet-stream"
                let encoding: String.Encoding = {
                    if let textEncodingName = response.textEncodingName,
                       let parsedEncoding = parseStringEncoding(textEncodingName) {
                        return parsedEncoding
                    }
                    return .utf8
                }()
                if mimeType.starts(with: "text/") || mimeType == "application/json" {
                    guard let text = String(data: data, encoding: encoding) else {
                        addResult(index, .error(DownloadManagerError.invalidTextResponse))
                        return
                    }
                    addResult(index, .text(value: text, mimeType: mimeType, actualURL: response.url!))
                    return
                } else {
                    addResult(index, .binary(data: data, mimeType: mimeType, actualURL: response.url!))
                    return
                }
            }
            task.resume()
        }
        dispatchGroup.notify(queue: .main) {
            let sortedResults = results.sorted(by: { $0.index < $1.index }).map { $0.result }
            completion(sortedResults)
        }
    }

    func downloadURL(_ url: URL, headers: [String: String], completion: @escaping (DownloadManagerResult) -> Void) {
        downloadURLs([url], headers: headers) { results in
            completion(results.first!)
        }
    }
}
