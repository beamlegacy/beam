import Foundation
import BeamCore

/// Loads file from app bundle. Used to load CSS and JS files.
///
/// For example loading `style.css`:
/// ```Swift
/// loadFile(from: "style", fileType:"css")
/// ```
/// - Parameters:
///   - fileName: Name of file without extension. For example `style`
///   - fileType: File extension. For example `css`
/// - Returns: If successful return file content as String
func loadFile(from fileName: String, fileType: String) -> String? {
    guard let path = Bundle.main.path(forResource: fileName, ofType: fileType),
       let fileContent = try? String(contentsOfFile: path, encoding: String.Encoding.utf8) else {
           Logger.shared.logError("Could not load file '\(fileName).\(fileType)' in bundle path. ", category: .web)
           return nil
    }

    return fileContent
}
