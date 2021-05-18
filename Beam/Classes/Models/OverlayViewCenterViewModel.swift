//
//  OverlayViewCenterViewModel.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 13/05/2021.
//

import Foundation

class OverlayViewCenterViewModel: ObservableObject {

    @Published var show = false
    @Published var credentialsToast: CredentialsConfirmationToast? {
        didSet {
            show.toggle()
        }
    }
}
