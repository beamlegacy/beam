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
    var tabId: UUID

    init(tabId: UUID) {
        self.tabId = tabId
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
                    guard let groupIdx = viewModel.remove(tabId: tabItem.tabId) else { return }
                    for group in viewModel.groups where group.id == newGrpId {
                        var newPageIDs = group.pageIds
                        newPageIDs.append(tabItem.tabId)
                        group.updatePageIds(newPageIDs)
                        viewModel.updateCorrectedPages(with: tabItem.tabId, in: group.id)
                    }
                    viewModel.remove(group: groupIdx)
                }
            } else {
                DispatchQueue.main.async {
                    guard let groupIdx = viewModel.remove(tabId: tabItem.tabId) else { return }
                    let newGroup = TabGroup(pageIds: [tabItem.tabId])
                    newGroup.changeColor(viewModel.getNewColor())
                    viewModel.groups.append(newGroup)
                    viewModel.updateCorrectedPages(with: tabItem.tabId, in: newGroup.id)
                    viewModel.remove(group: groupIdx)
                }
            }
        }
        return true
    }
}

struct TabGroupingFeedbackContentView: View {
    @ObservedObject var viewModel: TabGroupingFeedbackViewModel

    var body: some View {
        VStack {
            Text("Please, re-arrange the groups in a way that makes sense to you:")
                .padding(.bottom, 34)
            Spacer()

            ScrollView {
                ForEach(viewModel.groups) { tabGroup in
                    VStack {
                        ForEach(tabGroup.pageIds, id: \.self) { tabId in
                            if let url = viewModel.urlFor(pageId: tabId),
                               let title = viewModel.titleFor(pageId: tabId) {
                                TabGroupingFeedbackTabView(url: url,
                                                           title: title,
                                                           color: (tabGroup.color?.mainColor?.swiftUI ?? Color.red).opacity(0.25))
                                .onDrag {
                                    return NSItemProvider(object: TabGroupingFeedbackItem(tabId: tabId))
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
                    BeamData.shared.clusteringManager.exportSession(sessionExporter: BeamData.shared.sessionExporter, to: nil, correctedPages: viewModel.correctedPages)
                    AppDelegate.main.tabGroupingFeedbackWindow?.close()
                } label: {
                    Text("Send Feedback")
                }.buttonStyle(.automatic)
                Button {
                    let savePanel = NSSavePanel()
                    savePanel.canCreateDirectories = true
                    savePanel.showsTagField = false
                    savePanel.begin { (result) in
                        guard result == .OK, let url = savePanel.url else {
                            savePanel.close()
                            return
                        }
                        BeamData.shared.clusteringManager.exportSession(sessionExporter: BeamData.shared.sessionExporter, to: url, correctedPages: viewModel.correctedPages)
                        AppDelegate.main.tabGroupingFeedbackWindow?.close()
                    }
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
