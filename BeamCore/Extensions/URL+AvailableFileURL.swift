import Foundation

extension URL {

    /// Checks whether a file exists at the specified URL, and if yes, returns an alternate, unique URL with a suffix
    /// added to the filename.
    ///
    /// If a `/some/dir/` directory contains a `file.txt` file, then passing `/some/dir/file.txt`
    /// will return `/some/dir/file-2.txt`.
    ///
    /// If the directory also contains a `file-2.txt` file, then `/some/dir/file-3.txt` will be returned instead.
    public func availableFileURL(fileManager: FileManager = .default) -> URL {
        guard isFileURL else { return self }

        var url = self

        let directory = url.deletingLastPathComponent()
        let splits = url.lastPathComponent.split(separator: ".")
        let fileName = splits[0]
        let pathExtension = splits[1...].joined(separator: ".")

        var count = 2

        while fileManager.fileExists(atPath: url.path) {
            let tentativeFileName = "\(fileName)-\(count)"
            url = directory.appendingPathComponent(tentativeFileName).appendingPathExtension(pathExtension)
            count += 1
        }

        return url
    }

}
