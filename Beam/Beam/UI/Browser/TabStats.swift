//
//  TabStats.swift
//  Beam
//
//  Created by Sebastien Metrot on 24/11/2020.
//

import Foundation
import SwiftUI

struct TabStats: View {
    var score: Score

    var body: some View {
        VStack {
            Text("Tab stats").bold()
            VStack {
//                Text("Score \(tab.score?.score)")
                Text("readingTime: \(score.readingTime)")
                Text("textSelections: \(score.textSelections)")
                Text("scrollRatioX: \(score.scrollRatioX)")
                Text("scrollRatioY: \(score.scrollRatioY)")
                Text("openIndex: \(score.openIndex)")
                Text("outbounds: \(score.outbounds)")
                Text("textAmount: \(score.textAmount)")
                Text("area: \(score.area)")
                Text("inbounds: \(score.inbounds)")
                Text("videoTotalDuration: \(score.videoTotalDuration)")
//                Text("videoReadingDuration: \(score.videoReadingDuration)")
            }
        }.background(
            RoundedRectangle(cornerRadius: 7)
                .foregroundColor(Color("ToolbarButtonBackgroundOnColor"))
        )
    }
}
