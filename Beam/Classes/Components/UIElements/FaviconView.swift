//
//  FaviconView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 01/06/2021.
//

import SwiftUI
import Combine

struct FaviconView: View {
    let url: URL?

    @State private var faviconState: FaviconState = .loading

    enum FaviconState {
        case loading
        case generic
        case available(NSImage)
    }

    var body: some View {
        VStack {
            switch faviconState {
            case .available(let favicon):
                Image(nsImage: favicon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            case .generic:
                Icon(name: "field-web", color: BeamColor.Niobium.swiftUI)
                    .padding(.trailing, 4)
            default:
                Color.clear
                    .frame(width: 16, height: 16)
            }
        }.onReceive(Just(url), perform: { _ in
            guard let url = url else {
                self.faviconState = .generic
                return
            }
            FaviconProvider.shared.favicon(fromURL: url) { favicon in
                if let image = favicon?.image {
                    self.faviconState = .available(image)
                } else {
                    self.faviconState = .generic
                }
            }
        })
    }
}

struct FaviconView_Previews: PreviewProvider {
    static var previews: some View {
        FaviconView(url: URL(string: "www.beamapp.co")!)
    }
}
