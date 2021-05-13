import Foundation
import os.log
import CocoaLumberjack
import CocoaLumberjackSwift

public enum LogCategory: String {
    case general
    case tracking
    case network
    case coredata
    case coredataDebug
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
    case documentMerge
    case documentDebug
    case database
    case databaseDebug
    case noteEditor
    case keychain
    case encryption
    case contentBlocking
    case pointAndShoot
    case fileDB
    case oauth
}

public final class Logger {
    public static var shared: Logger!

    public static func setup(subsystem: String) {
        shared = Logger(subsystem: subsystem)
    }

    private var subsystem = "beam"
    private let hideCategories: [LogCategory] = [.web, .coredataDebug, .documentDebug]
    private let hideLumberCategories: [LogCategory] = [.documentDebug]

    private var ddFileLogger = DDFileLogger()

    private func configure() {
        DDLog.add(ddFileLogger)
    }

    public func removeFiles() {
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

    private init(subsystem: String) {
        self.subsystem = subsystem
        configure()

        // swiftlint:disable:next print
        print("Storing log files to \(ddFileLogger.currentLogFileInfo?.filePath ?? "-")")

        ddFileLogger.logFileManager.maximumNumberOfLogFiles = 2
        ddFileLogger.maximumFileSize = 1024 * 1024 // 1MB
        ddFileLogger.rollingFrequency = 3600 * 24 * 7 // 1 week
    }

    public var logFileData: Data {
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

    public var logFileString: String {
        return String(data: logFileData, encoding: .utf8) ?? "Couldn't parse logs data"
    }

    public func logInfo(_ message: String, category: LogCategory = .general) {
        if !hideLumberCategories.contains(category) {
            DDLogInfo("[\(category.rawValue)] \(message)")
        }

        log(message, level: .info, category: category)
    }

    public func logDebug(_ message: String, category: LogCategory = .general) {
        if !hideLumberCategories.contains(category) {
            DDLogDebug("[\(category.rawValue)] \(message)")
        }

        log(message, level: .debug, category: category)
    }

    public func logError(_ message: String, category: LogCategory) {
        if !hideLumberCategories.contains(category) {
            DDLogError("[\(category.rawValue)] 🛑 \(message)")
        }

        log("🛑 \(message)", level: .error, category: category)
    }

    public func logWarning(_ message: String, category: LogCategory) {
        if !hideLumberCategories.contains(category) {
            DDLogWarn("[\(category.rawValue)] 🛑 \(message)")
        }

        log("🛑 \(message)", level: .default, category: category)
    }

    private func log(_ message: String, level: OSLogType, category: LogCategory) {
        #if DEBUG
        if hideCategories.contains(category) { return }

        let log = OSLog(subsystem: subsystem, category: category.rawValue)
        os_log("%{public}@", log: log, type: level, message)
        #endif
    }
}
