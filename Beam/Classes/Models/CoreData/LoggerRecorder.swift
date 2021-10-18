import Foundation
import BeamCore
import os

class LoggerRecorder {
    public static var shared = LoggerRecorder()

    public init() {
        Logger.shared.callback = { (message, level, category, duration) in
            let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

            context.perform {
                let logEntry = LogEntry(context: context)
                logEntry.created_at = BeamDate.now
                logEntry.log = message
                logEntry.category = category.rawValue
                logEntry.level = self.logType(level)
                logEntry.duration = nil

                if let duration = duration {
                    logEntry.duration = NSDecimalNumber(value: duration)
                }

                do {
                    try context.save()
                    DispatchQueue.main.async {
                        let object = try? CoreDataManager.shared.mainContext.existingObject(with: logEntry.objectID)
                        NotificationCenter.default.post(name: .loggerInsert,
                                                        object: object)
                    }
                } catch {
                    //swiftlint:disable:next print
                    print("Unable to save LoggerRecorder context: \(error.localizedDescription)")
                }
            }
        }
    }

    public func deleteOldEntries() {
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        context.perform {
            let fetchRequest: NSFetchRequest<LogEntry> = LogEntry.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "created_at < %@", BeamDate.now as NSDate)

            do {
                for logEntry in try context.fetch(fetchRequest) {
                    context.delete(logEntry)
                }
                try context.save()
            } catch {
                //swiftlint:disable:next print
                print("Unable to delete LogEntry: \(error.localizedDescription)")
            }
        }
    }

    public func deleteAll(_ category: String?) {
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        context.perform {
            let fetchRequest: NSFetchRequest<LogEntry> = LogEntry.fetchRequest()
            if let category = category {
                fetchRequest.predicate = NSPredicate(format: "category = %@", category)
            }

            do {
                for logEntry in try context.fetch(fetchRequest) {
                    context.delete(logEntry)
                }
                try context.save()
            } catch {
                //swiftlint:disable:next print
                print("Unable to delete all LogEntry: \(error.localizedDescription)")
            }
        }
    }

    func logType(_ logType: OSLogType) -> String {
        switch logType {
        case .debug: return "debug"
        case .info: return "info"
        case .error: return "error"
        case .fault: return "fault"
        default:
            return "default"
        }
    }
}
