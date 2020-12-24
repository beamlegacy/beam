import Foundation

extension Int64 {
    var byteSize: String {
        return ByteCountFormatter().string(fromByteCount: Int64(self))
    }
}
