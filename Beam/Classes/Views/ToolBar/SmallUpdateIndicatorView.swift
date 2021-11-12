//
//  SmallUpdateIndicatorView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 12/05/2021.
//

import SwiftUI
import AutoUpdate
import Parma
import Combine

struct SmallUpdateIndicatorView: View {

    @ObservedObject var versionChecker: VersionChecker

    @State private var showReleaseNotes = false
    @State private var opacity = 1.0
    @State private var opacityTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    @State private var updateInstalledTimerCancellable: Cancellable?
    @State private var timerExpired = false

    var body: some View {
        Group {
            switch versionChecker.state {
            case .updateAvailable(let release):
                GeometryReader { proxy in
                    ButtonLabel("Update available", icon: "status-publish", customStyle: buttonLabelStyle) {
                        showReleaseNoteWindow(with: release, at: proxy.frame(in: .global).origin)
                    }.onAppear {
                        opacity = 1
                    }
                }.frame(maxWidth: 250)
            case .noUpdate where versionChecker.currentRelease != nil :
                GeometryReader { proxy in
                    ButtonLabel("Updated", icon: "tool-keep", customStyle: buttonLabelStyle) {
                        showReleaseNoteWindow(with: versionChecker.currentRelease!, at: proxy.frame(in: .global).origin, hideButtonOnClose: true)
                    }
                    .onReceive(opacityTimer, perform: { _ in
                        withAnimation {
                            opacity = 0
                        }
                        opacityTimer.upstream.connect().cancel()
                    })
                }.frame(maxWidth: 250)
            case .noUpdate where versionChecker.lastCheck == nil :
                EmptyView()
            case .checking:
                EmptyView()
            case .error(errorDesc: let errorDesc):
                ButtonLabel("Update error : \(errorDesc)", customStyle: buttonLabelStyle)
                    .onReceive(opacityTimer, perform: { _ in
                        withAnimation {
                            opacity = 0
                        }
                        opacityTimer.upstream.connect().cancel()
                    })
            case .downloading(progress: _):
                EmptyView()
            case .downloaded(let downloadedRelease):
                GeometryReader { proxy in
                    ButtonLabel("Update now", icon: "status-publish", customStyle: buttonLabelStyle) {
                        showReleaseNoteWindow(with: downloadedRelease.appRelease, at: proxy.frame(in: .global).origin)
                    }.onAppear {
                        opacity = 1
                    }
                }.frame(maxWidth: 250)
            case .installing:
                ButtonLabel("Installing update…")
            case .updateInstalled:
                ButtonLabel(updateInstalledMessage(timerExpired: timerExpired), customStyle: buttonLabelStyle) {
                    NSApp.terminate(nil)
                }.onAppear(perform: {
                    updateInstalledTimerCancellable = Timer.publish(every: 3, on: .main, in: .common).autoconnect().sink(receiveValue: { _ in
                        timerExpired = true
                    })
                })
            default:
                EmptyView()
            }
        }.opacity(opacity)
    }

    func updateInstalledMessage(timerExpired: Bool) -> String {
        timerExpired ? "Update installed… Click to relaunch" : "Update installed."
    }

    private var buttonLabelStyle: ButtonLabelStyle {
        return ButtonLabelStyle(spacing: 1, activeBackgroundColor: .clear)
    }

    private var beamStyle: ReleaseNoteView.ReleaseNoteViewStyle {

        let style = ReleaseNoteView.ReleaseNoteViewStyle(titleFont: BeamFont.medium(size: 13).swiftUI, titleColor: BeamColor.Niobium.swiftUI,
                                                         buttonFont: BeamFont.medium(size: 12).swiftUI, buttonColor: BeamColor.LightStoneGray.swiftUI,
                                                         buttonHoverColor: BeamColor.Niobium.swiftUI, closeButtonColor: BeamColor.LightStoneGray.swiftUI,
                                                         closeButtonHoverColor: BeamColor.Niobium.swiftUI, dateFont: BeamFont.medium(size: 12).swiftUI,
                                                         dateColor: BeamColor.AlphaGray.swiftUI, versionNameFont: BeamFont.medium(size: 13).swiftUI, versionNameColor: BeamColor.Niobium.swiftUI, backgroundColor: BeamColor.Generic.background.swiftUI, cellHoverColor: BeamColor.Nero.swiftUI, separatorColor: BeamColor.Mercury.swiftUI, parmaRenderer: BeamRender())

        return style
    }

    private func showReleaseNoteWindow(with release: AppRelease, at origin: CGPoint, hideButtonOnClose: Bool = false) {
        let window = CustomPopoverPresenter.shared.presentPopoverChildWindow()
        let releaseNoteView = ReleaseNoteView(release: release, closeAction: {
            if hideButtonOnClose {
                withAnimation {
                    opacity = 0
                }
            }
            window?.close()
        }, beforeInstallAction: {
            window?.close()
        }, history: versionChecker.missedReleases, checker: self.versionChecker, style: beamStyle).cornerRadius(6)

        var origin = origin
        origin.x += 7
        origin.y += 25

        window?.setView(with: releaseNoteView, at: origin)
        window?.makeKey()
    }
}

struct SmallUpdateIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        let checker = VersionChecker(mockedReleases: AppRelease.mockedReleases())
        SmallUpdateIndicatorView(versionChecker: checker)
    }
}

struct BeamRender: ParmaRenderable {

    func paragraph(text: String) -> Text {
        Text(text)
            .font(BeamFont.regular(size: 12).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
    }

    func heading(level: HeadingLevel?, textView: Text) -> Text {
        textView
            .font(BeamFont.medium(size: 13).swiftUI)
            .foregroundColor(BeamColor.Generic.text.swiftUI)
    }

    func listItem(attributes: ListAttributes, index: [Int], view: AnyView) -> AnyView {
        let delimiter: String
        switch attributes.delimiter {
        case .period:
            delimiter = "."
        case .parenthesis:
            delimiter = ")"
        }

        let separator: String
        switch attributes.type {
        case .bullet:
            separator = index.count % 2 == 1 ? "•" : "◦"
        case .ordered:
            separator = index
                .map({ String($0) })
                .joined(separator: ".")
                .appending(delimiter)
        }

        return AnyView(
            HStack(alignment: .top, spacing: 4) {
                Text(separator)
                    .foregroundColor(BeamColor.AlphaGray.swiftUI)
                view
            }
        )
    }
}
