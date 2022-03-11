import Foundation
import PDFKit
import SwiftUI
import Combine

struct PDFDocumentView {

    let pdfDocument: PDFDocument
    var displayMode: Binding<PDFDisplayMode>?
    var autoScales: Binding<Bool>?
    var scaleFactor: Binding<CGFloat>?
    let minScaleFactor: CGFloat
    let maxScaleFactor: CGFloat
    var destination: Binding<PDFDocumentViewDestination>?
    var onClickLink: ((URL) -> Void)?

    init(
        pdfDocument: PDFDocument,
        displayMode: Binding<PDFDisplayMode>? = nil,
        autoScales: Binding<Bool>? = nil,
        scaleFactor: Binding<CGFloat>? = nil,
        minScaleFactor: CGFloat = 0.5,
        maxScaleFactor: CGFloat = 3,
        destination: Binding<PDFDocumentViewDestination>? = nil,
        onClickLink: ((URL) -> Void)? = nil
    ) {
        self.pdfDocument = pdfDocument
        self.displayMode = displayMode
        self.autoScales = autoScales
        self.scaleFactor = scaleFactor
        self.minScaleFactor = minScaleFactor
        self.maxScaleFactor = maxScaleFactor
        self.destination = destination
        self.onClickLink = onClickLink
    }

}

// MARK: - PDFDocumentViewDestination

enum PDFDocumentViewDestination {

    case top
    case custom(PDFDestination)

}

// MARK: - NSViewRepresentable

extension PDFDocumentView: NSViewRepresentable {

    func makeCoordinator() -> PDFDocumentViewCoordinator {
        PDFDocumentViewCoordinator()
    }

    func makeNSView(context: Context) -> CustomPDFView {
        let pdfView = CustomPDFView()
        context.coordinator.setNSView(pdfView)
        return pdfView
    }

    func updateNSView(_ pdfView: CustomPDFView, context: Context) {
        context.coordinator.setSwiftUIView(self)
    }

}
