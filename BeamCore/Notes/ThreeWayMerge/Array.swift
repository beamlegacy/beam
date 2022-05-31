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

class Diff {
    func diff<T: Equatable>(original: [T], new: [T]) -> [ArrayDiff<T>] {
        let diff = new.difference(from: original)
        let bestPath: [ArrayDiff<T>] = diff.map { change in
            switch change {
            case .remove(offset: let offset, element: _, associatedWith: _):
                return .Deletion(offset)
            case .insert(offset: let offset, element: let element, associatedWith: _):
                return .Insertion(offset, element)
            }
        }
        return bestPath.reversed()
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

        if myDiff.count > 0 || theirDiff.count > 0 {
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
        }

        for d in preparation {
            result = apply(base: result, diff: d)
        }
        return .Merged(result)
    }
}
