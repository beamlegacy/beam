import Foundation

class BeamObjectManagerCall {
    private static let semaphore = DispatchSemaphore(value: 1)
    private static var objects: [UUID: DispatchSemaphore] = [:]

    static func objectSemaphore(uuid: UUID) -> DispatchSemaphore {
        semaphore.wait()
        defer { semaphore.signal() }

        objects[uuid] = objects[uuid] ?? DispatchSemaphore(value: 1)
        return objects[uuid]!
    }

    static func deleteObjectSemaphore(uuid: UUID) {
        semaphore.wait()
        defer { semaphore.signal() }

        objects.removeValue(forKey: uuid)
    }

    static func objectsSemaphores(uuids: [UUID]) -> [DispatchSemaphore] {
        semaphore.wait()
        defer { semaphore.signal() }

        return uuids.map { uuid in
            objects[uuid] = objects[uuid] ?? DispatchSemaphore(value: 1)
            return objects[uuid]!
        }
    }

    static func deleteObjectsSemaphores(uuids: [UUID]) {
        semaphore.wait()
        defer { semaphore.signal() }

        uuids.forEach { objects.removeValue(forKey: $0) }
    }
}
