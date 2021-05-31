import Foundation

/**
 This is derived from FavIcon's contenttypes code
 */
func parseHTTPContentType(_ headerValue: String) -> (mimeType: String, encoding: String.Encoding) {

    let headerComponents = headerValue
            .components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }

    if headerComponents.count > 1 {
        let parameterValues = headerComponents[1..<headerComponents.count]
                .filter { $0.contains("=") }
                .map { $0.components(separatedBy: "=") }
                .map { ($0[0], $0[1]) }

        let parameters = [String: String](uniqueKeysWithValues: parameterValues)

        // Default according to RFC is ISO-8859-1, but probably nothing obeys that, so default
        // to UTF-8 instead.
        var encoding = String.Encoding.utf8
        if let charset = parameters["charset"], let parsedEncoding = parseStringEncoding(charset) {
            encoding = parsedEncoding
        }

        return (mimeType: headerComponents[0], encoding: encoding)
    } else {
        return (mimeType: headerComponents[0], encoding: .utf8)
    }
}

func parseStringEncoding(_ value: String) -> String.Encoding? {
    switch value.lowercased() {
    case "iso-8859-1", "latin1": return .isoLatin1
    case "iso-8859-2", "latin2": return .isoLatin2
    case "iso-2022-jp": return .iso2022JP
    case "shift_jis": return .shiftJIS
    case "us-ascii": return .ascii
    case "utf-8": return .utf8
    case "utf-16": return .utf16
    case "utf-32": return .utf32
    case "utf-32be": return .utf32BigEndian
    case "utf-32le": return .utf32LittleEndian
    case "windows-1250": return .windowsCP1250
    case "windows-1251": return .windowsCP1251
    case "windows-1252": return .windowsCP1252
    case "windows-1253": return .windowsCP1253
    case "windows-1254": return .windowsCP1254
    case "x-mac-roman": return .macOSRoman
    default:
        return nil
    }
}

extension HTTPURLResponse {
    func mimeTypeAndEncoding() -> (mimeType: String, encoding: String.Encoding) {
        if let contentType = allHeaderFields["Content-Type"] as? String {
            return parseHTTPContentType(contentType)
        }
        return (mimeType: "application/octet-stream", encoding: .utf8)
    }
}
