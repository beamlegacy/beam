import Foundation
import CoreData

enum CoreDataMigrationVersion: String, CaseIterable {
    case version1 = "Beam"
    case version2 = "Beam2"

    // MARK: - Current

    static var current: CoreDataMigrationVersion {
        guard let current = allCases.last else {
            fatalError("no model versions found")
        }

        return current
    }

    // MARK: - Migration

    func nextVersion() -> CoreDataMigrationVersion? {
        switch self {
        case .version1:
            return .version2
        case .version2:
            return nil
        }
    }
}

extension CoreDataMigrationVersion {
    // MARK: - Compatible
    static func compatibleVersionForStoreMetadata(_ metadata: [String: Any]) -> CoreDataMigrationVersion? {
        let compatibleVersion = CoreDataMigrationVersion.allCases.first {
            let model = NSManagedObjectModel.managedObjectModel(forResource: $0.rawValue)

            return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }

        return compatibleVersion
    }
}
