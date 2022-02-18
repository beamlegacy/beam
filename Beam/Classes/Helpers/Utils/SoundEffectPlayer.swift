//
//  SoundEffectPlayer.swift
//  Beam
//
//  Created by Remi Santos on 18/02/2022.
//

import Foundation
import AVFoundation

class SoundEffectPlayer {

    static let shared = SoundEffectPlayer()

    private var soundIDs = [SoundEffectPlayer.Sounds: SystemSoundID]()

    func playSound(_ sound: SoundEffectPlayer.Sounds) {
        var soundID = soundIDs[sound]
        if soundID == nil, let soundURL = Bundle.main.url(forResource: sound.fileName, withExtension: sound.fileExtension) {
            var sID: SystemSoundID = 0
            AudioServicesCreateSystemSoundID(soundURL as CFURL, &sID)
            soundID = sID
            soundIDs[sound] = sID
        }

        guard let soundID = soundID else { return }
        AudioServicesPlaySystemSound(soundID)
    }
}

extension SoundEffectPlayer {
    enum Sounds: String {
        case pointAndShootCollect = "collect"
        case pointAndShootConfirm = "confirm"
        case beginRecord = "begin_record"

        var fileName: String {
            rawValue
        }
        var fileExtension: String {
            switch self {
            case .pointAndShootConfirm:
                return "aiff"
            case .pointAndShootCollect:
                return "aif"
            default:
                return "caf"
            }
        }
    }
}
