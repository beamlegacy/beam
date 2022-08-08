import Foundation
import BeamCore
import os

class LoggerRecorder {
    public static var shared = LoggerRecorder()
    private let lock = NSLock()

    public func reset() {
        lock {
            Logger.shared.callback = nil
        }
    }

    public func attach() {
        lock.lock()
        defer { lock.unlock() }

        Logger.shared.callback = { (message, level, category, thread, duration) in
            CoreDataManager.shared.persistentContainer.performBackgroundTask { context in
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

                    if LoggerNSWindow.instances > 0 {
                        DispatchQueue.main.async {
                            let object = try? CoreDataManager.shared.mainContext.existingObject(with: logEntry.objectID)
                            NotificationCenter.default.post(name: .loggerInsert, object: object)
                        }
                    }
                } catch {
                    Logger.shared.logDebug("Unable to save LoggerRecorder context: \(error.localizedDescription)", category: .coredata)
                }
            }
        }
    }

    public func getEntries(with predicate: NSCompoundPredicate, and sortDescriptors: [NSSortDescriptor], for limit: Int = 500) -> [LogEntry]? {
        let request: NSFetchRequest<LogEntry> = LogEntry.fetchRequest()
        request.fetchLimit = limit
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        do {
            return try CoreDataManager.shared.mainContext.fetch(request).reversed()
        } catch {
            Logger.shared.logDebug("Unable to get LogEntry: \(error.localizedDescription)", category: .coredata)
        }
        return nil
    }

    public func deleteEntries(olderThan: DateComponents) {
        guard let previousDate = Calendar.current.date(byAdding: olderThan, to: BeamDate.now) else { return }
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        do {
            try context.performAndWait {
                let localTimer = Date()

                let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "LogEntry")
                fetchRequest.predicate = NSPredicate(format: "created_at < %@", previousDate as NSDate)

                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                deleteRequest.resultType = .resultTypeObjectIDs

                let batchDelete = try context.execute(deleteRequest) as? NSBatchDeleteResult
                guard let deleteResult = batchDelete?.result as? [NSManagedObjectID] else { return }
                let deletedObjects: [AnyHashable: Any] = [NSDeletedObjectsKey: deleteResult]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: deletedObjects, into: [CoreDataManager.shared.mainContext])
                Logger.shared.logInfo("Execution time to delete Beam logs", category: .coredataDebug, localTimer: localTimer)
            }
        } catch {
            Logger.shared.logDebug("Unable to delete older Logs entries: \(error.localizedDescription)", category: .coredata)
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
                Logger.shared.logDebug("Unable to delete all LogEntry: \(error.localizedDescription)", category: .coredata)
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
