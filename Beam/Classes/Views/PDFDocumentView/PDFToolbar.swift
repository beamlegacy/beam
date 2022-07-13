import SwiftUI

struct PDFToolbar: View {

    @State private var didDownloadFileLottiePlaying = false

    var body: some View {
        FloatingToolbar(spacing: 0, contentLeadingPadding: 10) {
            Group {
                ButtonLabel(
                    icon: "download-file_zoomout",
                    state: contentState.canZoomOut ? .normal : .disabled,
                    customStyle: zoomButtonLabelStyle
                ) {
                    contentState.zoomOut()
                }
                .tooltipOnHover("Zoom Out")
                .accessibilityIdentifier("zoom-out")

                ButtonLabel(
                    contentState.zoomLevel,
                    customStyle: zoomLevelButtonLabelStyle
                ) {
                    contentState.scaleToActualSize()
                }
                .frame(minWidth: 46)
                .tooltipOnHover("Zoom Level")
                .accessibilityIdentifier("zoom-level")

                ButtonLabel(
                    icon: "download-file_zoomin",
                    state: contentState.canZoomIn ? .normal : .disabled,
                    customStyle: zoomButtonLabelStyle
                ) {
                    contentState.zoomIn()
                }
                .tooltipOnHover("Zoom In")
                .accessibilityIdentifier("zoom-in")

                Separator(color: separatorColor)
                    .blendMode(colorScheme == .light ? .multiply : .screen)
                    .padding(.horizontal, 6)

                ButtonLabel(
                    icon: "download-file_print",
                    state: .normal,
                    customStyle: buttonLabelStyle
                ) {
                    contentState.printDocument()
                }
                .padding(.trailing, 1)
                .tooltipOnHover("Print")
                .accessibilityIdentifier("print-pdf")

                ButtonLabel(
                    lottie: "download-file",
                    lottiePlaying: didDownloadFileLottiePlaying,
                    lottieLoopMode: .playOnce,
                    lottieCompletion: { didDownloadFileLottiePlaying = false },
                    customStyle: buttonLabelStyle,
                    action: downloadFile)
                // Force a new view when the playing state changes, this is needed
                // because of animation glitches from the underlying lottie view.
                .id(didDownloadFileLottiePlaying)
                .padding(.leading, 1)
                .tooltipOnHover("Save")
                // We are using an overlay to workaround an issue where .accessibilityElement()
                // is seemingly broken when a child view is an NSViewRepresentable (the lottie
                // view in this case).
                .overlay(
                    Rectangle()
                        .opacity(0)
                        .accessibilityElement()
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("Download file")
                        .accessibilityAction { downloadFile() }
                        .accessibilityIdentifier("save-pdf")
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pdf-toolbar")
    }

    @ObservedObject private var contentState: PDFContentState

    @Environment(\.colorScheme) private var colorScheme

    private let buttonLabelStyle: ButtonLabelStyle = {
        var style = ButtonLabelStyle.floatingToolbarButtonLabelStyle()
        style.iconSize = 16
        return style
    }()

    private let zoomButtonLabelStyle: ButtonLabelStyle = {
        var style = ButtonLabelStyle.floatingToolbarButtonLabelStyle()
        style.iconSize = 10
        style.horizontalPadding = 6
        style.verticalPadding = 6
        return style
    }()

    private let zoomLevelButtonLabelStyle: ButtonLabelStyle = {
        var style = ButtonLabelStyle.floatingToolbarButtonLabelStyle()
        style.font = BeamFont.regular(size: 10).swiftUI
        style.horizontalPadding = 3
        style.verticalPadding = 6
        return style
    }()

    private let separatorColor = BeamColor.combining(
        lightColor: BeamColor.Mercury,
        darkColor: BeamColor.Mercury,
        darkAlpha: 0.5
    )

    private func downloadFile() {
        if contentState.saveDocument() {
            didDownloadFileLottiePlaying = true
        }
    }

    init(contentState: PDFContentState) {
        self.contentState = contentState
    }

}
