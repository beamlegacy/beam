import Foundation
import CoreData
import BeamCore

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
        if let type = BeamObjectObjectType(rawValue: beamObject.beamObjectType) {
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

    static func previousChecksums(beamObjects: [BeamObject]) -> [UUID: String] {
        var result: [UUID: String] = [:]
        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()
        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        var predicates: [NSPredicate] = []
        predicates.append(NSPredicate(format: "id IN %@",
                                      beamObjects.compactMap { $0.id } as CVarArg))

        if let objects = try? context.fetch(request) {
            for objectChecksum in objects {
                if let id = objectChecksum.id {
                    result[id] = objectChecksum.previous_checksum
                }
            }
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
        Logger.shared.logDebug("Deleting previous checksums for \(object.description)", category: .beamObject)

        let (objectChecksum, context) = objectWithObject(object: object)
        context.delete(objectChecksum)
        try CoreDataManager.save(context)
    }

    static func deletePreviousChecksum(beamObject: BeamObject) throws {
        Logger.shared.logDebug("Deleting previous checksums for \(beamObject.description)", category: .beamObject)

        let (objectChecksum, context) = objectWithObject(object: beamObject)
        context.delete(objectChecksum)
        try CoreDataManager.save(context)
    }

    static func deletePreviousChecksums(type: BeamObjectObjectType) throws {
        Logger.shared.logDebug("Deleting previous checksums for type \(type)", category: .beamObject)

        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()
        request.predicate = NSPredicate(format: "object_type = %@",
                                        type.rawValue as CVarArg)

        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        for object in try context.fetch(request) {
            context.delete(object)
        }

        try CoreDataManager.save(context)
    }

    static func deletePreviousChecksums<T: BeamObjectProtocol>(objects: [T]) throws {
        for object in objects {
            try deletePreviousChecksum(object: object)
        }
    }

    static func deleteAll() throws {
        Logger.shared.logDebug("Deleted all checksums", category: .beamObject)
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
        Logger.shared.logDebug("Saving previous checksums for \(beamObjects.count) objects", category: .beamObject)

        for beamObject in beamObjects {
            try savePreviousChecksum(beamObject: beamObject)
        }
    }

    static func savePreviousChecksums<T: BeamObjectProtocol>(objects: [T]) throws {
        for object in objects {
            try savePreviousChecksum(object: object)
        }
    }

    static func savePreviousChecksum(beamObject: BeamObject) throws {
        let (objectChecksum, context) = objectWithObject(object: beamObject)

        guard !objectChecksum.isEqual(to: beamObject) else { return }

        objectChecksum.previous_checksum = beamObject.dataChecksum
        objectChecksum.data_sent = try encoder.encode(beamObject)
        objectChecksum.updated_at = BeamDate.now

        Logger.shared.logDebug("Saving previous checksums for \(beamObject.description): \(objectChecksum.previous_checksum ?? "-")",
                               category: .beamObject)

        try CoreDataManager.save(context)
    }

    static func savePreviousChecksum<T: BeamObjectProtocol>(object: T) throws {
        let (objectChecksum, context) = objectWithObject(object: object)

        let beamObject = try BeamObject(object: object)

        guard !objectChecksum.isEqual(to: object) else { return }

        objectChecksum.previous_checksum = beamObject.dataChecksum
        objectChecksum.data_sent = try encoder.encode(beamObject)
        objectChecksum.updated_at = BeamDate.now

        Logger.shared.logDebug("Saving previous checksums for \(object.description): \(objectChecksum.previous_checksum ?? "-")",
                               category: .beamObject)

        try CoreDataManager.save(context)
    }

    static func savePreviousChecksum<T: BeamObjectProtocol>(object: T, previousChecksum: String?) throws {
        let (objectChecksum, context) = objectWithObject(object: object)

        let beamObject = try BeamObject(object: object)

        objectChecksum.previous_checksum = previousChecksum
        objectChecksum.data_sent = try encoder.encode(beamObject)
        objectChecksum.updated_at = BeamDate.now

        Logger.shared.logDebug("Saving previous checksums for \(object.description): \(objectChecksum.previous_checksum ?? "-")",
                               category: .beamObject)

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

    private static func findObjectWithObject(object: BeamObject, create: Bool = false) -> (BeamObjectChecksum?, NSManagedObjectContext) {

        let request: NSFetchRequest<BeamObjectChecksum> = BeamObjectChecksum.fetchRequest()
        request.fetchLimit = 1
        request.predicate = predicates(id: object.id, type: BeamObjectObjectType(rawValue: object.beamObjectType)!)

        let context = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        return ((try? context.fetch(request))?.first, context)
    }

    private static func objectWithObject(object: BeamObjectProtocol) -> (BeamObjectChecksum, NSManagedObjectContext) {
        let (result, context) = findObjectWithObject(object: object, create: true)

        guard let result = result else {
            let result = BeamObjectChecksum(context: context)
            result.id = object.beamObjectId
            result.object_type = type(of: object).beamObjectType.rawValue
            return (result, context)
        }

        return (result, context)
    }

    private static func findObjectWithObject(object: BeamObjectProtocol, create: Bool = false) -> (BeamObjectChecksum?, NSManagedObjectContext) {
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
