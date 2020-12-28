import Foundation
import os.log
import CocoaLumberjack

enum LogCategory: String {
    case general
    case tracking
    case network
    case coredata
    case document
    case memory
    case bluetooth
    case ui
    case disk
    case push
    case lexer
    case web
    case search
    case javascript
}

final class Logger {
    static let shared = Logger()

    private var subsystem = Configuration.bundleIdentifier
    private let hideCategories: [LogCategory] = [.web]
    private let hideLumberCategories: [LogCategory] = []

    private var ddFileLogger: DDFileLogger = DDFileLogger()
    private func configure() {
        DDLog.add(ddFileLogger)
    }

    func removeFiles() {
        ddFileLogger.rollLogFile(withCompletion: {
            for filename: String in self.ddFileLogger.logFileManager.sortedLogFilePaths {
                do {
                    try FileManager.default.removeItem(atPath: filename)
                } catch {
                    print(error.localizedDescription)
                }
            }
        })
        configure()
    }

    private init() {
        configure()
        ddFileLogger.logFileManager.maximumNumberOfLogFiles = 2
        ddFileLogger.maximumFileSize = 1024 * 64 // 64k
        ddFileLogger.rollingFrequency = 3600 * 24 * 7 // 1 week
    }

    var logFileData: Data {
        let logFilePaths = ddFileLogger.logFileManager.sortedLogFilePaths
        var logFileDataArray = Data()
        for logFilePath in logFilePaths.reversed() {
            let fileURL = URL(fileURLWithPath: logFilePath)
            if let data = try? Data(contentsOf: fileURL, options: NSData.ReadingOptions.mappedIfSafe) {
                logFileDataArray.append(data)
            }
        }
        return logFileDataArray
    }

    func logInfo(_ message: String, category: LogCategory) {
        if !hideLumberCategories.contains(category) {
            DDLogInfo("[\(category.rawValue)] \(message)")
        }

        log(message, level: .info, category: category)
    }

    func logDebug(_ message: String, category: LogCategory) {
        if !hideLumberCategories.contains(category) {
            DDLogDebug("[\(category.rawValue)] \(message)")
        }

        log(message, level: .debug, category: category)
    }

    func logError(_ message: String, category: LogCategory) {
        if !hideLumberCategories.contains(category) {
            DDLogError("[\(category.rawValue)] 🛑 \(message)")
        }

        log(message, level: .error, category: category)
    }

    private func log(_ message: String, level: OSLogType, category: LogCategory) {
        #if DEBUG
        if hideCategories.contains(category) { return }

        let log = OSLog(subsystem: subsystem, category: category.rawValue)
        os_log("%{public}@", log: log, type: level, message)
        #endif
    }
}
