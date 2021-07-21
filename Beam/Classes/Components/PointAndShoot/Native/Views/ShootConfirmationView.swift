//
//  ShootConfirmationView.swift
//  Beam
//
//  Created by Stef Kors on 13/07/2021.
//

import Foundation
import SwiftUI
import BeamCore

struct ShootConfirmationView: View {
    @ObservedObject var pns: PointAndShoot

    var body: some View {
        if let group = pns.shootConfirmationGroup {
            ShootAbsolutePositioning(pns: pns, webPositions: pns.webPositions, group: group, contentSize: ShootCardConfirmationView.size) {
                ShootCardConfirmationView(group: group)
            }
        }
    }
}
