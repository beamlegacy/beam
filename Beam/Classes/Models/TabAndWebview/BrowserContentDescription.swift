import Combine

/// A protocol describing an object publishing updates about the content currently displayed in the browser.
protocol BrowserContentDescription {

    var type: BrowserContentType { get }
    var titlePublisher: AnyPublisher<String?, Never> { get }
    var isLoadingPublisher: AnyPublisher<Bool, Never> { get }
    var estimatedProgressPublisher: AnyPublisher<Double, Never> { get }

}

enum BrowserContentType {
    case web
    case pdf
}
