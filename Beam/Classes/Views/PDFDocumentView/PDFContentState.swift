import Foundation
import PDFKit
import Combine

final class PDFContentState: ObservableObject {

    @Published var pdfDocument: PDFDocument?
    @Published var displayMode: PDFDisplayMode = .singlePageContinuous
    @Published var autoScales = false
    @Published var destination: PDFDocumentViewDestination = .top

    var scaleFactor: CGFloat {
        get {
            scaleFactorIncrementor.value
        }
        set {
            guard scaleFactorIncrementor.value != newValue else { return }

            scaleFactorIncrementor.value = newValue
            objectWillChange.send()
        }
    }

    var canZoomIn: Bool {
        !scaleFactorIncrementor.isHighestIncrement
    }

    var canZoomOut: Bool {
        !scaleFactorIncrementor.isSmallestIncrement
    }

    var zoomLevel: String {
        "\(Int(scaleFactor * 100))%"
    }

    var minScaleFactor: CGFloat {
        scaleFactorIncrements.first ?? 1
    }

    var maxScaleFactor: CGFloat {
        scaleFactorIncrements.last ?? 1
    }

    var isLoaded: Bool {
        pdfDocument != nil
    }

    private(set) var currentSelection: String?

    private let filename: String

    private var scaleFactorIncrementor: Incrementor<CGFloat>

    private var scaleFactorIncrements: [CGFloat] = [
        0.1, 0.15, 0.2, 0.3, 0.4, 0.5, 0.75, 0.81, 1, 1.5, 2, 3, 4, 6, 8, 10, 15, 20, 30
    ]

    init(filename: String) {
        self.filename = filename
        scaleFactorIncrementor = Incrementor<CGFloat>(defaultValue: 1, increments: scaleFactorIncrements)
    }

    func zoomIn() {
        autoScales = false
        scaleFactorIncrementor.increase()
    }

    func zoomOut() {
        autoScales = false
        scaleFactorIncrementor.decrease()
    }

    func scaleToActualSize() {
        autoScales = false
        scaleFactorIncrementor.reset()
    }

    func printDocument() {
        let printOperation = pdfDocument?.printOperation(for: .shared, scalingMode: .pageScaleDownToFit, autoRotate: false)
        printOperation?.run()
    }

    func saveDocument() {
        guard let tentativeSaveLocationURL = destinationDirectoryURL()?.appendingPathComponent(filename) else {
            return
        }

        var saveLocationURL = tentativeSaveLocationURL.availableFileURL()

        if saveLocationURL.pathExtension.isEmpty {
            saveLocationURL.appendPathExtension("pdf")
        }

        pdfDocument?.write(to: saveLocationURL)
    }

    func setCurrentSelection(_ selection: String?) {
        currentSelection = selection
    }

    private func destinationDirectoryURL() -> URL? {
        if let preferredDownloadDirectory = DownloadFolder(rawValue: PreferencesManager.selectedDownloadFolder)?.sandboxAccessibleUrl {
            return preferredDownloadDirectory
        }

        if let systemDownloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            return systemDownloadsDirectory
        }

        return nil
    }

}
