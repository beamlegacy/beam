import Foundation

protocol URLProvider {
    var wrappedURL: URL { get }
}

extension URL: URLProvider {
    var wrappedURL: URL { self }
}
