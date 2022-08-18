//
//  UpdatePanel.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 15/04/2022.
//

import SwiftUI
import BeamCore
import AutoUpdate

struct UpdatePanel: View {

    let appRelease: AppRelease
    @ObservedObject var versionChecker: VersionChecker
    var closeAction: (() -> Void)

    private let windowBarHeight = 28.0
    @StateObject private var webViewModel = WebViewModel()

    static let panelSize = CGSize(width: 684, height: 400)

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .top) {
                VStack(spacing: 6) {
                    AppIcon()
                        .frame(width: 66, height: 66)
                    texts
                    buttons
                        .padding(.top, 53)
                }
                .padding(.top, 18)
            }
            .frame(width: 238, height: Self.panelSize.height - windowBarHeight)
            if let releaseNoteURL = appRelease.releaseNoteURL {
                VStack {
                    ReleaseNoteWebView(url: releaseNoteURL, viewModel: webViewModel)
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                        .if(webViewModel.isLoading, transform: {
                            $0.hidden()
                        })
                }.frame(width: 440)
                    .background(BeamColor.Generic.background.swiftUI)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(BeamColor.combining(lightColor: .From(color: .black), lightAlpha: 0.5, darkColor: .From(color: .black), darkAlpha: 0.85).swiftUI, lineWidth: 0.5)
                    )
                    .overlay(loadingOverlay, alignment: .center)
                    .cornerRadius(10)
                    .padding(3)

            }
        }.foregroundColor(BeamColor.combining(lightColor: .Mercury, lightAlpha: 0.8, darkColor: .Mercury, darkAlpha: 0.7).swiftUI)
            .visualEffect(material: .hudWindow)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(BeamColor.combining(lightColor: .From(color: .black), lightAlpha: 0.1, darkColor: .From(color: .white), darkAlpha: 0.3).swiftUI, lineWidth: 0.5)
            )
    }

    @ViewBuilder private var loadingOverlay: some View {
        if webViewModel.isLoading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: BeamColor.LightStoneGray.swiftUI))
                .scaleEffect(0.5, anchor: .center)
        } else {
            EmptyView()
        }
    }

    private var texts: some View {
        VStack(spacing: 6) {
            Text("beam")
                .foregroundColor(BeamColor.Niobium.swiftUI)
                .font(BeamFont.regular(size: 20).swiftUI)
                .blendModeLightMultiplyDarkScreen()
            Text("\(appRelease.versionName) \(appRelease.version) is available.")
                .multilineTextAlignment(.center)
                .font(BeamFont.regular(size: 12).swiftUI)
                .foregroundColor(BeamColor.Corduroy.swiftUI)
                .blendModeLightMultiplyDarkScreen()
        }
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            ActionableButton(text: loc("Update now"), defaultState: .normal, variant: updateVariant, minWidth: 180, height: 34, invertBlendMode: true) {
                Task {
                    await versionChecker.performUpdateIfAvailable(forceInstall: true)
                }
                closeAction()
            }
            ActionableButton(text: loc("Later"), defaultState: .normal, variant: laterUpdateVariant, minWidth: 180, height: 34, invertBlendMode: false) {
                closeAction()
            }
        }
    }

    private var updateVariant: ActionableButtonVariant {
        var updateVariant = ActionableButtonVariant.primaryBeam.style
        updateVariant.icon = nil
        updateVariant.textAlignment = .center
        return .custom(updateVariant)
    }

    private var laterUpdateVariant: ActionableButtonVariant {
        var updateVariant = ActionableButtonVariant.ghost.style
        updateVariant.icon = nil
        updateVariant.textAlignment = .center
        return .custom(updateVariant)
    }

    static func showReleaseNoteWindow(with release: AppRelease, versionChecker: VersionChecker, hideButtonOnClose: Bool = false) {
        let window = SimpleClearHostingWindow(rect: .zero, styleMask: [.titled, .closable, .miniaturizable, .unifiedTitleAndToolbar, .fullSizeContentView])

        let releaseNoteView = UpdatePanel(appRelease: release, versionChecker: versionChecker, closeAction: {
            window.close()
        }).edgesIgnoringSafeArea(.all)

        window.setView(content: releaseNoteView)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}

private class WebViewModel: ObservableObject {
    @Published var isLoading: Bool = true
}

private struct ReleaseNoteWebView: View, NSViewRepresentable {

    var url: URL
    @ObservedObject var viewModel: WebViewModel

    init(url: URL, viewModel: WebViewModel) {
        self.viewModel = viewModel
        self.url = url
    }

    typealias NSViewType = NSViewContainerView<WKWebView>

    func makeNSView(context: Context) -> WebView.NSViewType {

        let content = NSViewType()
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))

        let style = "body { padding-top: 0 } .main-header { display: none } header .date { display: none; }".data(using: .utf8)!.base64EncodedString()
        let cssStyle = """
                    javascript:(function() {
                    var parent = document.getElementsByTagName('head').item(0);
                    var style = document.createElement('style');
                    style.type = 'text/css';
                    style.innerHTML = window.atob('\(style)');
                    parent.appendChild(style)})()
                """

        webView.configuration.userContentController.addUserScript(WKUserScript(source: cssStyle, injectionTime: .atDocumentEnd, forMainFrameOnly: false))

        content.contentView = webView
        return content
    }

    func updateNSView(_ view: WebView.NSViewType, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self.viewModel)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
         private var viewModel: WebViewModel

         init(_ viewModel: WebViewModel) {
             self.viewModel = viewModel
         }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            viewModel.isLoading = false
        }
     }
}

struct UpdatePanel_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            UpdatePanel(appRelease: AppRelease.mockedReleases()[3], versionChecker: VersionChecker(mockedReleases: AppRelease.mockedReleases()), closeAction: {})
            UpdatePanel(appRelease: AppRelease.mockedReleases()[3], versionChecker: VersionChecker(mockedReleases: AppRelease.mockedReleases()), closeAction: {})
                .preferredColorScheme(.light)
        }
    }
}
