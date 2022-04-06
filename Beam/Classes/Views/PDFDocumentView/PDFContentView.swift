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
                onClickLink: onClickLink,
                onSelectionChanged: { selection in
                    contentState.setCurrentSelection(selection)
                },
                findString: searchState.searchTerms,
                findMatchIndex: $searchState.currentOccurence,
                onFindMatches: { selections in
                    searchState.foundOccurences = selections.count
                }
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
    @ObservedObject private var searchState: SearchViewModel

    private let onClickLink: ((URL) -> Void)?
    private let loadingAnimationSize: CGFloat = 64

    init(
        contentState: PDFContentState,
        searchState: SearchViewModel?,
        onClickLink: ((URL) -> Void)? = nil
    ) {
        self.contentState = contentState
        self.searchState = searchState ?? SearchViewModel(context: .web)
        self.onClickLink = onClickLink
    }

}
