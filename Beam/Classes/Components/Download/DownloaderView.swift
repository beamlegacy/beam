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
    @Environment(\.presentationMode) var presentationMode

    private let disabledContentColor = BeamColor.Button.text.swiftUI.opacity(0.13)
    private let contentColor = BeamColor.Button.text.swiftUI
    private let activeContentColor = BeamColor.Button.activeText.swiftUI

    @State private var isHovering: Bool = false
    @State private var isHoveringHeader: Bool = false
    @State private var selectedDownload: Download?

    init(downloader: BeamDownloadManager) {
        self.downloader = downloader
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
                    .animation(.easeInOut(duration: 0.3))
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }, label: {
                        Image("tabs-close")
                            .renderingMode(.template)
                            .foregroundColor(foregroundColor)
                    })
                    .buttonStyle(RoundRectButtonStyle())
                    .foregroundColor(foregroundColor)
                    .onHover { h in
                        self.isHovering = h
                    }
                }.onHover { h in
                    self.isHoveringHeader = h
                }
                Separator(horizontal: true)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(downloader.downloads) { d in
                        DownloadCell(download: d, from: downloader, isSelected: selectedDownload == d)
                            .onTapGesture {
                                self.selectedDownload = d
                            }
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
            .padding(.top, 2)
        }
        .frame(width: 368.0)
        .background(BeamColor.Generic.background.swiftUI)
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
}

struct DownloaderView_Previews: PreviewProvider {

    static var previews: some View {

        let downloader = BeamDownloadManager()
        downloader.downloadFile(at: URL(string: "https://devimages-cdn.apple.com/design/resources/download/SF-Symbols-2.1")!, headers: [:], suggestedFileName: nil)

        return Group {
            DownloaderView(downloader: downloader)
        }
    }
}
