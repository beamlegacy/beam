import Foundation
import CoreData
import BeamCore

// swiftlint:disable file_length
extension BeamObjectChecksum {
    // MARK: -
    // MARK: Fetches
    static func previousChecksum(id: UUID, type: BeamObjectObjectType) -> String? {
        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()
        request.fetchLimit = 1
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        request.predicate = predicates(id: id, type: type)

        if let objects = try? context.fetch(request) {
            return objects.first?.previous_checksum
        }

        return nil
    }

    static func previousChecksum<T: BeamObjectProtocol>(object: T) -> String? {
        previousChecksum(id: object.beamObjectId, type: type(of: object).beamObjectType)
    }

    static func previousChecksum(beamObject: BeamObject) -> String? {
        if let type = BeamObjectObjectType.fromString(value: beamObject.beamObjectType) {
            return previousChecksum(id: beamObject.id, type: type)
        }

        return nil
    }

    static func previousChecksums<T: BeamObjectProtocol>(objects: [T]) -> [UUID: String] {
        var result: [UUID: String] = [:]
        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        var predicates: [NSPredicate] = []
        predicates.append(NSPredicate(format: "id IN %@",
                                      objects.compactMap { $0.beamObjectId } as CVarArg))

        context.performAndWait {
            guard let objects = try? context.fetch(request) else { return }
            for objectChecksum in objects {
                guard let id = objectChecksum.id else { continue }
                result[id] = objectChecksum.previous_checksum
            }
        }

        return result
    }

    /// I use `BeamObject` as the result key because the 100% way to be unique is a combined object type + object id
    static func previousChecksums(beamObjects: [BeamObject]) -> [BeamObject: String] {
        let (checksums, context) = findChecksumsForBeamObjects(beamObjects: beamObjects)
        var result: [BeamObject: String] = [:]

        context.performAndWait {
            checksums.forEach { (key, value) in
                result[key] = value.previous_checksum
            }
        }

        return result
    }

    static func sentData<T: BeamObjectProtocol>(object: T) -> Data? {
        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()
        request.fetchLimit = 1
        request.predicate = predicates(id: object.beamObjectId, type: type(of: object).beamObjectType)

        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        return context.performAndWait {
            guard let objects = try? context.fetch(request) else { return nil }

            return objects.first?.data_sent
        }
    }

    static func previousSavedObject<T: BeamObjectProtocol>(object: T) throws -> T? {
        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()
        request.fetchLimit = 1
        request.predicate = predicates(id: object.beamObjectId, type: type(of: object).beamObjectType)

        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        return try context.performAndWait {
            guard let objects = try? context.fetch(request), let object = objects.first else { return nil}
            context.refresh(object, mergeChanges: false)

            guard let previousData = object.data_sent else { return nil }

            let beamObject = try Self.decoder.decode(BeamObject.self, from: previousData)
            return try beamObject.decodeBeamObject()
        }
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601withFractionalSeconds
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601withFractionalSeconds
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    // MARK: -
    // MARK: Deletes

    static func deletePreviousChecksum<T: BeamObjectProtocol>(object: T) throws {
        Logger.shared.logDebug("Deleting previous checksums for \(object.description)",
                               category: .beamObjectChecksum)

        let (objectChecksum, context) = objectWithObject(object: object)
        try context.performAndWait {
            context.delete(objectChecksum)
            try CoreDataManager.save(context)
        }
    }

    static func deletePreviousChecksum(beamObject: BeamObject) throws {
        Logger.shared.logDebug("Deleting previous checksums for \(beamObject.description)",
                               category: .beamObjectChecksum)

        let (objectChecksum, context) = objectWithObject(object: beamObject)
        try context.performAndWait {
            context.delete(objectChecksum)
            try CoreDataManager.save(context)
        }
    }

    static func deletePreviousChecksums(type: BeamObjectObjectType) throws {
        Logger.shared.logDebug("Deleting previous checksums for type \(type)",
                               category: .beamObjectChecksum)

        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()
        request.predicate = NSPredicate(format: "object_type = %@",
                                        type.rawValue as CVarArg)

        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        try context.performAndWait {
            for object in try context.fetch(request) {
                context.delete(object)
            }

            try CoreDataManager.save(context)
        }
    }

    static func deletePreviousChecksums(beamObjects: [BeamObject]) throws {
        Logger.shared.logDebug("Deleting previous checksums for \(beamObjects)",
                               category: .beamObjectChecksum)

        for beamObject in beamObjects {
            try deletePreviousChecksum(beamObject: beamObject)
        }
    }

    static func deletePreviousChecksums<T: BeamObjectProtocol>(objects: [T]) throws {
        for object in objects {
            try deletePreviousChecksum(object: object)
        }
    }

    static func deleteAll() throws {
        Logger.shared.logDebug("Deleted all checksums",
                               category: .beamObjectChecksum)
        // swiftlint:disable:next date_init
        let localTimer = Date()
        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        try context.performAndWait {
            for object in try context.fetch(request) {
                context.delete(object)
            }

            try CoreDataManager.save(context)
            Logger.shared.logInfo("Execution time for BeamObjectChecksum deleteAll", category: .beamObjectChecksum, localTimer: localTimer)
        }
    }

    // MARK: -
    // MARK: Saves

    func isEqual(to object: BeamObject) -> Bool {
        previous_checksum == object.dataChecksum &&
        data_sent == (try? Self.encoder.encode(object))
    }

    static func savePreviousChecksums(beamObjects: [BeamObject]) throws {
        guard !beamObjects.isEmpty else {
            Logger.shared.logWarning("No objects to save...", category: .beamObjectChecksum)
            return
        }

        // swiftlint:disable:next date_init
        var localTimer = Date()

        let (checksums, context) = findChecksumsForBeamObjects(beamObjects: beamObjects)

        Logger.shared.logDebug("Found or created previous checksum objects for \(beamObjects.count) beamObjects",
                               category: .beamObjectChecksum,
                               localTimer: localTimer)

        localTimer = Date()

        try context.performAndWait {
            for beamObject in beamObjects {
                let checksum = checksums[beamObject] ?? BeamObjectChecksum(context: context)

                checksum.id = checksum.id ?? beamObject.id
                checksum.object_type = checksum.object_type ?? beamObject.beamObjectType
                checksum.previous_checksum = beamObject.dataChecksum
                checksum.updated_at = BeamDate.now
            }

            try CoreDataManager.save(context)

            let objectTypes = Array(Set(beamObjects.map { $0.beamObjectType }))
            Logger.shared.logDebug("Saved previous checksums for \(beamObjects.count) \(objectTypes) beamObjects",
                                   category: .beamObjectChecksum,
                                   localTimer: localTimer)
        }
    }

    static func savePreviousObjects(beamObjects: [BeamObject]) throws {
        guard !beamObjects.isEmpty else {
            Logger.shared.logWarning("No objects to save...", category: .beamObjectChecksum)
            return
        }

        // We don't save previous objects for anything else than document for now
        guard beamObjects.compactMap({ $0.beamObjectType == BeamObjectObjectType.document.rawValue }).contains(true) else { return }

        // swiftlint:disable:next date_init
        var localTimer = Date()

        let (checksums, context) = findChecksumsForBeamObjects(beamObjects: beamObjects)
        // swiftlint:disable:next date_init
        localTimer = Date()

        try context.performAndWait {
            for beamObject in beamObjects {
                guard beamObject.beamObjectType == BeamObjectObjectType.document.rawValue else {
                    continue
                }

                let checksum = checksums[beamObject] ?? BeamObjectChecksum(context: context)

                // Note: This is slow, we only store previousData for `Document` type, which is using smart merge.
                // Other beam objects use automatic merge (we overwrite the full data) and don't need previous saved data
                if beamObject.beamObjectType == BeamObjectObjectType.document.rawValue {
                    checksum.data_sent = try encoder.encode(beamObject)
                }

                checksum.id = checksum.id ?? beamObject.id
                checksum.object_type = checksum.object_type ?? beamObject.beamObjectType
                checksum.previous_checksum = beamObject.dataChecksum
                checksum.updated_at = BeamDate.now
            }

            try CoreDataManager.save(context)

            let objectTypes = Array(Set(beamObjects.map { $0.beamObjectType }))
            Logger.shared.logDebug("Saved previous data for \(beamObjects.count) \(objectTypes) beamObjects",
                                   category: .beamObjectChecksum,
                                   localTimer: localTimer)
        }
    }

    /// This will be much slower than using `savePreviousChecksums(beamObjects)`
    static func savePreviousChecksums<T: BeamObjectProtocol>(objects: [T]) throws {
        guard !objects.isEmpty else {
            Logger.shared.logWarning("No objects to save...", category: .beamObjectChecksum)
            return
        }

        // swiftlint:disable:next date_init
        let localTimer = Date()

        let (checksums, context) = findChecksumsForObjects(objects: objects)

        try context.performAndWait {
            for object in objects {
                let checksum = checksums[object] ?? BeamObjectChecksum(context: context)

                let beamObject = try BeamObject(object: object)

                checksum.id = checksum.id ?? beamObject.id
                checksum.object_type = checksum.object_type ?? type(of: object).beamObjectType.rawValue
                checksum.previous_checksum = beamObject.dataChecksum
                checksum.updated_at = BeamDate.now
            }

            try CoreDataManager.save(context)

            Logger.shared.logDebug("Saved previous checksums for \(objects.count) \(T.beamObjectType) objects",
                                   category: .beamObjectChecksum,
                                   localTimer: localTimer)
        }
    }

    /// This will be much slower than using `savePreviousChecksums(beamObjects)`
    static func savePreviousObject<T: BeamObjectProtocol>(objects: [T]) throws {
        guard !objects.isEmpty else {
            Logger.shared.logWarning("No objects to save...", category: .beamObjectChecksum)
            return
        }

        guard T.beamObjectType == BeamObjectObjectType.document else { return }

        // swiftlint:disable:next date_init
        let localTimer = Date()

        let (checksums, context) = findChecksumsForObjects(objects: objects)

        try context.performAndWait {
            for object in objects {
                let checksum = checksums[object] ?? BeamObjectChecksum(context: context)

                let beamObject = try BeamObject(object: object)

                // Note: This is slow, we only store previousData for `Document` type, which is using smart merge.
                // Other beam objects use automatic merge (we overwrite the full data) and don't need previous saved data
                if beamObject.beamObjectType == BeamObjectObjectType.document.rawValue {
                    checksum.data_sent = try encoder.encode(beamObject)
                }

                checksum.id = checksum.id ?? beamObject.id
                checksum.object_type = checksum.object_type ?? type(of: object).beamObjectType.rawValue
                checksum.previous_checksum = beamObject.dataChecksum
                checksum.updated_at = BeamDate.now
            }

            try CoreDataManager.save(context)

            Logger.shared.logDebug("Saved previous object for \(objects.count) \(T.beamObjectType) objects",
                                   category: .beamObjectChecksum,
                                   localTimer: localTimer)
        }
    }

    static func savePreviousChecksum(beamObject: BeamObject, noLog: Bool = false) throws {
        let (objectChecksum, context) = objectWithObject(object: beamObject)

        try context.performAndWait {
            guard !objectChecksum.isEqual(to: beamObject) else { return }

            objectChecksum.previous_checksum = beamObject.dataChecksum
            objectChecksum.updated_at = BeamDate.now

            if !noLog {
                Logger.shared.logDebug("Saving previous checksum for \(beamObject.description): \(objectChecksum.previous_checksum ?? "-")",
                                       category: .beamObjectChecksum)
            }

            try CoreDataManager.save(context)
        }
    }

    static func savePreviousObject(beamObject: BeamObject, noLog: Bool = false) throws {
        let (objectChecksum, context) = objectWithObject(object: beamObject)

        guard beamObject.beamObjectType == BeamObjectObjectType.document.rawValue else { return }

        try context.performAndWait {
            guard !objectChecksum.isEqual(to: beamObject) else { return }

            objectChecksum.previous_checksum = beamObject.dataChecksum
            objectChecksum.data_sent = try encoder.encode(beamObject)
            objectChecksum.updated_at = BeamDate.now

            if !noLog {
                Logger.shared.logDebug("Saving previous object for \(beamObject.description): \(objectChecksum.previous_checksum ?? "-")",
                                       category: .beamObjectChecksum)
            }

            try CoreDataManager.save(context)
        }
    }

    static func savePreviousChecksum<T: BeamObjectProtocol>(object: T, noLog: Bool = false) throws {
        let (objectChecksum, context) = objectWithObject(object: object)

        try context.performAndWait {
            let beamObject = try BeamObject(object: object)

            guard !objectChecksum.isEqual(to: object) else { return }

            objectChecksum.previous_checksum = beamObject.dataChecksum
            objectChecksum.updated_at = BeamDate.now

            if !noLog {
                Logger.shared.logDebug("Saving previous checksum for \(object.description): \(objectChecksum.previous_checksum ?? "-")",
                                       category: .beamObjectChecksum)
            }

            try CoreDataManager.save(context)
        }
    }

    static func savePreviousObject<T: BeamObjectProtocol>(object: T, noLog: Bool = false) throws {
        guard T.beamObjectType == BeamObjectObjectType.document else { return }

        let (objectChecksum, context) = objectWithObject(object: object)

        try context.performAndWait {
            let beamObject = try BeamObject(object: object)

            guard !objectChecksum.isEqual(to: object) else { return }

            objectChecksum.previous_checksum = beamObject.dataChecksum
            objectChecksum.data_sent = try encoder.encode(beamObject)
            objectChecksum.updated_at = BeamDate.now

            if !noLog {
                Logger.shared.logDebug("Saving previous object for \(object.description): \(objectChecksum.previous_checksum ?? "-")",
                                       category: .beamObjectChecksum)
            }

            try CoreDataManager.save(context)
        }
    }

    static func savePreviousObject<T: BeamObjectProtocol>(object: T, previousChecksum: String?) throws {
        guard T.beamObjectType == BeamObjectObjectType.document else { return }

        let (objectChecksum, context) = objectWithObject(object: object)

        let beamObject = try BeamObject(object: object)

        try context.performAndWait {
            objectChecksum.previous_checksum = previousChecksum
            objectChecksum.data_sent = try encoder.encode(beamObject)
            objectChecksum.updated_at = BeamDate.now

            Logger.shared.logDebug("Saving previous object for \(object.description): \(objectChecksum.previous_checksum ?? "-")",
                                   category: .beamObjectChecksum)

            try CoreDataManager.save(context)
        }
    }

    static func savePreviousChecksum<T: BeamObjectProtocol>(object: T, previousChecksum: String?) throws {
        let (objectChecksum, context) = objectWithObject(object: object)

        try context.performAndWait {
            objectChecksum.previous_checksum = previousChecksum
            objectChecksum.updated_at = BeamDate.now

            Logger.shared.logDebug("Saving previous checksum for \(object.description): \(objectChecksum.previous_checksum ?? "-")",
                                   category: .beamObjectChecksum)

            try CoreDataManager.save(context)
        }
    }

    // MARK: -
    // MARK: Privates

    private static func objectWithObject(object: BeamObject) -> (BeamObjectChecksum, NSManagedObjectContext) {
        let (result, context) = findObjectWithObject(object: object, create: true)

        return context.performAndWait {
            guard let result = result else {
                let result = BeamObjectChecksum(context: context)
                result.id = object.id
                result.object_type = object.beamObjectType
                return (result, context)
            }

            return (result, context)
        }
    }

    private static func findChecksumsForBeamObjects(beamObjects: [BeamObject]) -> ([BeamObject: BeamObjectChecksum], NSManagedObjectContext) {
        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()

        /*
         Because multiple beam objects type might have the same ID (but close to impossible) I first tried
         to add AND predicates for each objects like `(id = %@ AND object_type = %@) AND ...` but
         coredata fails with: Expression tree is too large (maximum depth 1000)

         Will do different just fetching IDs and the type after.

         let predicates: [NSPredicate] = beamObjects.map {
             var result: [NSPredicate] = []
             result.append(NSPredicate(format: "id = %@",
                                       $0.id as CVarArg))
             result.append(NSPredicate(format: "object_type = %@",
                                       $0.beamObjectType as CVarArg))

             return NSCompoundPredicate(andPredicateWithSubpredicates: result)
         }
         request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

         */

        request.predicate = NSPredicate(format: "id IN %@", beamObjects.map { $0.id })

        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        do {
            var result: [BeamObject: BeamObjectChecksum] = [:]

            try context.performAndWait {
                // Fetch all checksums
                let storedChecksums: [String: BeamObjectChecksum] = try context.fetch(request).reduce(into: [:], { dict, checksum in
                    guard let id = checksum.id, let object_type = checksum.object_type else { return }

                    dict["\(id.uuidString)::\(object_type)"] = checksum
                })

                // Set all checksums for objects
                for beamOject in beamObjects {
                    guard let checksum = storedChecksums["\(beamOject.id.uuidString)::\(beamOject.beamObjectType)"] else {
                        continue
                    }

                    if let object_type = checksum.object_type, object_type != beamOject.beamObjectType {
                        Logger.shared.logError("Very weird, types don't match: \(object_type) != \(beamOject.beamObjectType)",
                                               category: .beamObjectChecksum)

                        // Congrats, you found an unexpected issue with a beam object ID and a different type
                        assert(false)
                        continue
                    }

                    result[beamOject] = checksum
                }
            }

            return (result, context)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .beamObjectChecksum)
        }

        assert(false)

        var result: [BeamObject: BeamObjectChecksum] = [:]
        beamObjects.forEach {
            let checksum = BeamObjectChecksum(context: context)
            checksum.id = $0.id
            checksum.object_type = $0.beamObjectType
            result[$0] = checksum
        }

        return (result, context)
    }

    private static func findChecksumsForObjects<T: BeamObjectProtocol>(objects: [T]) -> ([T: BeamObjectChecksum], NSManagedObjectContext) {
        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()

        /*
         Because multiple beam objects type might have the same ID (but close to impossible) I first tried
         to add AND predicates for each objects like `(id = %@ AND object_type = %@) AND ...` but
         coredata fails with: Expression tree is too large (maximum depth 1000)

         Will do different just fetching IDs and the type after.

         let predicates: [NSPredicate] = objects.map {
             var result: [NSPredicate] = []
             result.append(NSPredicate(format: "id = %@",
                                       $0.beamObjectId as CVarArg))
             result.append(NSPredicate(format: "object_type = %@",
                                       type(of: $0).beamObjectType.rawValue as CVarArg))

             return NSCompoundPredicate(andPredicateWithSubpredicates: result)
         }
         request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

         */

        request.predicate = NSPredicate(format: "id IN %@", objects.map { $0.beamObjectId })

        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        do {
            var result: [T: BeamObjectChecksum] = [:]

            try context.performAndWait {
                let storedChecksums: [String: BeamObjectChecksum] = try context.fetch(request).reduce(into: [:], { dict, checksum in
                    guard let id = checksum.id, let object_type = checksum.object_type else { return }

                    dict["\(id.uuidString)::\(object_type)"] = checksum
                })

                for object in objects {
                    guard let checksum = storedChecksums["\(object.beamObjectId.uuidString)::\(type(of: object).beamObjectType.rawValue)"] else {
                        continue
                    }

                    if let object_type = checksum.object_type, object_type != type(of: object).beamObjectType.rawValue {
                        Logger.shared.logError("Very weird, types don't match: \(object_type) != \(type(of: object).beamObjectType.rawValue)",
                                               category: .beamObjectChecksum)

                        // Congrats, you found an unexpected issue with a beam object ID and a different type
                        assert(false)

                        continue
                    }

                    result[object] = checksum
                }
            }

            return (result, context)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .beamObjectChecksum)
        }

        assert(false)

        var result: [T: BeamObjectChecksum] = [:]
        objects.forEach {
            let checksum = BeamObjectChecksum(context: context)
            checksum.id = $0.beamObjectId
            checksum.object_type = type(of: $0).beamObjectType.rawValue
            result[$0] = checksum
        }

        return (result, context)
    }

    private static func findObjectWithObject(object: BeamObject, create: Bool = false) -> (BeamObjectChecksum?, NSManagedObjectContext) {
        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()
        request.fetchLimit = 1

        let beamObjectType: BeamObjectObjectType? = BeamObjectObjectType.fromString(value: object.beamObjectType)

        if let beamObjectType = beamObjectType {
            request.predicate = predicates(id: object.id, type: beamObjectType)
        } else {
            // Shouldn't happen, we always want a type
            assert(false)
        }

        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        return context.performAndWait {
            ((try? context.fetch(request))?.first, context)
        }
    }

    private static func objectWithObject<T: BeamObjectProtocol>(object: T) -> (BeamObjectChecksum, NSManagedObjectContext) {
        let (result, context) = findObjectWithObject(object: object, create: true)

        return context.performAndWait {
            guard let result = result else {
                let result = BeamObjectChecksum(context: context)
                result.id = object.beamObjectId
                result.object_type = type(of: object).beamObjectType.rawValue
                return (result, context)
            }

            return (result, context)
        }
    }

    private static func findObjectWithObject<T: BeamObjectProtocol>(object: T, create: Bool = false) -> (BeamObjectChecksum?, NSManagedObjectContext) {
        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()
        request.fetchLimit = 1
        request.predicate = predicates(id: object.beamObjectId, type: type(of: object).beamObjectType)

        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        return context.performAndWait {
            ((try? context.fetch(request))?.first, context)
        }
    }

    private static func predicates(id: UUID, type: BeamObjectObjectType) -> NSPredicate {
        var predicates: [NSPredicate] = []
        predicates.append(NSPredicate(format: "id = %@",
                                      id as CVarArg))
        predicates.append(NSPredicate(format: "object_type = %@",
                                      type.rawValue as CVarArg))

        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
