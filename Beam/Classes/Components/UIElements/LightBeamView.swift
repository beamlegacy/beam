//
//  LightBeamView.swift
//  Beam
//
//  Created by Remi Santos on 13/06/2022.
//

import SwiftUI
import BeamCore

private struct LightBeamShotView: View {

    @State private var appeared = false

    var animation: Animation {
        Animation.interpolatingSpring(stiffness: 380, damping: 50)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("beam-pewpew")
                    .resizable()
                    .frame(width: 40, height: 8)
                    .offset(x: !appeared ? -20 : proxy.size.width + 20, y: 0)
                    .animation(animation, value: appeared)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .onAppear {
            DispatchQueue.main.async {
                appeared.toggle()
            }
        }
    }
}

struct LightBeamViewTouchBarContainer: View {

    var onTap: (() -> Void)?
    @State private var shots = [UUID]()

    func triggerShot() {
        let newShot = UUID()
        shots.append(newShot)
        onTap?()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("🔫")
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .onTapGesture {
                    triggerShot()
                }
                .padding(.horizontal, 10)
            ZStack {
                ForEach(shots, id: \.self) { shot in
                    LightBeamShotView()
                        .id(shot)
                }
            }
            .offset(x: -10, y: 0)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct LightBeamView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LightBeamShotView()
                .padding(.top, 13)
                .frame(width: 400, height: 30)
            LightBeamViewTouchBarContainer()
                .frame(width: 400, height: 30)
        }
    }
}
