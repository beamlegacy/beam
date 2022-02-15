//
//  ToolbarDownloadButton.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 26/05/2021.
//

import SwiftUI
import Combine

struct ToolbarDownloadButton<List: DownloadListProtocol>: View {

    @ObservedObject private var downloadList: List
    var action: () -> Void

    @State private var isHovering: Bool = false

    private let disabledContentColor = BeamColor.Button.text.swiftUI.opacity(0.13)
    private let contentColor = BeamColor.Button.text.swiftUI
    private let activeContentColor = BeamColor.Button.activeText.swiftUI

    init(downloadList: List, action: @escaping () -> Void) {
        self.downloadList = downloadList
        self.action = action
    }

    var body: some View {
        ToolbarButton(icon: downloadList.isDownloading ? "nav-downloads" : "nav-downloads_done",
                      action: action)
            .overlay(!downloadList.isDownloading ? nil :
                        LinearProgressView(progress: downloadList.progressFractionCompleted, height: 2.0)
                        .frame(width: 16)
                        .padding(.bottom, 5),
                     alignment: .bottom
            )
            .accessibility(identifier: "downloads")
    }

}

struct ToolbarDownloadButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ToolbarDownloadButton(
                downloadList: DownloadListFake(isDownloading: false),
                action: {}
            )
            ToolbarDownloadButton(
                downloadList: DownloadListFake(isDownloading: true, progressFractionCompleted: 0.7),
                action: {}
            )
        }
    }
}
