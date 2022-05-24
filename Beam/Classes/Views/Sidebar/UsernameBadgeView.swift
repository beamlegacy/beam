//
//  UsernameBadgeView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 18/05/2022.
//

import SwiftUI

struct UsernameBadgeView: View {

    let username: String

    var body: some View {
        ZStack {
            Circle()
                .foregroundColor(BeamColor.Beam.swiftUI)
            Text(firstCharacter)
                .font(BeamFont.bold(size: 9).swiftUI)
                .foregroundColor(.white)
        }.frame(width: 18, height: 18)
    }

    private var firstCharacter: String {
        username.prefix(1).uppercased()
    }
}

struct UsernameBadgeView_Previews: PreviewProvider {
    static var previews: some View {
        UsernameBadgeView(username: "Ludovic")
    }
}
