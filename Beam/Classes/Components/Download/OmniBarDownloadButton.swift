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

    private var previewFractionCompleted: CGFloat?
    fileprivate init(downloadManager: BeamDownloadManager, previewFraction: CGFloat, action: @escaping () -> Void) {
        self.init(downloadManager: downloadManager, action: action)
        self.previewFractionCompleted = previewFraction
    }

    var body: some View {
        OmniboxV2ToolbarButton(icon: hasOngoingDownload ? "nav-downloads" : "nav-downloads_done",
                               customIconSize: hasOngoingDownload ? CGSize(width: 20, height: 20) : nil,
                               action: action)
            .overlay(!hasOngoingDownload ?  nil :
                        LinearProgressView(progress: previewFractionCompleted ?? downloadManager.fractionCompleted)
                        .frame(width: 16).padding(.bottom, 2),
                     alignment: .bottom
            )
            .accessibility(identifier: "downloads")
            .animation(Animation.default.delay(0.2), value: hasOngoingDownload)
    }

    var foregroundColor: Color {
        return isHovering ? activeContentColor : contentColor
    }

    var hasOngoingDownload: Bool {
        downloadManager.ongoingDownload || previewFractionCompleted != nil
    }
}

struct OmniBarDownloadButton_Previews: PreviewProvider {
    static var previews: some View {
        let noDownloadsManager = BeamDownloadManager()
        let downloadsManager = BeamDownloadManager()
        return Group {
            OmniBarDownloadButton(downloadManager: noDownloadsManager, action: {})
            OmniBarDownloadButton(downloadManager: downloadsManager, previewFraction: 0.7, action: {})
        }
    }
}
