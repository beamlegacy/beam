import Foundation

extension BeamNote {
    public func textDescription() -> String {
        children.compactMap {
            childAsTextDescription($0)
        }.joined(separator: "\n")
    }

    private func childAsTextDescription(_ element: BeamElement, deep: Int = 0) -> String {
        let space = String(repeating: " ", count: 4 * deep)
        var result = space + element.text.text

        if !element.children.isEmpty {
            result += "\n" + element.children.compactMap {
                childAsTextDescription($0, deep: deep + 1)
            }.joined(separator: "\n")
        }

        return result
    }
}
