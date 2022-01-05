import Foundation
import CoreData

enum CoreDataMigrationVersion: String, CaseIterable {
    case version1 = "Beam"
    case version2 = "Beam2"
    case version3 = "Beam3"
    case version4 = "Beam4"
    case version5 = "Beam5"
    case version6 = "Beam6"
    case version7 = "Beam7"
    case version8 = "Beam8"
    case version9 = "Beam9"
    case version10 = "Beam10"

    // TODO: when adding a migration, fix the test named `it("imports its own backup")` with a new BeamExport.sqlite

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
            return .version3
        case .version3:
            return .version4
        case .version4:
            return .version5
        case .version5:
            return .version6
        case .version6:
            return .version7
        case .version7:
            return .version8
        case .version8:
            return .version9
        case .version9:
            return .version10
        case .version10:
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
