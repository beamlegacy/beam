import Foundation
import CoreData

protocol BeamCoreDataObject {
    associatedtype ObjectType = Self

    // MARK: Deletes
    static func deleteWithPredicate(_ context: NSManagedObjectContext, _ predicate: NSPredicate?) throws
    func delete(_ context: NSManagedObjectContext)

    // MARK: Creations
    static func create(_ context: NSManagedObjectContext, title: String?) -> ObjectType
    static func fetchOrCreateWithId(_ context: NSManagedObjectContext, _ id: UUID) -> ObjectType

    static func rawFetchOrCreateWithId(_ context: NSManagedObjectContext, _ id: UUID) -> ObjectType

    // MARK: Fetches
    static func fetchFirst(_ context: NSManagedObjectContext,
                           _ predicate: NSPredicate?,
                           _ sortDescriptors: [NSSortDescriptor]?) throws -> ObjectType?
    static func fetchAll(_ context: NSManagedObjectContext,
                         _ predicate: NSPredicate?,
                         _ sortDescriptors: [NSSortDescriptor]?) throws -> [ObjectType]
    static func fetchAllWithLimit(_ context: NSManagedObjectContext,
                                  _ predicate: NSPredicate?,
                                  _ sortDescriptors: [NSSortDescriptor]?,
                                  _ limit: Int,
                                  _ fetchOffset: Int) throws -> [ObjectType]
    static func fetchWithId(_ context: NSManagedObjectContext, _ id: UUID) throws -> ObjectType?

    // MARK: Raw Fetches
    static func rawFetchAllWithLimit(_ context: NSManagedObjectContext,
                                     _ predicate: NSPredicate?,
                                     _ sortDescriptors: [NSSortDescriptor]?,
                                     _ limit: Int,
                                     _ fetchOffset: Int) throws -> [ObjectType]
    static func rawFetchAll(_ context: NSManagedObjectContext,
                            _ predicate: NSPredicate? ,
                            _ sortDescriptors: [NSSortDescriptor]?) throws -> [ObjectType]
    static func rawFetchFirst(_ context: NSManagedObjectContext,
                              _ predicate: NSPredicate?,
                              _ sortDescriptors: [NSSortDescriptor]?) throws -> ObjectType?

    // MARK: Counts
    static func countWithPredicate(_ context: NSManagedObjectContext,
                                   _ predicate: NSPredicate?) -> Int
    static func rawCountWithPredicate(_ context: NSManagedObjectContext,
                                      _ predicate: NSPredicate?) -> Int
}
