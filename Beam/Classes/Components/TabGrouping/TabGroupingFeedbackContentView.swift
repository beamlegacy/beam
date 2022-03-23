//
//  TabGroupingFeedbackContentView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 15/03/2022.
//

import SwiftUI
import BeamCore

private final class TabItem: NSObject, Codable, Identifiable {
    var id = UUID().uuidString
    var tabId: UUID

    init(tabId: UUID) {
        self.tabId = tabId
    }
}

extension TabItem: NSItemProviderWriting {
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

extension TabItem: NSItemProviderReading {
    static var readableTypeIdentifiersForItemProvider: [String] {
        [Self.typeIdentifier]
    }

    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> TabItem {
        let decoder = JSONDecoder()
        return try decoder.decode(TabItem.self, from: data)
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
        guard info.hasItemsConforming(to: [TabItem.typeIdentifier]) else {
            return false
        }

        let itemProviders = info.itemProviders(for: [TabItem.typeIdentifier])
        guard let itemProvider = itemProviders.first else {
            return false
        }

        itemProvider.loadObject(ofClass: TabItem.self) { tabItem, _ in
            guard let tabItem = tabItem as? TabItem else {
                return
            }

            if let newGrpId = newGrpId {
                DispatchQueue.main.async {
                    guard let groupIdx = viewModel.remove(tabId: tabItem.tabId) else { return }
                    for group in viewModel.groups where group.id == newGrpId {
                        group.pageIDs.append(tabItem.tabId)
                        viewModel.updateCorrectedPages(with: tabItem.tabId, in: group.id)
                    }
                    viewModel.remove(group: groupIdx)
                }
            } else {
                if let newGrpHue = viewModel.getNewhueTint() {
                    DispatchQueue.main.async {
                        guard let groupIdx = viewModel.remove(tabId: tabItem.tabId) else { return }
                        let newGroup = TabClusteringGroup(pageIDs: [tabItem.tabId], hueTint: newGrpHue)
                        viewModel.groups.append(newGroup)
                        viewModel.updateCorrectedPages(with: tabItem.tabId, in: newGroup.id)
                        viewModel.remove(group: groupIdx)
                    }
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
                        ForEach(tabGroup.pageIDs, id: \.self) { tabId in
                            if let url = viewModel.urlFor(pageId: tabId),
                                let title = viewModel.titleFor(pageId: tabId) {
                                TabGroupingTabView(url: url,
                                                   title: title,
                                                   color: Color(hue: tabGroup.hueTint, saturation: 0.6, brightness: 1, opacity: 0.25))
                                    .padding(.bottom, 5)
                                    .onDrag {
                                        return NSItemProvider(object: TabItem(tabId: tabId))
                                    }
                            }
                        }
                    }.onDrop(of: [TabItem.typeIdentifier],
                             delegate: TabDropDelegate(newGrpId: tabGroup.id, viewModel: viewModel))

                    Separator(horizontal: true, hairline: false, rounded: true, color: BeamColor.Generic.separator)
                                        .padding(.vertical, 16)
                }
            }
            .padding(.bottom, 16)

            VStack {
                Text("Drag a tab here to exclude from a group")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .onDrop(of: [TabItem.typeIdentifier],
                    delegate: TabDropDelegate(newGrpId: nil, viewModel: viewModel))
            .background(
                RoundedRectangle(cornerRadius: 10)
                  .strokeBorder(BeamColor.LightStoneGray.swiftUI, style: StrokeStyle(dash: [10]))
                  .background(BeamColor.Mercury.swiftUI)
              )

            HStack {
                Spacer()
                Button {
                    let openPanel = NSOpenPanel()
                    openPanel.canChooseDirectories = true
                    openPanel.canCreateDirectories = true
                    openPanel.canChooseFiles = false
                    openPanel.showsTagField = false
                    openPanel.begin { (result) in
                        guard result == .OK, let url = openPanel.url else {
                            openPanel.close()
                            return
                        }
                        AppDelegate.main.data.clusteringManager.exportSession(sessionExporter: AppDelegate.main.data.sessionExporter, to: url, correctedPages: viewModel.correctedPages)
                        AppDelegate.main.tabGroupingFeedbackWindow?.close()
                    }
                } label: {
                    Text("Send Feedback")
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

private struct TabGroupingTabView: View {
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

struct TabGroupingTabView_Previews: PreviewProvider {
    static var previews: some View {
        TabGroupingTabView(url: URL(string: "www.google.com")!, title: "Google", color: .blue)
    }
}
