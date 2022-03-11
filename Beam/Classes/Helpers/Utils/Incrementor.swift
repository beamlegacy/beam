import Foundation

/// Increases or decreases a value based on a list of increments.
struct Incrementor<T> where T: Comparable {

    var value: T

    var isSmallestIncrement: Bool {
        guard let firstIncrement = increments.first else { return true }
        return value <= firstIncrement
    }

    var isHighestIncrement: Bool {
        guard let lastIncrement = increments.last else { return true }
        return value >= lastIncrement
    }

    private let defaultValue: T

    private let increments: [T]

    init(defaultValue: T, increments: [T]) {
        self.value = defaultValue
        self.defaultValue = defaultValue
        self.increments = increments
    }

    mutating func increase() {
        let index = increments.firstIndex { $0 > value }
        guard let index = index else { return }

        value = increments[index]
    }

    mutating func decrease() {
        let reversedIncrements = Array(increments.reversed())
        let index = reversedIncrements.firstIndex { $0 < value }
        guard let index = index else { return }

        value = reversedIncrements[index]
    }

    mutating func reset() {
        value = defaultValue
    }

}
