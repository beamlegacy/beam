import Foundation
import BeamCore
import os

class LoggerRecorder {
    public static var shared = LoggerRecorder()
    private var context: NSManagedObjectContext?

    public func reset() {
        // `context?.performAndWait()` ensures that:
        // 1. Any running `callback` calls in `attach` are finishing and its context saved before we finished `reset()`
        // 2. No lock needed for changing `self.context`

        context?.performAndWait {
            self.context = nil
        }
    }

    public func attach() {
        self.context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        Logger.shared.callback = { (message, level, category, thread, duration) in
            guard let context = self.context else { return }

            context.perform {
                let logEntry = LogEntry(context: context)
                logEntry.created_at = BeamDate.now
                logEntry.log = "[\(thread)] \(message)"
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

    public func deleteAll(_ category: String? = nil) {
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
