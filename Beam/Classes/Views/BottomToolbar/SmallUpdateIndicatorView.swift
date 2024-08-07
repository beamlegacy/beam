//
//  SmallUpdateIndicatorView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 12/05/2021.
//

import SwiftUI
import AutoUpdate
import Combine

struct SmallUpdateIndicatorView: View {

    @ObservedObject var versionChecker: VersionChecker
    @EnvironmentObject var state: BeamState

    @State private var opacity = 1.0
    @State private var opacityTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    @State private var updateInstalledTimerCancellable: Cancellable?
    @State private var timerExpired = false

    var body: some View {
        Group {
            let message = versionChecker.state.informativeMessage

            switch versionChecker.state {
            case .updateAvailable(let release):
                ButtonLabel("Update available", icon: "status-publish", customStyle: buttonLabelStyle) {
                    showReleaseNoteWindow(with: release)
                }
                .onAppear {
                    opacity = 1
                }
            case .noUpdate where versionChecker.currentRelease != nil :
                ButtonLabel("Updated", icon: "tool-keep", customStyle: buttonLabelStyle) {
                    showReleaseNoteWindow(with: versionChecker.currentRelease!, hideButtonOnClose: true)
                }
                .onReceive(opacityTimer, perform: { _ in
                    withAnimation {
                        opacity = 0
                    }
                    opacityTimer.upstream.connect().cancel()
                })
            case .noUpdate where versionChecker.lastCheck == nil :
                EmptyView()
            case .checking:
                EmptyView()
            case .error(errorDesc: let errorDesc):
                ButtonLabel("\(errorDesc)",
                            icon: "status-update_failed",
                            customStyle: buttonLabelStyle)
                .onReceive(opacityTimer, perform: { _ in
                    withAnimation {
                        opacity = 0
                    }
                    opacityTimer.upstream.connect().cancel()
                })
            case .downloading(progress: _):
                ButtonLabel(message, lottie: "status-update_restart", customStyle: buttonLabelLottieStyle)
            case .downloaded(let downloadedRelease):
                ButtonLabel("Update now", icon: "status-publish", customStyle: buttonLabelStyle) {
                    showReleaseNoteWindow(with: downloadedRelease.appRelease)
                }
                .onAppear {
                    opacity = 1
                }
            case .installing:
                ButtonLabel(message, lottie: "status-update_restart", customStyle: buttonLabelLottieStyle)
            case .updateInstalled:
                ButtonLabel(updateInstalledMessage(timerExpired: timerExpired),
                            lottie: "status-update_restart",
                            customStyle: buttonLabelLottieStyle) {
                    updateInstalledTimerCancellable?.cancel()
                    NSApp.terminate(nil)
                }
                            .onAppear(perform: {
                                updateInstalledTimerCancellable = Timer.publish(every: 3, on: .main, in: .common).autoconnect().sink(receiveValue: { _ in
                                    timerExpired = true
                                })
                            })
                            .onDisappear {
                                updateInstalledTimerCancellable?.cancel()
                            }
            default:
                EmptyView()
            }
        }
        .opacity(opacity)
        .onHover { hover in
            state.shouldDisableLeadingGutterHover = hover
        }
    }

    func updateInstalledMessage(timerExpired: Bool) -> String {
        timerExpired ? "Updated. Restarting…" : "Updated."
    }

    private var buttonLabelStyle: ButtonLabelStyle {
        return ButtonLabelStyle(spacing: 1,
                                foregroundColor: BeamColor.LightStoneGray.swiftUI,
                                activeForegroundColor: BeamColor.Niobium.swiftUI,
                                backgroundColor: BeamColor.Generic.background.swiftUI,
                                hoveredBackgroundColor: BeamColor.Mercury.swiftUI,
                                activeBackgroundColor: BeamColor.AlphaGray.swiftUI.opacity(0.5),
                                leadingPaddingAdjustment: 4)
    }

    private var buttonLabelLottieStyle: ButtonLabelStyle {
        return ButtonLabelStyle(iconSize: 12,
                                spacing: 3,
                                foregroundColor: BeamColor.LightStoneGray.swiftUI,
                                activeForegroundColor: BeamColor.Niobium.swiftUI,
                                backgroundColor: BeamColor.Generic.background.swiftUI,
                                hoveredBackgroundColor: BeamColor.Mercury.swiftUI,
                                activeBackgroundColor: BeamColor.AlphaGray.swiftUI.opacity(0.5),
                                leadingPaddingAdjustment: 4)
    }

    private var beamStyle: ReleaseNoteView.ReleaseNoteViewStyle {

        let style = ReleaseNoteView.ReleaseNoteViewStyle(titleFont: BeamFont.medium(size: 13).swiftUI, titleColor: BeamColor.Niobium.swiftUI,
                                                         buttonFont: BeamFont.medium(size: 12).swiftUI, buttonColor: BeamColor.LightStoneGray.swiftUI,
                                                         buttonHoverColor: BeamColor.Niobium.swiftUI, closeButtonColor: BeamColor.LightStoneGray.swiftUI,
                                                         closeButtonHoverColor: BeamColor.Niobium.swiftUI, dateFont: BeamFont.medium(size: 12).swiftUI,
                                                         dateColor: BeamColor.AlphaGray.swiftUI, versionNameFont: BeamFont.medium(size: 13).swiftUI,
                                                         versionNameColor: BeamColor.Niobium.swiftUI,
                                                         backgroundColor: BeamColor.Generic.secondaryBackground.swiftUI, cellHoverColor: BeamColor.Nero.swiftUI,
                                                         separatorView: AnyView(PopupSeparator()))

        return style
    }

    private func showReleaseNoteWindow(with release: AppRelease, hideButtonOnClose: Bool = false) {
        UpdatePanel.showReleaseNoteWindow(with: release, versionChecker: versionChecker)
    }

    private struct ButtonFramePreferenceKey: FramePreferenceKey {}
}

struct SmallUpdateIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        let checker = VersionChecker(mockedReleases: AppRelease.mockedReleases())
        SmallUpdateIndicatorView(versionChecker: checker)
    }
}
