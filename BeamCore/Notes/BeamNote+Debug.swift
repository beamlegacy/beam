import Foundation

extension BeamNote {
    public func textDescription() -> String {
        children.map {
            childAsTextDescription($0)
        }.joined(separator: "\n")
    }

    private func childAsTextDescription(_ element: BeamElement, deep: Int = 0) -> String {
        let space = String(repeating: " ", count: 4 * deep)
        return space + element.text.text + "\n" +
            element.children.map {
                childAsTextDescription($0, deep: deep + 1)
            }.joined(separator: "\n")
    }
}
