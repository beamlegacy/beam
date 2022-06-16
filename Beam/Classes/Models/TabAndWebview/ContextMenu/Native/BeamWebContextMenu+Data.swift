//
//  BeamWebContextMenu+Data.swift
//  Beam
//
//  Created by Adam Viaud on 16/06/2022.
//

import Foundation
import UniformTypeIdentifiers

// Adapted from: https://stackoverflow.com/questions/29644168/get-image-file-type-programmatically-in-swift
extension Data {
    private enum ImageHeaderData: UInt8 {
        case jpeg = 0xFF
        case png = 0x89
        case gif = 0x47
        case tiff_01 = 0x49
        case tiff_02 = 0x4D
        case webp = 0x52
        case heic = 0x00
    }

    var preferredFileExtension: String? {
        switch self[0] {
        case ImageHeaderData.jpeg.rawValue:
            return UTType.jpeg.preferredFilenameExtension
        case ImageHeaderData.png.rawValue:
            return UTType.png.preferredFilenameExtension
        case ImageHeaderData.gif.rawValue:
            return UTType.gif.preferredFilenameExtension
        case ImageHeaderData.tiff_01.rawValue, ImageHeaderData.tiff_02.rawValue:
            return UTType.tiff.preferredFilenameExtension
        case ImageHeaderData.webp.rawValue where count >= 12:
            guard let header = String(data: self[0...11], encoding: .ascii), header.hasPrefix("RIFF"), header.hasSuffix("WEBP")
            else {
                return nil
            }
            return UTType.webP.preferredFilenameExtension
        case ImageHeaderData.webp.rawValue where count >= 12:
            guard let header = String(data: self[8...11], encoding: .ascii), Set(["heic", "heix", "hevc", "hevx"]).contains(header)
            else {
                return nil
            }
            return UTType.heic.preferredFilenameExtension
        default:
            return nil
        }
    }
}
