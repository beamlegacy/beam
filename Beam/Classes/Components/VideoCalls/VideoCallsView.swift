import SwiftUI

/// Root SwiftUI view shown within the ``VideoCallsPanel``.
/// It displays a toolbar and a web view and is configured thanks to ``VideoCallsViewModel``.
struct VideoCallsView: View {

    static let shadowPadding: CGFloat = 50

    private static let panelToolbarHeight: CGFloat = 28.0

    let webView: BeamWebView

    private let toolbarHeight: CGFloat = 36.0
    private let padding: CGFloat = 6.0
    private let cornerRadius: CGFloat = 6.0
    private let toolbarSpacing: CGFloat = 6.0
    private let itemSpacing: CGFloat = 8.0
    private let animationDuration: TimeInterval = 0.150

    @ObservedObject var viewModel: VideoCallsViewModel
    @State private var transitionSnapshot: NSImage?
    @State private var showSnapshot = false
    @State private var isHovering = false

    @State private var trafficButtonHovered: (close: Bool, main: Bool, fullscreen: Bool) = (false, false, false)
    @State private var privacyButtonHovered: (mic: Bool, video: Bool, speaker: Bool) = (false, false, false)

    private let backgroundColor = BeamColor.combining(lightColor: .Mercury, lightAlpha: 0.8, darkColor: .Mercury, darkAlpha: 0.7)
    private let inactiveBackgroundColor = BeamColor.Mercury.alpha(0.1)

    private var showToolbar: Bool {
        viewModel.isExpanded || viewModel.isFullscreen || isHovering
    }
    private let strokeColor = BeamColor.combining(lightColor: .From(color: .black, alpha: 0.1), darkColor: .From(color: .white, alpha: 0.3))
    private let webViewStrokeColor = BeamColor.combining(lightColor: .AlphaGray, lightAlpha: 0.5, darkColor: .Mercury, darkAlpha: 0.5)

    private var shadowColor: Color {
        guard !viewModel.isExpanded else { return .clear }
        return .black.opacity(showToolbar ? 0.3 : 0.15)
    }
    private var shadowRadius: CGFloat {
        showToolbar ? 17 : 12
    }
    private var shadowY: CGFloat {
        showToolbar ? 10 : 5
    }

    var body: some View {
        VStack(spacing: .zero) {
            if !showToolbar {
                Rectangle()
                    .fill(.clear)
                    .frame(height: toolbarHeight - padding)
            }

            VStack(spacing: .zero) {
                if showToolbar {
                    toolbarView
                        .frame(height: toolbarHeight)
                        .transition(.opacity)
                }
                ZStack {
                    let image = transitionSnapshot
                    if image == nil || !showSnapshot {
                        WebView(webView: webView, topContentInset: .zero)
                            .transition(.identity)
                    }
                    if let image = image {
                        Image(nsImage: image)
                            .resizable()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .opacity(showSnapshot ? 1 : 0)
                    }

                }
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius + 0.5)
                        .stroke(webViewStrokeColor.swiftUI, lineWidth: 0.5)
                )
            }
            .padding(showToolbar ? [.leading, .trailing, .bottom] : .all, padding)
            .background((showToolbar ? backgroundColor : inactiveBackgroundColor).swiftUI)
            .background(
                VisualEffectView(material: .hudWindow, state: .active)
            )
            .cornerRadius(viewModel.isExpanded ? 0 : cornerRadius + padding)
            .overlay(
                RoundedRectangle(cornerRadius: viewModel.isExpanded ? cornerRadius : cornerRadius + padding + 0.5)
                    .stroke(strokeColor.swiftUI, lineWidth: 0.5)
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
        }
        .padding(viewModel.isExpanded || viewModel.isFullscreen ? 0 : Self.shadowPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
        .onChange(of: viewModel.isHovered) { isHovered in
            /// storing local isHovering state to manually animate
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = isHovered
            }
        }
        .onReceive(viewModel.$transitionSnapshot) { newSnapshot in
            if newSnapshot == nil {
                // Manually handling the transition from snapshot to webView
                let duration: TimeInterval = 0.15
                withAnimation(.easeIn(duration: duration)) {
                    showSnapshot = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    self.transitionSnapshot = nil
                }
            } else {
                transitionSnapshot = newSnapshot
                showSnapshot = true
            }
        }
    }

    private var toolbarView: some View {
        HStack {
            trafficLightsView

            if !viewModel.isShrinked {
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
                        .transition(.opacity)
                }
            }

            Spacer()

            privacyDetailsView
        }
        .animation(.easeInOut(duration: animationDuration), value: !viewModel.isShrinked)
        .padding(.horizontal, padding)
    }

}

private extension VideoCallsView {
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

private extension VideoCallsView {
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
