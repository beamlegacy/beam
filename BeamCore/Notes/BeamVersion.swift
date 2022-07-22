//
//  BeamVersion.swift
//  BeamCore
//
//  Created by Sébastien Metrot on 12/07/2022.
//

import Foundation

/// BeamVersion is a vector clock versioning system. A Vector clock is a logical clock. It enable us to have comparable clocks from different systems without relying on an absolute clock that is bound to diverge in a byzantine multi machine setup. You can learn more about logical clocks and vector clocks in particular in this video https://www.youtube.com/watch?v=x-D8iFU1d-o (this guys has many videos on distributed computing and CRDT that are well worth watching BTW!).
/// We use BeamVersion to store the version of a document as is enables us to detect how to versions of a document relate to each other. If we have version A and version B we can compare them to know if:
/// A == B: They are the same version, all is good
/// A -> B: A is a direct ancestor of B, that is we can safely update A to B without losing data.
/// B -> A: B is a direct ancestor of A, in which case we alrady have A as the latest version or the document and don't need to do anything.
/// A # B: A and B are not comparable, which mean they are in conflict. Sometime in the life of A and B they started to diverge and there is no fast forward path from one version to the other. We need to merge and try to solve the conflict in order to restore ordre to the chaos.
/// BeamVersion uses a local machine Id that we try to persist on a singular install of the app (ideally per user). It's not the responsibility of BeamVersion to decide how this local Id is computed (have a look at AppDelegate to see how we do it).
public struct BeamVersion: Codable {
    public static private(set) var deviceId: UUID = UUID()
    public private(set) var vector: [UUID: Int]

    /// Set the local device Id. The device Id is ideal generated just once for the life of the app on the machine. It should be per machine AND per user.
    public static func setupLocalDevice(_ id: UUID?) {
        guard let id = id else { return }
        deviceId = id
    }

    /// Build a BeamVersion from a version vector. By default it creates an initial local version.
    public init(_ vector: [UUID: Int] = [Self.deviceId: 0]) {
        self.vector = vector
    }

    /// Build a version with the given initial local version number. This is used to move old plain versions to a BeamVersion for previously saved documents. Do not use it in any other case
    public init(localVersion: Int) {
        self.init([Self.deviceId: localVersion])
    }

    /// The local version, without taking other machines into account.
    public var localVersion: Int {
        vector[Self.deviceId] ?? 0
    }

    /// Return the next version for self (which could be the initial version)
    public func incremented() -> Self {
        var v = BeamVersion(vector)
        v.vector[Self.deviceId] = (v.vector[Self.deviceId] ?? -1) + 1
        return v
    }

    /// Return true is for lhs and rhs are equivalent versions (their vectors may differ)
    /// V1 = V2 , iff V1[i] = V2[i], for all i = 1 to N (i.e, V1 and V2 are equal if and only if all the corresponding values in their vector matches)
    public static func == (lhs: BeamVersion, rhs: BeamVersion) -> Bool {
        lhs.vector == rhs.vector
    }

    /// Sementically compare version to order them. Beware that A ≤ B and B ≤ A may both be false at the same time (which means that they are incomparable)
    /// V1 ≤ V2 , iff V1[i] ≤ V2[i], for all i = 1 to N
    public static func <= (lhs: BeamVersion, rhs: BeamVersion) -> Bool {
        let keys = Set(lhs.vector.keys).union(Set(rhs.vector.keys))
        return !keys.contains { k in
            (lhs.vector[k] ?? -1) > (rhs.vector[k] ?? -1)
        }
    }

    /// Sementically compare two versions. If A < B, it means that there is a fast forward path from A to B.
    /// V1 < V2 , iff  V1 ≤ V2 & there exists a j such that 1 ≤ j ≤ N & V1[j] < V2[j]
    public static func < (lhs: BeamVersion, rhs: BeamVersion) -> Bool {
        let keys = Set(lhs.vector.keys).union(Set(rhs.vector.keys))
        guard !keys.contains(where: { k in
            (lhs.vector[k] ?? -1) > (rhs.vector[k] ?? -1)
        }) else { return false }

        return keys.contains { k in
            (lhs.vector[k] ?? 0) < (rhs.vector[k] ?? 0)
        }
    }

    /// Return an updated version from a local an remote version. It is to be used anytime we receive a new version from the server.
    public func receive(other: BeamVersion) -> BeamVersion {
        var result = vector
        for v in other.vector {
            result[v.key] = max(result[v.key] ?? 0, v.value)
        }
        return BeamVersion(result).incremented()
    }

    /// Returns true if lhs and rhs are incomparable: they are in conflict.
    public func areConcurrent(lhs: BeamVersion, rhs: BeamVersion) -> Bool {
        !(lhs <= rhs) && !(rhs <= lhs)
    }

    public enum Comparison {
        case equal
        case ancestor
        case descendant
        case conflict
    }

    /// Return the result of comparing both versions to decide if they are directly related (and in which order) or in conflict.
    public func compare(with other: BeamVersion) -> Comparison {
        if self == other {
            return .equal
        } else if self <= other {
            return .ancestor
        } else if other <= self {
            return .descendant
        }
        return .conflict
    }

    /// Return true if self is the initial version, that it no participating machine as a local version other that 0.
    public var isInitial: Bool {
        vector.first { $0.value > 0 } == nil
    }

    public var description: String {
        String(vector.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
    }
}

extension BeamVersion: Hashable {
    public func hash(into hasher: inout Hasher) {
        for kv in vector {
            hasher.combine(kv.key)
            hasher.combine(kv.value)
        }
    }
}
