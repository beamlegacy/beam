import Foundation
import CryptoKit

// https://stackoverflow.com/questions/56828125/how-do-i-access-the-underlying-key-of-a-symmetrickey-in-cryptokit
extension SymmetricKey {
    // MARK: Custom Initializers

    /// Creates a `SymmetricKey` from a Base64-encoded `String`.
    ///
    /// - Parameter base64EncodedString: The Base64-encoded string from which to generate the `SymmetricKey`.
    init?(base64EncodedString: String) {
        guard let data = Data(base64Encoded: base64EncodedString) else {
            return nil
        }

        self.init(data: data)
    }
    // MARK: - Instance Methods

    /// Serializes a `SymmetricKey` to a Base64-encoded `String`.
    func asString() -> String {
        asData().base64EncodedString()
    }

    func asData() -> Data {
        self.withUnsafeBytes { Data($0) }
    }
}
