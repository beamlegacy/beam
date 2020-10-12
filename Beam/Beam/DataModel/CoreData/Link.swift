import Foundation
import CoreData

@objc(Link)
class Link: NSManagedObject {
    override func awakeFromInsert() {
        super.awakeFromInsert()
        created_at = Date()
    }
}
