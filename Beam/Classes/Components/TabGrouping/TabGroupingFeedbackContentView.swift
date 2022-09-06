//
//  TabGroupingFeedbackContentView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 15/03/2022.
//

import SwiftUI
import BeamCore

private final class TabGroupingFeedbackItem: NSObject, Codable, Identifiable {
    var id = UUID().uuidString
    var pageId: UUID

    init(pageId: UUID) {
        self.pageId = pageId
    }
}

extension TabGroupingFeedbackItem: NSItemProviderWriting {
    static let typeIdentifier = "co.beamapp.clustering.tabitem"

    static var writableTypeIdentifiersForItemProvider: [String] {
        [Self.typeIdentifier]
    }

    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        let progress = Progress(totalUnitCount: 100)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self)
            progress.completedUnitCount = 100
            completionHandler(data, nil)
        } catch {
            completionHandler(nil, error)
        }

        return progress
    }
}

extension TabGroupingFeedbackItem: NSItemProviderReading {
    static var readableTypeIdentifiersForItemProvider: [String] {
        [Self.typeIdentifier]
    }

    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> TabGroupingFeedbackItem {
        let decoder = JSONDecoder()
        return try decoder.decode(TabGroupingFeedbackItem.self, from: data)
    }
}

private struct TabDropDelegate: DropDelegate {
    var newGrpId: UUID?
    var viewModel: TabGroupingFeedbackViewModel

    func dropEntered(info: DropInfo) {
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard info.hasItemsConforming(to: [TabGroupingFeedbackItem.typeIdentifier]) else {
            return false
        }

        let itemProviders = info.itemProviders(for: [TabGroupingFeedbackItem.typeIdentifier])
        guard let itemProvider = itemProviders.first else {
            return false
        }

        itemProvider.loadObject(ofClass: TabGroupingFeedbackItem.self) { tabItem, _ in
            guard let tabItem = tabItem as? TabGroupingFeedbackItem else {
                return
            }

            if let newGrpId = newGrpId {
                DispatchQueue.main.async {
                    guard viewModel.remove(pageId: tabItem.pageId) else { return }
                    for group in viewModel.groups where group.id == newGrpId {
                        var newPageIDs = group.pageIds
                        newPageIDs.append(tabItem.pageId)
                        group.updatePageIds(newPageIDs)
                        viewModel.updateCorrectedPages(with: tabItem.pageId, in: group.id)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    guard viewModel.remove(pageId: tabItem.pageId) else { return }
                    let newGroup = TabGroup(pageIds: [tabItem.pageId])
                    newGroup.changeColor(viewModel.getNewColor())
                    viewModel.groups.append(newGroup)
                    viewModel.updateCorrectedPages(with: tabItem.pageId, in: newGroup.id)
                }
            }
        }
        return true
    }
}

struct TabGroupingFeedbackContentView: View {
    @ObservedObject var viewModel: TabGroupingFeedbackViewModel

    func triggerSendFeedback(saveToURL url: URL?) {
        let correctedPages = viewModel.buildCorrectedPagesForExport()
        viewModel.clusteringManager.exportSession(sessionExporter: BeamData.shared.sessionExporter,
                                                  to: url,
                                                  allPages: viewModel.allOpenedPages(),
                                                  initialBuiltGroups: viewModel.initialAssignations,
                                                  correctedPages: correctedPages)
        AppDelegate.main.tabGroupingFeedbackWindow?.close()
    }

    func triggerSaveAndSendFeedback() {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.begin { (result) in
            guard result == .OK, let url = savePanel.url else {
                savePanel.close()
                return
            }
            triggerSendFeedback(saveToURL: url)
        }
    }

    var body: some View {
        VStack {
            Text("Please, re-arrange the groups in a way that makes sense to you:")
                .padding(.bottom, 34)

            ScrollView {
                ForEach(viewModel.groups) { tabGroup in
                    VStack(spacing: 4) {
                        ForEach(tabGroup.pageIds, id: \.self) { pageId in
                            if let url = viewModel.urlFor(pageId: pageId),
                               let title = viewModel.titleFor(pageId: pageId) {
                                TabGroupingFeedbackTabView(url: url,
                                                           title: title,
                                                           color: (tabGroup.color?.mainColor?.swiftUI ?? Color.red).opacity(0.25))
                                .onDrag {
                                    return NSItemProvider(object: TabGroupingFeedbackItem(pageId: pageId))
                                }
                            }
                        }
                    }.padding(.vertical, 16)
                    .onDrop(of: [TabGroupingFeedbackItem.typeIdentifier],
                             delegate: TabDropDelegate(newGrpId: tabGroup.id, viewModel: viewModel))
                    Separator(horizontal: true, hairline: false, rounded: true, color: BeamColor.Generic.separator)

                }
            }
            .padding(.bottom, 16)

            VStack {
                Text("Drag a tab here to exclude from a group")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .onDrop(of: [TabGroupingFeedbackItem.typeIdentifier],
                    delegate: TabDropDelegate(newGrpId: nil, viewModel: viewModel))
            .background(
                RoundedRectangle(cornerRadius: 10)
                  .strokeBorder(BeamColor.LightStoneGray.swiftUI, style: StrokeStyle(dash: [10]))
                  .background(BeamColor.Mercury.swiftUI)
              )

            HStack {
                Spacer()
                Button {
                    triggerSendFeedback(saveToURL: nil)
                } label: {
                    Text("Send Feedback")
                }.buttonStyle(.automatic)
                Button {
                    triggerSaveAndSendFeedback()
                } label: {
                    Text("Save and send Feedback")
                }.buttonStyle(.automatic)
            }.frame(height: 50)

        }
        .padding()
    }
}

struct TabGroupingFeedbackContentView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Beam")
    }
}

private struct TabGroupingFeedbackTabView: View {
    var url: URL
    var title: String
    var color: Color

    var body: some View {
        HStack {
            FaviconView(url: url)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
            Text(title)
                .lineLimit(1)
                .font(BeamFont.regular(size: 11).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
            Spacer()
        }.frame(height: 28, alignment: .center)
            .frame(maxWidth: .infinity)
            .background(
              RoundedRectangle(cornerRadius: 6)
                .foregroundColor(color)
            )
    }
}

struct TabGroupingFeedbackTabView_Previews: PreviewProvider {
    static var previews: some View {
        TabGroupingFeedbackTabView(url: URL(string: "www.google.com")!, title: "Google", color: .blue)
    }
}
