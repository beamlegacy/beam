import Foundation

final class BeamObjectQueue<Object: BeamObjectProtocol> {
    private final class Operation {
        private let objects: [Object]
        private let results: Results
        private let group: DispatchGroup
        private let block: ([Object]) async throws -> [Object]

        init(objects: [Object], results: Results, group: DispatchGroup, block: @escaping ([Object]) async throws -> [Object]) {
            self.objects = objects
            self.results = results
            self.group = group
            self.block = block

            group.enter()
        }

        func run() async {
            do {
                results.append(try await block(objects))
            } catch {
                results.setError(error)
            }
            group.leave()
        }
    }

    private final class Results: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var results: [Object] = []
        private(set) var error: Error? = nil

        func append(_ results: [Object]) {
            lock {
                self.results.append(contentsOf: results)
            }
        }

        func setError(_ error: Error) {
            lock {
                self.error = error
            }
        }
    }

    private let lock = NSLock()
    private var pendings: [UUID: [Operation]] = [:]
    private var currents: Set<UUID> = []

    /// Operate on objects serially *per object id*, deferring operations on already operating ids to a later time.
    /// Important: the `block` parameter may be called multiple times.
    @discardableResult
    func addOperation(for objects: [Object], block: @escaping ([Object]) async throws -> [Object]) async throws -> [Object] {
        return try await withCheckedThrowingContinuation { continuation in
            let group = DispatchGroup()
            let results = Results()
            let objectsByUUIDs = Dictionary(grouping: objects, by: \.beamObjectId)

            // We enter the group now to keep it alive while we add our notify block which we need
            // to do before adding operations to the pendings.
            group.enter()
            group.notify(queue: .userInitiated) {
                if let error = results.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results.results)
                }
            }

            let readyToRun = lock { () -> (uuids: [UUID], operation: Operation)? in
                var readyUUIDs: [UUID] = []
                var readyObjects: [Object] = []
                for (uuid, objects) in objectsByUUIDs {
                    if currents.contains(uuid) {
                        let operation = Operation(objects: objects, results: results, group: group, block: block)
                        pendings[uuid, default: []].append(operation)
                    } else {
                        currents.insert(uuid)
                        readyUUIDs.append(uuid)
                        readyObjects.append(contentsOf: objects)
                    }
                }
                guard !readyObjects.isEmpty else { return nil }
                return (readyUUIDs, Operation(objects: readyObjects, results: results, group: group, block: block))
            }

            group.leave()

            guard let readyToRun = readyToRun else { return }

            Task {
                await readyToRun.operation.run()

                for uuid in readyToRun.uuids {
                    guard let nextOperation = self.nextOperation(for: uuid) else { continue }

                    Task.detached {
                        await nextOperation.run()

                        while let nextOperation = self.nextOperation(for: uuid) {
                            await nextOperation.run()
                        }
                    }
                }
            }
        }
    }

    private func nextOperation(for uuid: UUID) -> Operation? {
        return lock {
            if (pendings[uuid] ?? []).isEmpty {
                currents.remove(uuid)
                return nil
            }
            return pendings[uuid]?.removeFirst()
        }
    }
}
