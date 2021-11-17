//
//  DownloaderView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 27/05/2021.
//

import SwiftUI
import Combine

struct DownloaderView: View {

    @ObservedObject var downloader: BeamDownloadManager

    private let disabledContentColor = BeamColor.Button.text.swiftUI.opacity(0.13)
    private let contentColor = BeamColor.Button.text.swiftUI
    private let activeContentColor = BeamColor.Button.activeText.swiftUI

    @State private var isHovering: Bool = false
    @State private var isHoveringHeader: Bool = false

    @State private var selectedDownloads: Set<Download> = []
    @State private var lastManuallyInsertedDownload: Download?

    static var width: CGFloat = 368.0

    private var onClose: () -> Void

    init(downloader: BeamDownloadManager, onCloseButtonTap: @escaping () -> Void) {
        self.downloader = downloader
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
                        downloader.clearAllFileDownloads()
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
                ForEach(downloader.downloads) { d in
                    ZStack {
                        DownloadCell(download: d, from: downloader, isSelected: selectedDownloads.contains(d), onDeleteKeyDownAction: backspaceTappedInCell)
                        ClickCatchingView(onTap: { event in
                            if event.modifierFlags.contains(.command) {
                                if selectedDownloads.contains(d) {
                                    selectedDownloads.remove(d)
                                    lastManuallyInsertedDownload = nil
                                } else {
                                    selectedDownloads.insert(d)
                                    lastManuallyInsertedDownload = d
                                }
                            } else if event.modifierFlags.contains(.shift) {
                                guard let tappedIndex = downloader.downloads.firstIndex(of: d) else { return }
                                if let last = lastManuallyInsertedDownload, let initialIndex = downloader.downloads.firstIndex(of: last) {
                                    let minIndex = min(initialIndex, tappedIndex)
                                    let maxIndex = max(initialIndex, tappedIndex)
                                    selectedDownloads = Set(downloader.downloads[minIndex...maxIndex])
                                } else {
                                    selectedDownloads = Set(downloader.downloads[0...tappedIndex])
                                }
                            } else {
                                selectedDownloads = [d]
                                lastManuallyInsertedDownload = d
                            }
                        }, onDoubleTap: { _ in
                            downloader.openFile(d)
                        })
                        .padding(.trailing, (d.state == URLSessionDownloadTask.State.completed && d.errorMessage == nil) ? 20 : 40)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
            .padding(.top, 2)
        }
        .frame(width: Self.width)
        .background(BeamColor.Generic.background.swiftUI)
        .cornerRadius(6)
        .alert(item: $downloader.showAlertFileNotFoundForDownload, content: { download in
            Alert(title: Text("Beam can’t show the file “\(download.fileSystemURL.lastPathComponent)” in the Finder."), message: Text("The file has moved since you downloaded it. You can download it again or remove it from Beam."), primaryButton: .default(Text("Download again"), action: {
                downloader.clearFileDownload(download)
                downloader.downloadFile(at: download.downloadURL, headers: [:], suggestedFileName: download.suggestedFileName)
            }), secondaryButton: .destructive(Text("Remove"), action: {
                downloader.clearFileDownload(download)
            }))
        })
    }

    private var shouldDisplayClearButton: Bool {
        if isHoveringHeader {
            return true
        } else if !downloader.ongoingDownload && !downloader.downloads.isEmpty {
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
            guard download.state != .running else { continue }
            downloader.clearFileDownload(download)
        }
        selectedDownloads = []
        lastManuallyInsertedDownload = nil
    }
}

struct DownloaderView_Previews: PreviewProvider {

    static var previews: some View {

        let downloader = BeamDownloadManager()
        downloader.downloadFile(at: URL(string: "https://devimages-cdn.apple.com/design/resources/download/SF-Symbols-2.1")!, headers: [:], suggestedFileName: nil)

        return Group {
            DownloaderView(downloader: downloader, onCloseButtonTap: {})
        }
    }
}
