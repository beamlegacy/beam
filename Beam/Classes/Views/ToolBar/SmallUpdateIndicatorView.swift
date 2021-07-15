//
//  SmallUpdateIndicatorView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 12/05/2021.
//

import SwiftUI
import AutoUpdate

struct SmallUpdateIndicatorView: View {

    @EnvironmentObject var versionChecker: VersionChecker

    @State private var showReleaseNotes = false
    @State private var opacity = 1.0
    @State private var opacityTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            switch versionChecker.state {
            case .updateAvailable(let release):
                ButtonLabel("Update available", icon: "status-publish") {
                    showReleaseNotes.toggle()
                }.popover(isPresented: $showReleaseNotes, content: {
                    ReleaseNoteView(release: release, history: versionChecker.missedReleases, checker: versionChecker)
                })

            case .noUpdate where versionChecker.currentRelease != nil :
                ButtonLabel("Beam is up to date", icon: "tooltip-mark") {
                    showReleaseNotes.toggle()
                }
                .onReceive(opacityTimer, perform: { _ in
                    withAnimation {
                        opacity = 0
                    }
                    opacityTimer.upstream.connect().cancel()
                })
                .popover(isPresented: $showReleaseNotes, content: {
                    ReleaseNoteView(release: versionChecker.currentRelease!)
                        .onDisappear(perform: {
                            withAnimation {
                                opacity = 0
                            }
                        })
                })
            case .noUpdate where versionChecker.lastCheck == nil :
                EmptyView()
            case .checking:
                EmptyView()
            case .error(errorDesc: let errorDesc):
                ButtonLabel("Update error : \(errorDesc)")
            case .downloading(progress: _):
                ButtonLabel("Downloading update…")
            case .installing:
                ButtonLabel("Installing update…")
            case .updateInstalled:
                ButtonLabel("Update installed. Click here to relaunch") {
                    NSApp.terminate(nil)
                }
            default:
                EmptyView()
            }
        }.opacity(opacity)
    }
}

struct SmallUpdateIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        let checker = VersionChecker(mockedReleases: AppRelease.mockedReleases())
        SmallUpdateIndicatorView()
            .environmentObject(checker)
    }
}
