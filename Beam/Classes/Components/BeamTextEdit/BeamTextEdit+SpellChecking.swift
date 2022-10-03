//
//  BeamTextEdit+SpellChecking.swift
//  Beam
//
//  Created by Frank Lefebvre on 21/09/2022.
//

import Cocoa

extension BeamTextEdit {
    @IBAction func toggleContinuousSpellChecking(_ sender: Any?) {
        let enable = Persistence.SpellChecking.enable == false
        Persistence.SpellChecking.enable = enable
    }
}
