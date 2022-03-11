import Foundation
import os.log
import CocoaLumberjack
import CocoaLumberjackSwift
import BeamCore

enum PerformanceDebugCategory: String {
    case none = ""
    case network = "🔄"
    case location = "📍"
    case coredata = "🦋"
    case memory = "🗜"
    case backgroundFetch = "🚶🏼"
    case view = "🐝"
    case disk = "💿"
    case error = "🛑"
    case debug = "🚗"
    case push = "🍏"
}

class PerformanceDebug {
    // swiftlint:disable:next date_init
    var localTimer = Date()
    let message: String?
    let maximumTime = 0.9
    var disabled = false
    let category: PerformanceDebugCategory

    static let hideCategories: [PerformanceDebugCategory] = []
    static let hideLumberCategories: [PerformanceDebugCategory] = [.view, .memory, .disk]

    static var ddFileLogger: DDFileLogger = DDFileLogger()
    class func configure() {
        DDLog.add(ddFileLogger)
    }

    public class func removeFiles() {
        ddFileLogger.rollLogFile(withCompletion: {
            for filename: String in self.ddFileLogger.logFileManager.sortedLogFilePaths {
                do {
                    try FileManager.default.removeItem(atPath: filename)
                } catch {
                    Logger.shared.logDebug(error.localizedDescription)
                }
            }
        })
        configure()
    }

    init(_ message: String? = nil, _ disabled: Bool = false, _ category: PerformanceDebugCategory = .none) {
        self.category = category
        self.message = message
        self.disabled = disabled
        if let message = message, !message.isEmpty {
            PerformanceDebug.debugLog(category, message, false, disabled)
        }
        PerformanceDebug.ddFileLogger.logFileManager.maximumNumberOfLogFiles = 2
        PerformanceDebug.ddFileLogger.maximumFileSize = 1024 * 64 // 64k
        PerformanceDebug.ddFileLogger.rollingFrequency = 3600 * 24 * 7 // 1 week
    }

    var logFileData: Data {
        let logFilePaths = PerformanceDebug.ddFileLogger.logFileManager.sortedLogFilePaths
        var logFileDataArray = Data()
        for logFilePath in logFilePaths.reversed() {
            let fileURL = URL(fileURLWithPath: logFilePath)
            if let data = try? Data(contentsOf: fileURL, options: NSData.ReadingOptions.mappedIfSafe) {
                logFileDataArray.append(data)
            }
        }
        return logFileDataArray
    }

    func debug(_ newMessage: String? = nil) {
        if newMessage != nil && message == nil { // This is a simple log
            PerformanceDebug.debugLog(category, newMessage ?? "", false, disabled)
        } else { // This is a performance measure
            // swiftlint:disable:next date_init
            let diffTime = Date().timeIntervalSince(localTimer)
            let diff = String(format: "%.2f", diffTime)
            let longDiffTime = diffTime >= maximumTime
            let finalMessage = "\(diff)sec \(longDiffTime ? "🛑 " : "")\(message ?? "") \(newMessage ?? "")"
            PerformanceDebug.debugLog(category, finalMessage, longDiffTime, disabled)
        }
        // swiftlint:disable:next date_init
        localTimer = Date()
    }

    func done(_ preMessage: String? = nil) {
        debug("\(preMessage ?? "") DONE".trimmingCharacters(in: .whitespaces))
    }

    func extraInfos() -> [String: Any] {
        // Add details for Alamofire errors (loosing details when casted to NSError)
        let tokensInfo: [String: Any] = AuthenticationManager.shared.hashTokensInfos()
        var extraInfo: [String: Any] = [:]
        extraInfo.merge(tokensInfo) { (current, _) in current }

        return extraInfo
    }

    static func debugLog(_ category: PerformanceDebugCategory,
                         _ message: String,
                         _ forced: Bool = false,
                         _ disabled: Bool = false) {

        if disabled && !forced { return }

        if !PerformanceDebug.hideLumberCategories.contains(category) {
            DDLogDebug("[\(getThreadName())] \(category.rawValue) \(message)")
        }

        #if DEBUG_PERF
        if PerformanceDebug.hideCategories.contains(category) { return }

        let logLevel = category == .network ? OSLog.network : OSLog.perf
        os_log("[%@] %@ %@", log: logLevel, type: .debug, getThreadName(), category.rawValue, message)
        #endif
    }

    // Just to get a thread id... :(
    static func getThreadName() -> String {
        let threadDescription = Thread.current.description

        let regex = try? NSRegularExpression(
            pattern: #"number = (\d+)"#
        )

        var threadName = "-"

        let match = regex?.firstMatch(in: threadDescription, options: [], range: NSRange(location: 0, length: threadDescription.utf8.count))

        if let match = match, let number = Range(match.range(at: 1), in: threadDescription) {
                threadName = String(threadDescription[number])
        }

        if threadName.count == 1 {
            threadName = "0\(threadName)"
        }

        return threadName
    }
}
