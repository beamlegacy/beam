//
//  DownloadCell.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 27/05/2021.
//

import SwiftUI
import Combine

struct DownloadCell: View {

    private enum OnHoverState {
        case pause
        case resume
        case view
    }

    @Environment(\.colorScheme) var colorScheme

    @ObservedObject var download: Download
    @State private var hoverState: OnHoverState?
    var isSelected: Bool
    private weak var downloadManager: BeamDownloadManager?
    private var onDeleteKeyDownAction: (() -> Void)?

    init(download: Download, from downloadManager: BeamDownloadManager? = nil, isSelected: Bool = false, onDeleteKeyDownAction: (() -> Void)? = nil) {
        self.download = download
        self.isSelected = isSelected
        self.downloadManager = downloadManager
        self.onDeleteKeyDownAction = onDeleteKeyDownAction
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: icon(for: download.fileSystemURL.pathExtension))
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 4) {
                Text(download.fileSystemURL.lastPathComponent)
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Niobium.swiftUI)
                if let task = download.downloadTask,
                   task.state == .running {
                    LinearProgressView(progress: download.progress, height: 3.0)
                }
                Text(detailString)
                    .animation(.none)
                    .font(BeamFont.regular(size: 10).swiftUI)
                    .foregroundColor(BeamColor.LightStoneGray.swiftUI)
            }.allowsHitTesting(false)
            Spacer()
            switch download.state {
            case .running:
                CircledButton(image: "download-pause", action: pauseDownload, onHover: { hover in
                    hoverState = hover ? .pause : nil
                }).blendModeLightMultiplyDarkScreen()
            case .suspended:
                CircledButton(image: "download-resume", action: resumeDownload, onHover: { hover in
                    hoverState = hover ? .resume : nil
                }).blendModeLightMultiplyDarkScreen()
            case .completed where download.errorMessage != nil:
                CircledButton(image: "download-resume", action: resumeDownload, onHover: { hover in
                    hoverState = hover ? .resume : nil
                }).blendModeLightMultiplyDarkScreen()
            case .completed, .canceling:
                EmptyView()
            @unknown default:
                EmptyView()
            }
            CircledButton(image: "download-view", action: showInFinder, onHover: { hover in
                hoverState = hover ? .view : nil
            }).blendModeLightMultiplyDarkScreen()
        }
        .padding(.horizontal, 8)
        .animation(.easeInOut(duration: 0.3), value: hoverState)
        .frame(height: 53)
        .background(KeyEventHandlingView(handledKeyCodes: [.space, .enter, .backspace, .delete], onKeyDown: onKeyDown(event:)))
        .background(backgroundColor.cornerRadius(6))
    }

    private var backgroundColor: Color {
        self.isSelected ? BeamColor.Autocomplete.clickedBackground.swiftUI : BeamColor.Generic.background.swiftUI
    }

    private var detailString: String {
        if let buttonHovered = hoverState {
            switch buttonHovered {
            case .pause:
                return "Cancel Download"
            case .resume:
                return "Resume Download"
            case .view:
                return "View in Finder"
            }
        } else {
            if let error = download.errorMessage {
                return error.capitalized
            }
            switch download.state {
            case .running:
                return download.localizedProgressString ?? ""
            case .suspended:
                return "\(download.localizedProgressString ?? "") · Stopped"
            case .canceling:
                return "\(download.localizedProgressString ?? "") · Canceling"
            case .completed:
                return download.totalByteCount ?? ""
            @unknown default:
                return ""
            }
        }
    }

    private func icon(for fileExtension: String) -> NSImage {
        NSWorkspace.shared.icon(forFileType: fileExtension)
    }

    private func pauseDownload() {
        downloadManager?.cancel(download)
    }

    private func resumeDownload() {
        downloadManager?.resume(download)
    }

    private func openFile() {
        downloadManager?.openFile(download)
    }

    private func showInFinder() {
        downloadManager?.showInFinder(download)
    }

    private func onKeyDown(event: NSEvent) {
        switch event.keyCode {
        case KeyCode.enter.rawValue:
            openFile()
        case KeyCode.space.rawValue:
            pauseOrResumeDependingOnState()
        case KeyCode.backspace.rawValue, KeyCode.delete.rawValue:
            onDeleteKeyDownAction?()
        default:
            break
        }
    }

    private func pauseOrResumeDependingOnState() {
        switch download.state {
        case .running:
            pauseDownload()
        case .suspended:
            resumeDownload()
        case .completed where download.errorMessage != nil:
            resumeDownload()
        default:
            break
        }
    }
}

struct DownloadCell_Previews: PreviewProvider {
    static var previews: some View {
        let d1 = Download(downloadURL: URL(string: "https://devimages-cdn.apple.com/design/resources/download/SF-Symbols-2.1.dmg")!, fileSystemURL: URL(fileURLWithPath: "/"), suggestedFileName: "", downloadTask: nil)
        d1.fakeState = .completed

        let d2 = Download(downloadURL: URL(string: "https://devimages-cdn.apple.com/design/resources/download/SF-Symbols-2.1.dmg")!, fileSystemURL: URL(fileURLWithPath: "/"), suggestedFileName: "", downloadTask: nil)
        d2.fakeState = .suspended

        let d3 = Download(downloadURL: URL(string: "https://devimages-cdn.apple.com/design/resources/download/SF-Symbols-2.1.dmg")!, fileSystemURL: URL(fileURLWithPath: "/"), suggestedFileName: "", downloadTask: nil)
        d3.fakeState = .running

        return Group {
            Group {
                DownloadCell(download: d1)
                    .frame(width: 368.0)
                DownloadCell(download: d2)
                    .frame(width: 368.0)
                DownloadCell(download: d3)
                    .frame(width: 368.0)
            }
            Group {
                DownloadCell(download: d1)
                    .frame(width: 368.0)
                DownloadCell(download: d2)
                    .frame(width: 368.0)
                DownloadCell(download: d3)
                    .frame(width: 368.0)
            }.preferredColorScheme(.dark)
        }

    }
}
