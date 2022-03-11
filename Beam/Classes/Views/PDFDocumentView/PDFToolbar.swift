import SwiftUI

struct PDFToolbar: View {

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
                    icon: "download-file_download",
                    customStyle: buttonLabelStyle
                ) {
                    contentState.saveDocument()
                }
                .padding(.leading, 1)
                .tooltipOnHover("Save")
                .accessibilityIdentifier("save-pdf")
            }
        }
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

    init(contentState: PDFContentState) {
        self.contentState = contentState
    }

}
