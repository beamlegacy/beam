import Foundation

extension ThreeWayMerge {
    public static func merge<K, V: Equatable>(base: [K: V], mine: [K: V], theirs: [K: V]) -> MergeResult<[K: V]> {
        var all_keys: Set<K> = Set()
        all_keys = all_keys.union(base.keys)
        all_keys = all_keys.union(mine.keys)
        all_keys = all_keys.union(theirs.keys)

        var object: [K: V] = [:]

        for key in all_keys {
            let b = base[key]
            let m = mine[key]
            let t = theirs[key]

            switch self.merge(base: b, mine: m, theirs: t) {
            case .Merged(let x):
                object[key] = x
            case .Conflicted:
                return .Conflicted
            }
        }

        return .Merged(object)
    }
}
