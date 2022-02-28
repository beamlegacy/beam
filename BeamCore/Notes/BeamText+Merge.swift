public enum MergeConflictStrategy {
    case conflict
    case chooseMine
    case chooseTheirs
}

public extension BeamText {
    func splitForMerge() -> [BeamText] {
        var elements = [BeamText]()
        var lastIndex = 0
        let ranges = tokenize(.word, options: .none)

        for range in ranges {
            while lastIndex < range.lowerBound {
                // First add all the unknown chars individually
                elements.append(extract(range: lastIndex..<lastIndex + 1))
                lastIndex += 1
            }
            elements.append(extract(range: range))
            lastIndex = range.upperBound
        }

        // Finish
        while lastIndex < count {
            // First add all the unknown chars individually
            elements.append(extract(range: lastIndex..<lastIndex + 1))
            lastIndex += 1
        }

        return elements
    }

    func merge(ancestor: BeamText, other: BeamText, strategy: MergeConflictStrategy = .conflict) -> BeamText? {
        guard self != other else { return self }
        switch ThreeWayMerge.merge(base: ancestor.splitForMerge(), mine: self.splitForMerge(), theirs: other.splitForMerge()) {
        case .Conflicted:
            switch strategy {
            case .conflict:
                return nil
            case .chooseMine:
                return self
            case .chooseTheirs:
                return other
            }
        case .Merged(let result):
            return result.reduce(BeamText()) { partialResult, element in
                var s = partialResult
                s.append(element)
                return s
            }
        }
    }
}
