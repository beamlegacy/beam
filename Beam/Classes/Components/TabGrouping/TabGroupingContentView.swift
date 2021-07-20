//
//  TabGroupingContentView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 23/05/2021.
//

import Foundation
import SwiftUI
import Fakery
import Clustering

struct TabGroupingContentView: View {
    @ObservedObject var clusteringManager: ClusteringManager

    var body: some View {
        ClusterSlidersView(clusteringManager: clusteringManager,
                           weightNavigation: clusteringManager.weightNavigation,
                           weightText: clusteringManager.weightText,
                           weightEntities: clusteringManager.weightEntities)
        ScrollView {
            VStack(alignment: .center) {
                ZStack {
                    if clusteringManager.clusteredTabs.flatMap { $0 }.isEmpty {
                        ClusterLoadingView(isLoading: false)
                    }
                    if clusteringManager.isClustering {
                        ClusterLoadingView(isLoading: true)
                    }
                }
                ClusterContentView(clusteringManager: clusteringManager)
            }.padding(.all, 20)
        }.frame(maxWidth: .infinity, alignment: .center)
        .background(BeamColor.Generic.background.swiftUI)
    }
}

struct TabGroupingContentView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Beam")
        //        TabGroupingContentView(clusteringManager: clusteringManager)
    }
}

struct ClusterLoadingView: View {
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .center) {
            Text(isLoading ? "Waiting for clustering result..." : "Waiting for tabs...")
                .padding()
            ProgressIndicator(isAnimated: true, controlSize: .small)
                .padding()
        }
    }
}

struct ClusterContentView: View {
    @ObservedObject var clusteringManager: ClusteringManager

    var body: some View {
        ForEach(0..<clusteringManager.clusteredTabs.count, id: \.self) { clusterGroupIdx in
            let clusterGroup = clusteringManager.clusteredTabs[clusterGroupIdx]
            VStack(alignment: .leading) {
                ForEach(0..<clusterGroup.count, id: \.self) { clusteredTabIdx in
                    if let tab = clusterGroup[clusteredTabIdx] {
                        TabView(tabInfo: tab)
                            .padding(.bottom, clusteredTabIdx == clusterGroup.count - 1 ? 0 : 10)
                    }
                }
            }
            if clusterGroupIdx != clusteringManager.clusteredTabs.count - 1 {
                Separator(horizontal: true, hairline: false)
                    .padding([.top, .bottom], 21.5)
            }
        }
    }
}

struct TabView: View {
    var tabInfo: TabInformation

    var body: some View {
        HStack {
            FaviconView(url: tabInfo.url)
                .padding(.trailing, 4)
            Text(tabInfo.document.title)
                .font(BeamFont.medium(size: 11).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
            Spacer()
        }
    }
}

struct TabView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Beam")
        //        TabView(tabName: "Donald Trump - Wikipedia")
    }
}

struct ClusterSlidersView: View {
    @ObservedObject var clusteringManager: ClusteringManager

    @State var weightNavigation: Double
    @State var weightText: Double
    @State var weightEntities: Double

    var body: some View {
        HStack {
            VStack {
                Text("Navigation \(String(format: "%.1f", weightNavigation))")
                Slider(value: $weightNavigation,
                       in: 0.0...1.0,
                       step: 0.1,
                       onEditingChanged: { began in
                        if !began {
                            clusteringManager.weightNavigation = weightNavigation
                        }
                       },
                       minimumValueLabel: Text("0"),
                       maximumValueLabel: Text("1"), label: {})
                    .labelsHidden()
                    .disabled(clusteringManager.isClustering)
            }
            VStack {
                Text("Text \(String(format: "%.1f", weightText))")
                Slider(value: $weightText,
                       in: 0.0...1.0,
                       step: 0.1,
                       onEditingChanged: { began in
                        if !began {
                            clusteringManager.weightText = weightText
                        }
                       },
                       minimumValueLabel: Text("0"),
                       maximumValueLabel: Text("1"), label: {})
                    .labelsHidden()
                    .disabled(clusteringManager.isClustering)
            }
            VStack {
                Text("Entities \(String(format: "%.1f", weightEntities))")
                Slider(value: $weightEntities,
                       in: 0.0...1.0,
                       step: 0.1,
                       onEditingChanged: { began in
                        if !began {
                            clusteringManager.weightEntities = weightEntities
                        }
                       },
                       minimumValueLabel: Text("0"),
                       maximumValueLabel: Text("1"), label: {})
                    .labelsHidden()
                    .disabled(clusteringManager.isClustering)
            }
        }.padding()
    }
}
