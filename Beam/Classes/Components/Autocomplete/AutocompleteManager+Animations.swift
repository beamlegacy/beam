//
//  AutocompleteManager+Animations.swift
//  Beam
//
//  Created by Remi Santos on 17/03/2022.
//

import Foundation
import SwiftUI

extension AutocompleteManager {

    /// Moves omnibox down and up to highlight that it was already focused
    func shakeOmniBox() {
        let animationIn = BeamAnimation.easeIn(duration: 0.08)
        let animationOut = BeamAnimation.defaultiOSEasing(duration: 0.3)
        withAnimation(animationIn) {
            animateInputingCharacter = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(80)) { [weak self] in
            withAnimation(animationOut) {
                self?.animateInputingCharacter = false
            }
        }
    }

    /// Moves omnibox down and up and switch search to the corresponding mode
    func animateToMode(_ mode: AutocompleteManager.Mode) {
        let animationIn = BeamAnimation.spring(stiffness: 420, damping: 24)
        let animationOut = BeamAnimation.spring(stiffness: 420, damping: 34)
        withAnimation(animationIn) {
            self.isPreparingForAnimatingToMode = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak self] in
            self?.animatingToMode = mode
            withAnimation(BeamAnimation.easeInOut(duration: 0.05)) {
                self?.setQuery("", updateAutocompleteResults: false)
                self?.setAutocompleteResults([], animated: false)
            }
            withAnimation(animationOut) {
                self?.isPreparingForAnimatingToMode = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) { [weak self] in
                self?.mode = mode
                self?.animatingToMode = nil
            }
        }
    }
}
