import Foundation
import CoreData

extension Database {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Database> {
        return NSFetchRequest<Database>(entityName: "Database")
    }

    //swiftlint:disable identifier_name
    @NSManaged public var id: UUID
    @NSManaged public var created_at: Date
    @NSManaged public var updated_at: Date
    @NSManaged public var deleted_at: Date?
    @NSManaged public var title: String
    //swiftlint:enable identifier_name
}

extension Database: Identifiable {

}
