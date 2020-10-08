import Foundation
import CoreData

class Bullet: NSManagedObject {
    override func awakeFromInsert() {
        super.awakeFromInsert()
        created_at = Date()
        id = UUID()
    }

    override var debugDescription: String {
        return content ?? "No title"
    }

    func sortedChildren() -> [Bullet] {
        guard let children = children else { return [] }

        let results = Array(children).compactMap { $0 as? Bullet }

        return results.sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    func treeBullets(_ tabCount: Int = 0) -> [Any]? {
        guard let children = children, children.count > 0 else {
            return [self]
        }

        let results: [Any] = [self, sortedChildren().compactMap { $0.treeBullets(tabCount + 1) }]

        return results
    }

    class func maxOrderIndex(_ context: NSManagedObjectContext, note: Note) -> Int32 {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Bullet")
        fetchRequest.resultType = .dictionaryResultType

        let keypathExpression = NSExpression(forKeyPath: "orderIndex")
        let maxExpression = NSExpression(forFunction: "max:", arguments: [keypathExpression])

        let key = "orderIndex"

        let expressionDescription = NSExpressionDescription()
        expressionDescription.name = key
        expressionDescription.expression = maxExpression
        expressionDescription.expressionResultType = .integer32AttributeType

        fetchRequest.propertiesToFetch = [expressionDescription]

        do {
            if let result = try context.fetch(fetchRequest) as? [[String: Int32]],
               let dict = result.first,
               let maxOrderIndex = dict[key] {
                return maxOrderIndex
            }

        } catch {
            assertionFailure("Failed to fetch max orderIndex with error = \(error)")
        }

        return 0
    }
}
