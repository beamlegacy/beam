//
//  TabGroupingTitleBarView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 01/06/2021.
//

import SwiftUI

struct TabGroupingTitleBarView: View {
    @State private var tagGroupingMethod = 0

    var body: some View {
        VStack {
            Picker("", selection: $tagGroupingMethod) {
                 Text("Gil").tag(0)
                 Text("Julien").tag(1)
                 Text("Paul").tag(2)
             }
             .pickerStyle(SegmentedPickerStyle())
         }
    }
}

struct TabGroupingTitleBarView_Previews: PreviewProvider {
    static var previews: some View {
        TabGroupingTitleBarView()
    }
}
