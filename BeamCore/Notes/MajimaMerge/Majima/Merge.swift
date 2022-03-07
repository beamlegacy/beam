import Foundation

public enum MergeResult<T> {
    case Merged(T)
    case Conflicted
}

public class ThreeWayMerge {
    public static func merge<T: Equatable>(base: T, mine: T, theirs: T) -> MergeResult<T> {
        if theirs == mine {
            return .Merged(theirs)
        }

        if base == mine {
            return .Merged(theirs)
        }

        if base == theirs {
            return .Merged(mine)
        }

        return .Conflicted
    }

    public static func merge<T: Equatable>(base: T?, mine: T?, theirs: T?) -> MergeResult<T?> {
        if theirs == mine {
            return .Merged(theirs)
        }

        if base == mine {
            return .Merged(theirs)
        }

        if base == theirs {
            return .Merged(mine)
        }
        return .Conflicted
    }
}
