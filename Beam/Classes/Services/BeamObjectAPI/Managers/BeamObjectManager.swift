import Foundation
import BeamCore
import Combine

enum BeamObjectConflictResolution {
    case replace
    case fetchRemoteAndError
}

enum BeamObjectRequestUploadType {
    case directUpload
    case multipartUpload
}

enum BeamObjectObjectType: String {
    case password
    case creditCard
    case link
    case database
    case browsingTree = "browsing_tree"
    case file
    case document
    case myRemoteObject = "my_remote_object"
    case contact
    case noteFrecency = "note_frecency"
    case privateKeySignature
    case tabGroup

    static func fromString(value: String) -> Self? {
        BeamObjectObjectType(rawValue: value)
    }
}

/// Stub — remote sync removed. Managers still register but no sync occurs.
public final class BeamObjectManager {
    var managerInstances: [BeamObjectObjectType: BeamObjectManagerDelegateProtocol] = [:]
    var disableSendingObjects = true
    var uploadTypeForTests: BeamObjectRequestUploadType?

    #if DEBUG
    var networkRequests: [Any] = []
    #endif

    func register<M: BeamObjectManagerDelegateProtocol, O: BeamObjectProtocol>(_ manager: M, object: O.Type) {
        managerInstances[object.beamObjectType] = manager
    }

    func unregister(objectType: BeamObjectObjectType) {
        managerInstances.removeValue(forKey: objectType)
    }

    func unregisterAll() {
        managerInstances = [:]
    }

    func setup() {}
    func liveSync(_ firstCall: Bool = true, _ handler: @escaping (Bool, Bool) -> Void) {
        handler(false, false)
    }
    func disconnectLiveSync() {}
    func clearNetworkCalls() {
        #if DEBUG
        networkRequests.removeAll()
        #endif
    }
    func isAllNetworkCallsCompleted() -> Bool { true }
}
