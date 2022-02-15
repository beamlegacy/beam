//
//  DownloaderView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 27/05/2021.
//

import SwiftUI
import Combine

struct DownloaderView<List: DownloadListProtocol>: View {

    @ObservedObject private var downloadList: List

    private let disabledContentColor = BeamColor.Button.text.swiftUI.opacity(0.13)
    private let contentColor = BeamColor.Button.text.swiftUI
    private let activeContentColor = BeamColor.Button.activeText.swiftUI

    @State private var isHovering: Bool = false
    @State private var isHoveringHeader: Bool = false

    @State private var selectedDownloads: Set<List.Element> = []
    @State private var lastManuallyInsertedDownload: List.Element?

    let preferredWidth: CGFloat = 368.0

    private var onClose: () -> Void

    init(downloadList: List, onCloseButtonTap: @escaping () -> Void) {
        self.downloadList = downloadList
        self.onClose = onCloseButtonTap
    }

    var body: some View {
        VStack(spacing: 4.0) {
            VStack(spacing: 4.0) {
                HStack(spacing: 14.0) {
                    Text("Downloads")
                        .font(BeamFont.medium(size: 13).swiftUI)
                    Spacer()
                    ButtonLabel("Clear") {
                        downloadList.removeAllCompletedOrSuspendedDownloads()
                    }
                    .opacity(shouldDisplayClearButton ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: shouldDisplayClearButton)
                    Button(action: {
                        onClose()
                    }, label: {
                        Image("tool-close")
                            .renderingMode(.template)
                            .foregroundColor(foregroundColor)
                    })
                    .buttonStyle(RoundRectButtonStyle())
                    .foregroundColor(foregroundColor)
                    .onHover { h in
                        withAnimation {
                            self.isHovering = h
                        }
                    }
                }.onHover { h in
                    withAnimation {
                        self.isHoveringHeader = h
                    }
                }
                Separator(horizontal: true)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .animation(.easeInOut(duration: 1), value: isHoveringHeader)
            .animation(.easeInOut(duration: 1), value: isHovering)
            .transition(.opacity)
            VStack(spacing: 2) {
                ForEach(downloadList.downloads) { download in
                    ZStack {
                        DownloadCell(download: download, from: downloadList, isSelected: selectedDownloads.contains(download), onDeleteKeyDownAction: backspaceTappedInCell)
                        ClickCatchingView(onTap: { event in
                            if event.modifierFlags.contains(.command) {
                                if selectedDownloads.contains(download) {
                                    selectedDownloads.remove(download)
                                    lastManuallyInsertedDownload = nil
                                } else {
                                    selectedDownloads.insert(download)
                                    lastManuallyInsertedDownload = download
                                }
                            } else if event.modifierFlags.contains(.shift) {
                                guard let tappedIndex = downloadList.downloads.firstIndex(of: download) else { return }
                                if let last = lastManuallyInsertedDownload, let initialIndex = downloadList.downloads.firstIndex(of: last) {
                                    let minIndex = min(initialIndex, tappedIndex)
                                    let maxIndex = max(initialIndex, tappedIndex)
                                    selectedDownloads = Set(downloadList.downloads[minIndex...maxIndex])
                                } else {
                                    selectedDownloads = Set(downloadList.downloads[0...tappedIndex])
                                }
                            } else {
                                selectedDownloads = [download]
                                lastManuallyInsertedDownload = download
                            }
                        }, onDoubleTap: { _ in
                            downloadList.openFile(download)
                        })
                        .padding(.trailing, (download.state == .completed && download.errorMessage == nil) ? 20 : 40)
                        .frame(height: 53) //Force the height to fix a bug on Monterey were the ClickCatchingView is not getting the good height
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
            .padding(.top, 2)
        }
        .frame(width: preferredWidth)
        .background(BeamColor.Generic.background.swiftUI)
        .cornerRadius(10)
        .alert(item: $downloadList.showAlertFileNotFoundForDownload, content: { download in
            Alert(title: Text("Beam can’t show the file “\(download.filename ?? "?")” in the Finder."), message: Text("The file has moved since you downloaded it. You can download it again or remove it from Beam."), primaryButton: .default(Text("Download again"), action: {
                downloadList.restart(download)
            }), secondaryButton: .destructive(Text("Remove"), action: {
                downloadList.remove(download)
            }))
        })
    }

    private var shouldDisplayClearButton: Bool {
        if isHoveringHeader {
            return true
        } else if downloadList.containsOnlyCompletedOrSuspendedDownloads {
            return true
        } else {
            return false
        }
    }

    private var foregroundColor: Color {
        return isHovering ? activeContentColor : contentColor
    }

    private func backspaceTappedInCell() {
        for download in selectedDownloads {
            downloadList.removeDownloadIfCompletedOrSuspended(download)
        }
        selectedDownloads = []
        lastManuallyInsertedDownload = nil
    }
}

struct DownloaderView_Previews: PreviewProvider {

    static var previews: some View {
        let downloadList = DownloadListFake(isDownloading: false)

        downloadList.downloads = [
            DownloadListItemFake(
                filename: "Uno.txt",
                fileExtension: "txt",
                state: .completed,
                progressFractionCompleted: 1,
                localizedDescription: "100 MB"
            ),
            DownloadListItemFake(
                filename: "Dos.mp4",
                fileExtension: "mp4",
                state: .running,
                progressFractionCompleted: 0.75,
                localizedDescription: "75 MB / 100 MB"
            ),
            DownloadListItemFake(
                filename: "Tres.jpg",
                fileExtension: "jpg",
                state: .suspended,
                progressFractionCompleted: 0.5,
                localizedDescription: "50 MB / 100 MB"
            ),
            DownloadListItemFake(
                filename: "Ricky.jpg",
                fileExtension: "jpg",
                state: .suspended,
                progressFractionCompleted: 0.5,
                localizedDescription: "50 MB / 100 MB",
                errorMessage: "Ouch error"
            )
        ]

        return Group {
            DownloaderView(downloadList: downloadList, onCloseButtonTap: {})
        }
    }
}
