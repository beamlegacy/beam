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

    static let panelSize = CGSize(width: 638, height: 406)

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .top) {
                BeamColor.Mercury.swiftUI
                    .frame(height: Self.panelSize.height)
                VStack(spacing: 22) {
                    AppIcon()
                        .frame(width: 66, height: 66)
                    texts
                    buttons
                        .padding(.top, 28)
                }
                .padding(.top, 82)
            }
            .frame(width: 248, height: Self.panelSize.height - windowBarHeight)
            if let releaseNoteURL = appRelease.releaseNoteURL {
                ReleaseNoteWebView(url: releaseNoteURL, viewModel: webViewModel)
                    .frame(width: 390)
                    .overlay(loadingOverlay, alignment: .center)
            }
        }
    }

    @ViewBuilder private var loadingOverlay: some View {
        if webViewModel.isLoading {
            ProgressView()
        } else {
            EmptyView()
        }
    }

    private var texts: some View {
        VStack(spacing: 6) {
            Text("\(appRelease.versionName) \(appRelease.version)")
                .font(BeamFont.semibold(size: 20).swiftUI)
                .foregroundColor(BeamColor.Niobium.swiftUI)
            Text("\(appRelease.versionName) \(appRelease.version) is available.\nTime to update!")
                .multilineTextAlignment(.center)
                .font(BeamFont.regular(size: 12).swiftUI)
                .foregroundColor(BeamColor.Corduroy.swiftUI)
        }
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            ActionableButton(text: loc("Update now"), defaultState: .normal, variant: updateVariant, minWidth: 180) {
                Task {
                    await versionChecker.performUpdateIfAvailable(forceInstall: true)
                }
                closeAction()
            }
            Button {
                closeAction()
            } label: {
                Text(loc("Later"))
                    .font(BeamFont.medium(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Corduroy.swiftUI)
                    .frame(width: 180, height: 34, alignment: .center)
            }.buttonStyle(.borderless)
        }
    }

    private var updateVariant: ActionableButtonVariant {
        var updateVariant = ActionableButtonVariant.primaryPurple.style
        updateVariant.icon = nil
        updateVariant.textAlignment = .center
        return .custom(updateVariant)
    }

    static func showReleaseNoteWindow(with release: AppRelease, versionChecker: VersionChecker, hideButtonOnClose: Bool = false) {
        let window = SimpleHostingWindow(rect: .zero, styleMask: [.titled, .closable, .miniaturizable, .unifiedTitleAndToolbar, .fullSizeContentView])
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

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
        UpdatePanel(appRelease: AppRelease.mockedReleases()[3], versionChecker: VersionChecker(mockedReleases: AppRelease.mockedReleases()), closeAction: {})
    }
}
