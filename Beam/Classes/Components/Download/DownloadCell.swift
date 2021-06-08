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

    init(download: Download) {
        self.download = download
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
                    .font(BeamFont.regular(size: 10).swiftUI)
                    .foregroundColor(BeamColor.LightStoneGray.swiftUI)
            }
            Spacer()
            if download.state == .running {
                CircledButton(image: "download-pause", action: {
                    download.downloadTask?.progress.pause()
                }, onHover: { hover in
                    hoverState = hover ? .pause : nil
                })
            } else if download.state == .suspended {
                CircledButton(image: "download-resume", action: {
                    download.downloadTask?.progress.resume()
                }, onHover: { hover in
                    hoverState = hover ? .resume : nil
                })
            } else if download.state == .completed {
                CircledButton(image: "download-view", action: {
                    openInFinder(url: download.fileSystemURL)
                }, onHover: { hover in
                    hoverState = hover ? .view : nil
                })
            }
        }
        .animation(.easeInOut(duration: 0.3))
        .frame(height: 53)
        .background(BeamColor.Generic.background.swiftUI)
        .alert(isPresented: $showAlertFileNotFound, content: {
            Alert(title: Text("Beam can’t show the file “\(download.downloadURL.lastPathComponent)” in the Finder."),
                  message: Text("The file has moved since you downloaded it. You can download it again or remove it from Beam."))
        })
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

    func openInFinder(url: URL) {
        guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else {
            showAlertFileNotFound = true
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
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
