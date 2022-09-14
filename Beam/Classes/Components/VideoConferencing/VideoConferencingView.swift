import SwiftUI

/// Root SwiftUI view shown within the ``VideoConferencingPanel``.
/// It displays a toolbar and a web view and is configured thanks to ``VideoConferencingViewModel``.
struct VideoConferencingView: View {

    private static let webViewMinFrame: CGRect = .init(origin: .zero, size: .init(width: 324, height: 226))
    private static let webViewIdealFrame: CGRect = .init(origin: .zero, size: .init(width: 660, height: 434))

    private static let panelToolbarHeight: CGFloat = 28.0

    let webView: BeamWebView

    private let toolbarHeight: CGFloat = 36.0
    private let padding: CGFloat = 6.0
    private let cornerRadius: CGFloat = 6.0
    private let toolbarSpacing: CGFloat = 6.0
    private let itemSpacing: CGFloat = 8.0
    private let animationDuration: TimeInterval = 0.150

    @ObservedObject var viewModel: VideoConferencingViewModel

    @State private var trafficButtonHovered: (close: Bool, main: Bool, fullscreen: Bool) = (false, false, false)
    @State private var privacyButtonHovered: (mic: Bool, video: Bool, speaker: Bool) = (false, false, false)

    var body: some View {
        VStack(spacing: .zero) {
            if viewModel.isExpanded {
                toolbarView
                    .frame(height: toolbarHeight)
                    .transition(.opacity)
            }

            WebView(webView: webView)
                .cornerRadius(cornerRadius)
                .frame(
                    minWidth: Self.webViewMinFrame.width,
                    idealWidth: viewModel.isExpanded ? Self.webViewIdealFrame.width : Self.webViewMinFrame.width,
                    minHeight: Self.webViewMinFrame.height - Self.panelToolbarHeight,
                    idealHeight: viewModel.isExpanded ? Self.webViewIdealFrame.height : (Self.webViewMinFrame.height - Self.panelToolbarHeight)
                )
        }
        .animation(.easeInOut(duration: animationDuration), value: viewModel.isExpanded)
        .padding(viewModel.isExpanded ? [.leading, .trailing, .bottom] : .all, padding)
        .foregroundColor(BeamColor.combining(lightColor: .Mercury, lightAlpha: 0.8, darkColor: .Mercury, darkAlpha: 0.7).swiftUI)
        .visualEffect(material: .hudWindow)
        .edgesIgnoringSafeArea(.all)
    }

    private var toolbarView: some View {
        HStack {
            trafficLightsView

            Spacer()

            HStack(spacing: toolbarSpacing) {
                TabFaviconView(
                    favIcon: viewModel.faviconImage,
                    isLoading: viewModel.isLoading,
                    estimatedLoadingProgress: viewModel.estimatedProgress
                )
                Text(viewModel.title)
                    .lineLimit(1)
                    .foregroundColor(BeamColor.Niobium.swiftUI)
                    .blendModeLightMultiplyDarkScreen()
            }

            Spacer()

            privacyDetailsView
        }
        .padding(.horizontal, padding)
    }

}

private extension VideoConferencingView {
    private var trafficLightsView: some View {
        HStack(spacing: itemSpacing) {
            trafficLight(imageName: "tabs-side-close") {
                viewModel.close()
            }
            .onHover { trafficButtonHovered.close = $0 }
            .colorMultiply(trafficButtonHovered.close ? BeamColor.Niobium.swiftUI : BeamColor.Corduroy.swiftUI)

            trafficLight(imageName: "tabs-side-openmain") {
                do {
                    try viewModel.attach()
                } catch {
                    UserAlert.showError(error: error)
                }
            }
            .onHover { trafficButtonHovered.main = $0 }
            .colorMultiply(trafficButtonHovered.main ? BeamColor.Niobium.swiftUI : BeamColor.Corduroy.swiftUI)

            trafficLight(imageName: "tabs-side-fullscreen") {
                viewModel.toggleFullscreen()
            }
            .onHover { trafficButtonHovered.fullscreen = $0 }
            .colorMultiply(trafficButtonHovered.fullscreen ? BeamColor.Niobium.swiftUI : BeamColor.Corduroy.swiftUI)
        }
        .blendModeLightMultiplyDarkScreen()
    }

    private func trafficLight(imageName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(imageName)
        }
        .foregroundColor(.white)
        .buttonStyle(BorderlessButtonStyle())
    }
}

private extension VideoConferencingView {
    enum PrivacyItem {
        case mic(activated: Bool)
        case video(activated: Bool)
        case speaker(activated: Bool)

        var imageName: String {
            switch self {
            case .mic(let activated):
                return activated ? "tabs-mic" : "tabs-mic_off"
            case .video(let activated):
                return activated ? "tabs-video" : "tabs-video_off"
            case .speaker(let activated):
                return activated ? "tabs-media" : "tabs-media_muted"
            }
        }
    }

    private var privacyDetailsView: some View {
        HStack(spacing: itemSpacing) {
            if #available(macOS 12.0, *) {
                privacyItem(.mic(activated: viewModel.microEnabled)) {
                    Task { await viewModel.toggleMic() }
                }
                .onHover { privacyButtonHovered.mic = $0 }
                .colorMultiply(privacyButtonHovered.mic ? BeamColor.Niobium.swiftUI : BeamColor.Corduroy.swiftUI)

                privacyItem(.video(activated: viewModel.cameraEnabled)) {
                    Task { await viewModel.toggleCamera() }
                }
                .onHover { privacyButtonHovered.video = $0 }
                .colorMultiply(privacyButtonHovered.video ? BeamColor.Niobium.swiftUI : BeamColor.Corduroy.swiftUI)
            }

            privacyItem(.speaker(activated: !viewModel.isPageMuted)) {
                viewModel.toggleMuteAudio()
            }
            .onHover { privacyButtonHovered.speaker = $0 }
            .colorMultiply(privacyButtonHovered.speaker ? BeamColor.Niobium.swiftUI : BeamColor.Corduroy.swiftUI)
        }
        .blendModeLightMultiplyDarkScreen()
    }

    private func privacyItem(_ item: PrivacyItem, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(item.imageName)
        }
        .foregroundColor(.white)
        .buttonStyle(BorderlessButtonStyle())
    }
}
