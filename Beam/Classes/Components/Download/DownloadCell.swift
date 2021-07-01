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

    @ObservedObject var download: Download
    @State private var hoverState: OnHoverState?
    @State private var showAlertFileNotFound: Bool = false
    var isSelected: Bool
    private weak var downloadManager: DownloadManager?

    init(download: Download, from downloadManager: DownloadManager? = nil, isSelected: Bool = false) {
        self.download = download
        self.isSelected = isSelected
        self.downloadManager = downloadManager
        showAlertFileNotFound = false
    }

    var body: some View {
        HStack(spacing: 8) {
            Image("download-icon")
            VStack(alignment: .leading, spacing: 4) {
                Text(download.fileSystemURL.lastPathComponent)
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Niobium.swiftUI)
                if let task = download.downloadTask,
                   task.state == .running {
                    LinearProgressView(progress: download.progress)
                }
                Text(detailString)
                    .animation(.none)
                    .font(BeamFont.regular(size: 10).swiftUI)
                    .foregroundColor(BeamColor.LightStoneGray.swiftUI)
            }
            Spacer()
            if download.state == .running {
                CircledButton(image: "download-pause", action: pauseDownload, onHover: { hover in
                    hoverState = hover ? .pause : nil
                }).blendMode(.multiply)
            } else if download.state == .suspended {
                CircledButton(image: "download-resume", action: resumeDownload, onHover: { hover in
                    hoverState = hover ? .resume : nil
                }).blendMode(.multiply)
            } else if download.state == .completed {
                CircledButton(image: "download-view", action: showInFinder, onHover: { hover in
                    hoverState = hover ? .view : nil
                }).blendMode(.multiply)
            }
        }
        .padding(.horizontal, 8)
        .animation(.easeInOut(duration: 0.3))
        .frame(height: 53)
        .background(KeyEventHandlingView(onKeyDown: onKeyDown(event:), handledKeyCodes: [.space, .enter, .backspace, .delete]))
        .background(backgroundColor.cornerRadius(6))
        .alert(isPresented: $showAlertFileNotFound, content: {
            Alert(title: Text("Beam can’t show the file “\(download.downloadURL.lastPathComponent)” in the Finder."),
                  message: Text("The file has moved since you downloaded it. You can download it again or remove it from Beam."))
        })
        .onTapGesture(count: 2) {
            openFile()
        }
    }

    private var backgroundColor: Color {
        self.isSelected ? BeamColor.Autocomplete.clickedBackground.swiftUI : BeamColor.Generic.background.swiftUI
    }

    private var detailString: String {
        if let buttonHovered = hoverState {
            switch buttonHovered {
            case .pause:
                return "Pause Download"
            case .resume:
                return "Resume Download"
            case .view:
                return "View in Finder"
            }
        } else {
            if let error = download.errorMessage {
                return error
            }
            switch download.state {
            case .running:
                return download.localizedProgressString ?? ""
            case .suspended:
                return "\(download.localizedProgressString ?? "") · Stopped"
            case .canceling:
                return "\(download.localizedProgressString ?? "") · Stopping"
            case .completed:
                return download.totalCount ?? ""
            @unknown default:
                return ""
            }
        }
    }

    private func deleteDownload() {
        downloadManager?.clearFileDownload(download)
    }

    private func pauseDownload() {
        download.downloadTask?.progress.pause()
    }

    private func resumeDownload() {
        download.downloadTask?.progress.resume()
    }

    private func showInFinder() {
        let url = download.fileSystemURL
        guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else {
            showAlertFileNotFound = true
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func openFile() {
        let url = download.fileSystemURL
        guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func onKeyDown(event: NSEvent) {
        switch event.keyCode {
        case KeyCode.space.rawValue, KeyCode.enter.rawValue:
            openFile()
        case KeyCode.backspace.rawValue, KeyCode.delete.rawValue:
            if download.state == .running {
                pauseDownload()
            } else {
                deleteDownload()
            }
        default:
            break
        }
    }
}

struct DownloadCell_Previews: PreviewProvider {
    static var previews: some View {
        let d1 = Download(downloadURL: URL(string: "https://devimages-cdn.apple.com/design/resources/download/SF-Symbols-2.1.dmg")!, fileSystemURL: URL(fileURLWithPath: "/"), downloadTask: nil)
        d1.fakeState = .completed

        let d2 = Download(downloadURL: URL(string: "https://devimages-cdn.apple.com/design/resources/download/SF-Symbols-2.1.dmg")!, fileSystemURL: URL(fileURLWithPath: "/"), downloadTask: nil)
        d2.fakeState = .suspended

        let d3 = Download(downloadURL: URL(string: "https://devimages-cdn.apple.com/design/resources/download/SF-Symbols-2.1.dmg")!, fileSystemURL: URL(fileURLWithPath: "/"), downloadTask: nil)
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
            if #available(macOS 11.0, *) {
                Group {
                    DownloadCell(download: d1)
                        .frame(width: 368.0)
                    DownloadCell(download: d2)
                        .frame(width: 368.0)
                    DownloadCell(download: d3)
                        .frame(width: 368.0)
                }.preferredColorScheme(.dark)
            } else {
                // Fallback on earlier versions
            }
        }

    }
}
