import CoreData

/*
 To avoid a bug when running 2 targets and CoreData, see:
 https://forums.raywenderlich.com/t/multiple-warnings-when-running-unit-tests-in-sample-app/74860/10
 https://github.com/drewmccormack/ensembles/issues/275
 */
public extension NSManagedObject {
    convenience init(context: NSManagedObjectContext) {
        let name = String(describing: type(of: self))
        let entity = NSEntityDescription.entity(forEntityName: name, in: context)!
        self.init(entity: entity, insertInto: context)
    }
}
