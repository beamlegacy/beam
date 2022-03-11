import Foundation
import SwiftUI
import PDFKit

struct PDFContentView: View {

    var body: some View {
        if let pdfDocument = contentState.pdfDocument {
            PDFDocumentView(
                pdfDocument: pdfDocument,
                displayMode: $contentState.displayMode,
                autoScales: $contentState.autoScales,
                scaleFactor: $contentState.scaleFactor,
                minScaleFactor: contentState.minScaleFactor,
                maxScaleFactor: contentState.maxScaleFactor,
                destination: $contentState.destination,
                onClickLink: onClickLink
            )

        } else {
            LottieView(
                name: "status-update_restart",
                playing: true,
                color: BeamColor.LightStoneGray.nsColor,
                animationSize: CGSize(width: loadingAnimationSize, height: loadingAnimationSize)
            )
        }
    }

    @ObservedObject private var contentState: PDFContentState

    private let onClickLink: ((URL) -> Void)?
    private let loadingAnimationSize: CGFloat = 64

    init(contentState: PDFContentState, onClickLink: ((URL) -> Void)?) {
        self.contentState = contentState
        self.onClickLink = onClickLink
    }

}
