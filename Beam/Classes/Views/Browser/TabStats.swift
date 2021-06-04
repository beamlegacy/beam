//
//  TabStats.swift
//  Beam
//
//  Created by Sebastien Metrot on 24/11/2020.
//

import Foundation
import SwiftUI
import BeamCore

struct TabStats: View {
    var score: Score
    @State private var position = CGSize()
    @State private var initialPosition = CGSize()
    @State private var dragging = false
    func actualPosition(_ containerSize: CGSize, _ position: CGSize) -> CGSize {
        let width = max(0, min(containerSize.width - 100, position.width))
        let height = max(0, min(containerSize.height - 100, position.height))
        return CGSize(width: width, height: height)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Text("Tab stats").bold()
                VStack {
    //                Text("Score \(tab.score?.score)")
                    Text("readingTime: \(score.readingTimeToLastEvent)")
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
                }.padding()
            }.background(
                RoundedRectangle(cornerRadius: 7)
                    .foregroundColor(Color.gray.opacity(0.85))
            ).foregroundColor(Color.white)
            .frame(alignment: .topLeading)
            .position(x: 100, y: 100)
            .offset(x: actualPosition(geometry.size, position).width, y: actualPosition(geometry.size, position).height)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if !dragging {
                            initialPosition = actualPosition(geometry.size, position)
                            dragging = true
                        }

                        var width = initialPosition.width + gesture.translation.width
                        var height = initialPosition.height + gesture.translation.height

                        width = max(0, min(geometry.size.width - 100, width))
                        height = max(0, min(geometry.size.height - 100, height))

                        self.position = actualPosition(geometry.size, CGSize(width: width, height: height))
                    }

                    .onEnded { _ in
                        dragging = false
                    }
            )
        }
    }
}
