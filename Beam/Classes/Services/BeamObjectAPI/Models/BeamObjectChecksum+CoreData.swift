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

        if let objects = try? context.fetch(request) {
            for objectChecksum in objects {
                if let id = objectChecksum.id {
                    result[id] = objectChecksum.previous_checksum
                }
            }
        }

        return result
    }

    /// I use `BeamObject` as the result key because the 100% way to be unique is a combined object type + object id
    static func previousChecksums(beamObjects: [BeamObject]) -> [BeamObject: String] {
        let (checksums, _) = findChecksumsForBeamObjects(beamObjects: beamObjects)
        var result: [BeamObject: String] = [:]

        checksums.forEach { (key, value) in
            result[key] = value.previous_checksum
        }

        return result
    }

    static func sentData<T: BeamObjectProtocol>(object: T) -> Data? {
        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()
        request.fetchLimit = 1
        request.predicate = predicates(id: object.beamObjectId, type: type(of: object).beamObjectType)

        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        if let objects = try? context.fetch(request) {
            return objects.first?.data_sent
        }

        return nil
    }

    static func previousSavedObject<T: BeamObjectProtocol>(object: T) throws -> T? {
        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()
        request.fetchLimit = 1
        request.predicate = predicates(id: object.beamObjectId, type: type(of: object).beamObjectType)

        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        guard let objects = try? context.fetch(request), let previousData = objects.first?.data_sent else { return nil }

        let beamObject = try Self.decoder.decode(BeamObject.self, from: previousData)
        return try beamObject.decodeBeamObject()
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
        context.delete(objectChecksum)
        try CoreDataManager.save(context)
    }

    static func deletePreviousChecksum(beamObject: BeamObject) throws {
        Logger.shared.logDebug("Deleting previous checksums for \(beamObject.description)",
                               category: .beamObjectChecksum)

        let (objectChecksum, context) = objectWithObject(object: beamObject)
        context.delete(objectChecksum)
        try CoreDataManager.save(context)
    }

    static func deletePreviousChecksums(type: BeamObjectObjectType) throws {
        Logger.shared.logDebug("Deleting previous checksums for type \(type)",
                               category: .beamObjectChecksum)

        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()
        request.predicate = NSPredicate(format: "object_type = %@",
                                        type.rawValue as CVarArg)

        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        for object in try context.fetch(request) {
            context.delete(object)
        }

        try CoreDataManager.save(context)
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
        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        for object in try context.fetch(request) {
            context.delete(object)
        }

        try CoreDataManager.save(context)
    }

    // MARK: -
    // MARK: Saves

    func isEqual(to object: BeamObject) -> Bool {
        self.previous_checksum == object.dataChecksum &&
        self.data_sent == (try? Self.encoder.encode(object))
    }

    static func savePreviousChecksums(beamObjects: [BeamObject]) throws {
        var localTimer = BeamDate.now

        let (checksums, context) = self.findChecksumsForBeamObjects(beamObjects: beamObjects)

        Logger.shared.logDebug("Found or created previous checksum objects for \(beamObjects.count) beamObjects",
                               category: .beamObjectChecksum,
                               localTimer: localTimer)

        localTimer = BeamDate.now

        for beamObject in beamObjects {
            guard let checksum = checksums[beamObject] else { assert(false); continue }

            checksum.previous_checksum = beamObject.dataChecksum

            // Note: This is slow, we only store previousData for `Document` type, which is using smart merge.
            // Other beam objects use automatic merge (we overwrite the full data) and don't need previous saved data
            if beamObject.beamObjectType == BeamObjectObjectType.document.rawValue {
                checksum.data_sent = try encoder.encode(beamObject)
            }

            checksum.updated_at = BeamDate.now
        }

        try CoreDataManager.save(context)

        Logger.shared.logDebug("Saved previous checksums for \(beamObjects.count) beamObjects",
                               category: .beamObjectChecksum,
                               localTimer: localTimer)
    }

    /// This will be much slower than using `savePreviousChecksums(beamObjects)`
    static func savePreviousChecksums<T: BeamObjectProtocol>(objects: [T]) throws {
        let localTimer = BeamDate.now

        let (checksums, context) = self.findChecksumsForObjects(objects: objects)

        for object in objects {
            guard let checksum = checksums[object] else { assert(false); continue }

            let beamObject = try BeamObject(object: object)

            checksum.previous_checksum = beamObject.dataChecksum

            // Note: This is slow, we only store previousData for `Document` type, which is using smart merge.
            // Other beam objects use automatic merge (we overwrite the full data) and don't need previous saved data
            if beamObject.beamObjectType == BeamObjectObjectType.document.rawValue {
                checksum.data_sent = try encoder.encode(beamObject)
            }
            checksum.updated_at = BeamDate.now
        }

        try CoreDataManager.save(context)

        Logger.shared.logDebug("Saved previous checksums for \(objects.count) \(T.beamObjectType) objects",
                               category: .beamObjectChecksum,
                               localTimer: localTimer)
    }

    static func savePreviousChecksum(beamObject: BeamObject, noLog: Bool = false) throws {
        let (objectChecksum, context) = objectWithObject(object: beamObject)

        guard !objectChecksum.isEqual(to: beamObject) else { return }

        objectChecksum.previous_checksum = beamObject.dataChecksum
        objectChecksum.data_sent = try encoder.encode(beamObject)
        objectChecksum.updated_at = BeamDate.now

        if !noLog {
            Logger.shared.logDebug("Saving previous checksum for \(beamObject.description): \(objectChecksum.previous_checksum ?? "-")",
                                   category: .beamObjectChecksum)
        }

        try CoreDataManager.save(context)
    }

    static func savePreviousChecksum<T: BeamObjectProtocol>(object: T, noLog: Bool = false) throws {
        let (objectChecksum, context) = objectWithObject(object: object)

        let beamObject = try BeamObject(object: object)

        guard !objectChecksum.isEqual(to: object) else { return }

        objectChecksum.previous_checksum = beamObject.dataChecksum
        objectChecksum.data_sent = try encoder.encode(beamObject)
        objectChecksum.updated_at = BeamDate.now

        if !noLog {
            Logger.shared.logDebug("Saving previous checksum for \(object.description): \(objectChecksum.previous_checksum ?? "-")",
                                   category: .beamObjectChecksum)
        }

        try CoreDataManager.save(context)
    }

    static func savePreviousChecksum<T: BeamObjectProtocol>(object: T, previousChecksum: String?) throws {
        let (objectChecksum, context) = objectWithObject(object: object)

        let beamObject = try BeamObject(object: object)

        objectChecksum.previous_checksum = previousChecksum
        objectChecksum.data_sent = try encoder.encode(beamObject)
        objectChecksum.updated_at = BeamDate.now

        Logger.shared.logDebug("Saving previous checksum for \(object.description): \(objectChecksum.previous_checksum ?? "-")",
                               category: .beamObjectChecksum)

        try CoreDataManager.save(context)
    }

    // MARK: -
    // MARK: Privates

    private static func objectWithObject(object: BeamObject) -> (BeamObjectChecksum, NSManagedObjectContext) {
        let (result, context) = findObjectWithObject(object: object, create: true)

        guard let result = result else {
            let result = BeamObjectChecksum(context: context)
            result.id = object.id
            result.object_type = object.beamObjectType
            return (result, context)
        }

        return (result, context)
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
            let storedChecksums: [String: BeamObjectChecksum] = try context.fetch(request).reduce(into: [:], { dict, checksum in
                guard let id = checksum.id, let object_type = checksum.object_type else { return }

                dict["\(id.uuidString)::\(object_type)"] = checksum
            })

            var result: [BeamObject: BeamObjectChecksum] = [:]
            beamObjects.forEach {
                var checksum = storedChecksums["\($0.id.uuidString)::\($0.beamObjectType)"] ?? BeamObjectChecksum(context: context)

                if let object_type = checksum.object_type, object_type != $0.beamObjectType {
                    // Congrats, you found an unexpected issue with a beam object ID and a different type
                    assert(false)

                    checksum = BeamObjectChecksum(context: context)
                }

                checksum.id = checksum.id ?? $0.id
                checksum.object_type = checksum.object_type ?? $0.beamObjectType
                result[$0] = checksum
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
            let storedChecksums: [String: BeamObjectChecksum] = try context.fetch(request).reduce(into: [:], { dict, checksum in
                guard let id = checksum.id, let object_type = checksum.object_type else { return }

                dict["\(id.uuidString)::\(object_type)"] = checksum
            })

            var result: [T: BeamObjectChecksum] = [:]
            objects.forEach {
                let checksum = storedChecksums["\($0.beamObjectId.uuidString)::\(type(of: $0).beamObjectType.rawValue)"] ?? BeamObjectChecksum(context: context)

                if let object_type = checksum.object_type, object_type != type(of: $0).beamObjectType.rawValue {
                    // Congrats, you found an unexpected issue with a beam object ID and a different type
                    assert(false)
                }

                checksum.id = checksum.id ?? $0.beamObjectId
                checksum.object_type = checksum.object_type ?? type(of: $0).beamObjectType.rawValue
                result[$0] = checksum
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

        return ((try? context.fetch(request))?.first, context)
    }

    private static func objectWithObject<T: BeamObjectProtocol>(object: T) -> (BeamObjectChecksum, NSManagedObjectContext) {
        let (result, context) = findObjectWithObject(object: object, create: true)

        guard let result = result else {
            let result = BeamObjectChecksum(context: context)
            result.id = object.beamObjectId
            result.object_type = type(of: object).beamObjectType.rawValue
            return (result, context)
        }

        return (result, context)
    }

    private static func findObjectWithObject<T: BeamObjectProtocol>(object: T, create: Bool = false) -> (BeamObjectChecksum?, NSManagedObjectContext) {
        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()
        request.fetchLimit = 1
        request.predicate = predicates(id: object.beamObjectId, type: type(of: object).beamObjectType)

        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        return ((try? context.fetch(request))?.first, context)
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
