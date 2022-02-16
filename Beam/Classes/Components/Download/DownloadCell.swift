//
//  DownloadCell.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 27/05/2021.
//

import SwiftUI
import Combine

struct DownloadCell<ListItem, List: DownloadListProtocol>: View where ListItem == List.Element {

    private enum OnHoverState {
        case pause
        case resume
        case view
    }

    @Environment(\.colorScheme) var colorScheme

    @ObservedObject private var download: ListItem
    @State private var hoverState: OnHoverState?
    var isSelected: Bool
    private weak var downloadList: List?
    private var onDeleteKeyDownAction: (() -> Void)?

    init(download: ListItem, from downloadList: List? = nil, isSelected: Bool = false, onDeleteKeyDownAction: (() -> Void)? = nil) {
        self.download = download
        self.isSelected = isSelected
        self.downloadList = downloadList
        self.onDeleteKeyDownAction = onDeleteKeyDownAction
    }

    var body: some View {
        HStack(spacing: 8) {

            if let filename = download.filename,
               let fileExtension = download.fileExtension {

                Image(nsImage: icon(for: fileExtension))
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 4) {
                    Text(filename)
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Niobium.swiftUI)
                    if download.state == .running {
                        LinearProgressView(progress: download.progressFractionCompleted, height: 3.0)
                    }
                    Text(detailString)
                        .animation(.none)
                        .font(BeamFont.regular(size: 10).swiftUI)
                        .foregroundColor(BeamColor.LightStoneGray.swiftUI)
                        .blendModeLightMultiplyDarkScreen()
                }.allowsHitTesting(false)

            }

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
            case .completed:
                EmptyView()
            }
            CircledButton(image: "download-view", action: showInFinder, onHover: { hover in
                hoverState = hover ? .view : nil
            }).blendModeLightMultiplyDarkScreen()
        }
        .padding(.trailing, 8)
        .padding(.leading, 7)
        .animation(.easeInOut(duration: 0.3), value: hoverState)
        .frame(height: 53)
        .background(KeyEventHandlingView(handledKeyCodes: [.space, .enter, .backspace, .delete], onKeyDown: onKeyDown(event:)))
        .background(backgroundColor.cornerRadius(6))
    }

    private var backgroundColor: Color {
        self.isSelected ? BeamColor.Autocomplete.clickedBackground.swiftUI : BeamColor.Generic.secondaryBackground.swiftUI
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
                return download.progressDescription ?? ""
            case .suspended:
                return "\(download.progressDescription ?? "") · Stopped"
            case .completed:
                return download.progressDescription ?? ""
            }
        }
    }

    private func icon(for fileExtension: String) -> NSImage {
        NSWorkspace.shared.icon(forFileType: fileExtension)
    }

    private func pauseDownload() {
        downloadList?.cancel(download)
    }

    private func resumeDownload() {
        downloadList?.resume(download)
    }

    private func openFile() {
        downloadList?.openFile(download)
    }

    private func showInFinder() {
        downloadList?.showInFinder(download)
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
        let list = DownloadListFake()

        Group {
            DownloadCell(
                download: DownloadListItemFake(
                    filename: "Uno.txt",
                    fileExtension: "txt",
                    state: .completed,
                    progressFractionCompleted: 1,
                    localizedDescription: "100 MB"
                ),
                from: list
            )

            DownloadCell(
                download: DownloadListItemFake(
                    filename: "Dos.mp4",
                    fileExtension: "mp4",
                    state: .running,
                    progressFractionCompleted: 0.75,
                    localizedDescription: "75 MB / 100 MB"
                ),
                from: list
            )

            DownloadCell(
                download: DownloadListItemFake(
                    filename: "Tres.jpg",
                    fileExtension: "jpg",
                    state: .suspended,
                    progressFractionCompleted: 0.5,
                    localizedDescription: "50 MB / 100 MB"
                ),
                from: list
            )

            DownloadCell(
                download: DownloadListItemFake(
                    filename: "Ricky.jpg",
                    fileExtension: "jpg",
                    state: .suspended,
                    progressFractionCompleted: 0.5,
                    localizedDescription: "50 MB / 100 MB",
                    errorMessage: "Ouch error"
                ),
                from: list
            )
        }
        .frame(width: 368.0)
    }
}
