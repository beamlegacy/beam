import Combine
import WebKit

final class WebContentDescription: BrowserContentDescription {

    let type: BrowserContentType = .web
    let titlePublisher: AnyPublisher<String?, Never>
    let isLoadingPublisher: AnyPublisher<Bool, Never>
    let estimatedProgressPublisher: AnyPublisher<Double, Never>

    private weak var webView: WKWebView?

    init(webView: WKWebView) {
        self.webView = webView

        titlePublisher = webView.publisher(for: \.title)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()

        isLoadingPublisher = webView.publisher(for: \.isLoading).eraseToAnyPublisher()
        estimatedProgressPublisher = webView.publisher(for: \.estimatedProgress).eraseToAnyPublisher()
    }

}
