import Foundation

extension BeamElement {
    class func threeWayMerge(ancestor: Data, input1: Data, input2: Data) -> Data? {
        let data = Merge.threeWayMergeData(ancestor: ancestor,
                                           input1: input1,
                                           input2: input2)

        return data
    }
}
