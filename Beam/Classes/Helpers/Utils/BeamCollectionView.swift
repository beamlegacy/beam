//
//  BEAMCollectionView.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 08/02/2021.
//

import Foundation

class BeamCollectionView: NSCollectionView {

    override func becomeFirstResponder() -> Bool {
        return false
    }

    override var acceptsFirstResponder: Bool {
        return false
    }

}
