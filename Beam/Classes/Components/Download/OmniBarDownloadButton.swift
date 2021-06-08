//
//  OmniBarDownloadButton.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 26/05/2021.
//

import SwiftUI
import Combine

struct OmniBarDownloadButton: View {

    @ObservedObject var downloadManager: BeamDownloadManager
    var action: () -> Void

    @State private var isHovering: Bool = false

    private let disabledContentColor = BeamColor.Button.text.swiftUI.opacity(0.13)
    private let contentColor = BeamColor.Button.text.swiftUI
    private let activeContentColor = BeamColor.Button.activeText.swiftUI

    init(downloadManager: BeamDownloadManager, action: @escaping () -> Void) {
        self.downloadManager = downloadManager
        self.action = action
    }

    var body: some View {
        Button(action: action, label: {
            VStack(spacing: 0) {
                Icon(name: ongoingDownload ? "nav-downloads" : "nav-downloads_done", size: 20, color: foregroundColor)
                if ongoingDownload {
                    LinearProgressView(progress: downloadManager.fractionCompleted)
                        .frame(width: 16)
                }
            }
        })
        .accessibility(identifier: "")
        .buttonStyle(RoundRectButtonStyle())
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
        .onHover { h in
            self.isHovering = h
        }
    }

    var foregroundColor: Color {
        return isHovering ? activeContentColor : contentColor
    }

    var ongoingDownload: Bool {
        downloadManager.ongoingDownload
    }
}

struct OmniBarDownloadButton_Previews: PreviewProvider {
    static var previews: some View {
        let noDownloadsManager = BeamDownloadManager()
        let downloadsManager = BeamDownloadManager()
        downloadsManager.downloadFile(at: URL(string: "https://devimages-cdn.apple.com/design/resources/download/SF-Symbols.dmg")!, headers: [:])
        return Group {
            OmniBarDownloadButton(downloadManager: noDownloadsManager, action: {})
            OmniBarDownloadButton(downloadManager: downloadsManager, action: {})
        }
    }
}
