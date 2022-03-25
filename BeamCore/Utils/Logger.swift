import Foundation
import os.log
import CocoaLumberjack
import CocoaLumberjackSwift

public enum LogCategory: String, CaseIterable {
    case general
    case tracking
    case network
    case coredata
    case coredataDebug
    case database
    case databaseDebug
    case databaseNetwork
    case document
    case documentNotification
    case documentNetwork
    case documentMerge
    case documentDebug
    case memory
    case bluetooth
    case ui
    case disk
    case push
    case lexer
    case web
    case search
    case javascript
    case noteEditor
    case keychain
    case encryption
    case contentBlocking
    case pointAndShoot
    case fileDB
    case linkDB
    case oauth
    case webSocket
    case passwordsDB
    case passwordManager
    case passwordManagerInternal
    case passwordNetwork
    case frecencyNetwork
    case fileNetwork
    case linkNetwork
    case clustering
    case commandManager
    case beamObject
    case beamObjectNetwork
    case beamObjectDebug
    case beamObjectChecksum
    case downloader
    case autocompleteManager
    case topDomain
    case browsingTreeSender
    case browsingTreeNetwork
    case notePublishing
    case eventCalendar
    case favIcon
    case embed
    case marker
    case sentry
    case contactsDB
    case browserImport
    case autoUpdate
    case accountManager
    case privateKeySignature
    case tabPinSuggestion
}

public final class Logger {
    public static var shared: Logger!

    public static func setup(subsystem: String) {
        shared = Logger(subsystem: subsystem)
    }

    private var subsystem = "beam"

    public var callback: ((String, OSLogType, LogCategory, String, TimeInterval?) -> Void)?

    // If you want to change this for you and uncluter your console logs, add into `.envrc.private`:
    // export HIDE_CATEGORIES="web documentDebug javascript pointAndShoot coredataDebug"
    // it will overwrite this `hideCategories`
    private var hideCategories: [LogCategory] = [.web, .coredataDebug, .documentDebug, .commandManager, .autocompleteManager, .favIcon, .passwordManagerInternal]

    private let hideLumberCategories: [LogCategory] = [.documentDebug, .passwordManagerInternal]

    private let hideLocalCategories: [LogCategory] = [.passwordManagerInternal]

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
        #if DEBUG
        ddFileLogger.maximumFileSize = 1024 * 1024 * 50 // 50MB
        #else
        ddFileLogger.maximumFileSize = 1024 * 1024 * 1 // 1MB
        #endif
        ddFileLogger.rollingFrequency = 3600 * 24 * 7 // 1 week

        if !EnvironmentVariables.hideCategories.isEmpty {
            hideCategories = EnvironmentVariables.hideCategories
        }
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

    public func logInfo(_ message: String, category: LogCategory = .general, localTimer: Date? = nil) {
        if !hideLumberCategories.contains(category) {
            DDLogInfo("[\(category.rawValue)] \(message)")
        }

        log(message, level: .info, category: category, localTimer: localTimer)
    }

    public func logDebug(_ message: String, category: LogCategory = .general, localTimer: Date? = nil) {
        if !hideLumberCategories.contains(category) {
            DDLogDebug("[\(category.rawValue)] \(message)")
        }

        log(message, level: .debug, category: category, localTimer: localTimer)
    }

    public func logError(_ message: String, category: LogCategory, localTimer: Date? = nil) {
        if !hideLumberCategories.contains(category) {
            DDLogError("[\(category.rawValue)] 🛑 \(message)")
        }

        log("🛑 \(message)", level: .error, category: category, localTimer: localTimer)
    }

    public func logWarning(_ message: String, category: LogCategory, localTimer: Date? = nil) {
        if !hideLumberCategories.contains(category) {
            DDLogWarn("[\(category.rawValue)] ⚠️ \(message)")
        }

        log("⚠️ \(message)", level: .info, category: category, localTimer: localTimer)
    }

    private func log(_ message: String, level: OSLogType, category: LogCategory, localTimer: Date? = nil) {
        var timeDiff: TimeInterval?
        if let localTimer = localTimer {
            // swiftlint:disable:next date_init
            timeDiff = Date().timeIntervalSince(localTimer)
        }

        var tid: UInt64 = 0
        pthread_threadid_np(nil, &tid)
        let threadName = Thread.isMainThread ? "main" : "\(tid)"

        if !hideLocalCategories.contains(category) {
            callback?(message, level, category, threadName, timeDiff)
        }

        #if DEBUG
        if hideCategories.contains(category) { return }

        let log = OSLog(subsystem: subsystem, category: category.rawValue)

        if let timeDiff = timeDiff {
            os_log("%{public}@ in %@sec", log: log, type: level, message, String(format: "%.4f", timeDiff))
        } else {
            os_log("%{public}@", log: log, type: level, message)
        }
        #endif
    }
}
