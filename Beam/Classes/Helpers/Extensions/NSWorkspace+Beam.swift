import AppKit

extension NSWorkspace {
    /// Errors thrown when trying to make Dock's stacks bounce.
    enum Error: Swift.Error {
        /// The URL provided is invalid, probably not a file one.
        case invalidURL
    }

    /// Makes any Stack in the user's Dock bounce with the specified file URL.
    ///
    /// Usually, it's the Downloads Stack but it should work with others as well.
    /// - Parameter url: the URL of the file.
    func bounceDockStack(with url: URL) throws {
        guard url.isFileURL else {
            throw Error.invalidURL
        }
        DistributedNotificationCenter.default().post(name: .downloadFinished, object: url.unsandboxedURL.path)
    }
}

private extension URL {
    private static var unsandboxedUsersHomePath: String {
        return "/Users/\(NSUserName())"
    }

    var unsandboxedURL: URL {
        let components = absoluteString.components(separatedBy: NSHomeDirectory())
        guard components.count > 1 else {
            return self // URL is probably unsandboxed
        }
        let unsandboxedComponents = [Self.unsandboxedUsersHomePath] + components[1...]
        return URL(fileURLWithPath: unsandboxedComponents.joined())
    }
}
