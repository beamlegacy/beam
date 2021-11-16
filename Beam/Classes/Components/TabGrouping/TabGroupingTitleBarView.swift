//
//  TabGroupingTitleBarView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 01/06/2021.
//

import SwiftUI
import BeamCore

struct TabGroupingTitleBarView: View {
    @ObservedObject var clusteringManager: ClusteringManager

    var body: some View {
        VStack {
            Picker("", selection: $clusteringManager.selectedTabGroupingCandidate) {
                Text("Candidate 1").tag(1)
                Text("Candidate 2").tag(2)
                Text("Candidate 3").tag(3)
            }.labelsHidden()
            .pickerStyle(SegmentedPickerStyle())
            .disabled(clusteringManager.isClustering)
        }.padding()
    }
}

struct TabGroupingTitleBarView_Previews: PreviewProvider {
    static var previews: some View {
        TabGroupingTitleBarView(clusteringManager: ClusteringManager(ranker: SessionLinkRanker(), candidate: 2, navigation: 0.5, text: 0.9, entities: 0.4, sessionId: UUID(), activeSources: ActiveSources()))
    }
}
