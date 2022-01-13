/// A protocol describing an object that can be decoded from the body of a message received from JavaScript code.
protocol ScriptMessageBodyDecodable {

  init(from scriptMessageBody: Any) throws

}

enum ScriptMessageBodyDecodingError: Error {
    case unexpectedFormat
}
