import Foundation
import Combine
import PDFKit
import BeamCore

final class PDFContentDescription: BrowserContentDescription {

    let url: URL
    let type: BrowserContentType = .pdf
    let titlePublisher: AnyPublisher<String?, Never>
    let isLoadingPublisher: AnyPublisher<Bool, Never>
    let estimatedProgressPublisher: AnyPublisher<Double, Never>
    let contentState: PDFContentState

    private(set) var pdfDocument: PDFDocument?

    private var cancellables = Set<AnyCancellable>()
    private let urlSession = URLSession.shared

    init(url: URL) {
        self.url = url

        titlePublisher = Just(url.lastPathComponent).eraseToAnyPublisher()
        contentState = PDFContentState(filename: url.lastPathComponent)

        let task = urlSession.dataTask(with: url) { [weak contentState] data, _, error in
            guard error == nil else {
                Logger.shared.logError("Could not download PDF document: \(error!)", category: .network)
                return
            }

            DispatchQueue.main.async { [weak contentState] in
                contentState?.pdfDocument = PDFDocument(data: data!)
            }
        }

        isLoadingPublisher = task.progress
            .publisher(for: \.isFinished)
            .map { !$0 }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()

        estimatedProgressPublisher = task.progress
            .publisher(for: \.fractionCompleted)
            .throttle(for: 0.5, scheduler: RunLoop.main, latest: true)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()

        task.resume()
    }

}
