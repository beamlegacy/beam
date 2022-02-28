import Foundation

enum ArrayDiff<T: Equatable>: Equatable {
    case Insertion(Int, T)
    case Deletion(Int)

    var position: Double {
        switch self {
        case .Deletion(let i):
            return Double(i)
        case .Insertion(let j, _):
            return Double(j) - 0.5
        }
    }
}

func ==<T: Equatable>(d: ArrayDiff<T>, e: ArrayDiff<T>) -> Bool {
    switch (d, e) {
    case (.Insertion(let p1, let r1), .Insertion(let p2, let r2)):
        return p1 == p2 && r1 == r2
    case (.Deletion(let r1), .Deletion(let r2)):
        return r1 == r2
    default:
        return false
    }
}

class Graph<T: Equatable> {
    let original: [T]
    let new: [T]

    init(original: [T], new: [T]) {
        self.original = original
        self.new = new
    }

    /**
     Returns nil if there is no edge from from to to.
     
     - (x:0, y:0) means origin
     - 0 <= x <= original.count should hold
     - 0 <= y <= new.count should hold
     */
    func cost(from: (x: Int, y: Int), to: (x: Int, y: Int)) -> UInt? {
        guard 0 <= from.x,
              to.x <= original.count,
              0 <= from.y,
              to.y <= new.count,
              to.x == from.x + 1 || to.y == from.y + 1
        else {
            return nil
        }

        if to.x == from.x + 1 && to.y == from.y + 1 {
            return original[to.x - 1] == new[to.y - 1] ? 0 : nil
        } else {
            return 1
        }
    }

    func enumeratePath(path: [ArrayDiff<T>], start: (x: Int, y: Int), candidates: inout [[ArrayDiff<T>]]) {
        guard start.x <= original.count,
              start.y <= new.count
        else {
            return
        }

        if start.x == original.count,
           start.y == new.count {
            candidates.append(path)
        } else {
            if cost(from: start, to: (x: start.x + 1, y: start.y + 1)) != nil {
                enumeratePath(path: path, start: (x: start.x + 1, y: start.y + 1), candidates: &candidates)
                return
            }
            if cost(from: start, to: (x: start.x + 1, y: start.y)) != nil {
                enumeratePath(path: path + [.Deletion(start.x)], start: (x: start.x + 1, y: start.y), candidates: &candidates)
            }
            if cost(from: start, to: (x: start.x, y: start.y + 1)) != nil {
                enumeratePath(path: path + [.Insertion(start.x, new[start.y])], start: (x: start.x, y: start.y + 1), candidates: &candidates)
            }
        }
    }
}

class Diff {
    func diff<T: Equatable>(original: [T], new: [T]) -> [ArrayDiff<T>] {
        var paths: [[ArrayDiff<T>]] = []

        let graph = Graph<T>(original: original, new: new)
        graph.enumeratePath(path: [], start: (x: 0, y: 0), candidates: &paths)

        return paths.min { $0.count < $1.count }!
    }
}

extension ThreeWayMerge {
    static func apply<T: Equatable>(base: [T], diff: ArrayDiff<T>) -> [T] {
        var array = base

        switch diff {
        case .Deletion(let i):
            array.remove(at: i)
        case .Insertion(let i, let x):
            array.insert(x, at: i)
        }

        return array
    }

    static public func merge<T: Equatable>(base: [T], mine: [T], theirs: [T]) -> MergeResult<[T]> {
        let diff = Diff()
        var result: [T] = base

        var _myDiff: [ArrayDiff<T>] = diff.diff(original: base, new: mine)
        var _theirDiff: [ArrayDiff<T>] = diff.diff(original: base, new: theirs)

        // Remove the common prefix of changes
        var preparation = [ArrayDiff<T>]()
        while let d = _myDiff.first, let e = _theirDiff.first, d == e {
            preparation.insert(d, at: 0)
            _myDiff.removeFirst()
            _theirDiff.removeFirst()
        }

        var myDiff: [ArrayDiff<T>] = _myDiff.reversed()
        var theirDiff: [ArrayDiff<T>] = _theirDiff.reversed()

        repeat {
            switch (myDiff.first, theirDiff.first) {
            case (.some(let d), .some(let e)) where d.position < e.position:
                result = apply(base: result, diff: e)
                theirDiff.removeFirst()
            case (.some(let d), .some(let e)) where d.position > e.position:
                result = apply(base: result, diff: d)
                myDiff.removeFirst()
            case (.some(let d), .some(let e)) where d == e:
                result = apply(base: result, diff: d)
                myDiff.removeFirst()
                theirDiff.removeFirst()
            case (.some(let d), .none):
                result = apply(base: result, diff: d)
                myDiff.removeFirst()
            case (.none, .some(let d)):
                result = apply(base: result, diff: d)
                theirDiff.removeFirst()
            default:
                return .Conflicted
            }
        } while myDiff.count > 0 || theirDiff.count > 0

        for d in preparation {
            result = apply(base: result, diff: d)
        }
        return .Merged(result)
    }
}
