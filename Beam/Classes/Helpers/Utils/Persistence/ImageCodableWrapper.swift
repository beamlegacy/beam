//
//  ImageCodableWrapper.swift
//  Beam
//
//  Created by Remi Santos on 21/10/2021.
//

import Foundation

/// Wrapper to have an Image conform to Codable
struct ImageCodableWrapper: Codable {
    enum ImageCodableWrapperError: Error, Equatable {
        case decodingFailed
        case encodingFailed
    }

    let image: NSImage

    private enum CodingKeys: String, CodingKey {
        case image
    }

    init(image: NSImage) {
        self.image = image
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try container.decode(Data.self, forKey: CodingKeys.image)
        guard let image = NSImage(data: data) else {
            throw ImageCodableWrapperError.decodingFailed
        }
        self.image = image
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        guard let data = image.tiffRepresentation else {
            throw ImageCodableWrapperError.encodingFailed
        }
        try container.encode(data, forKey: CodingKeys.image)
    }
}
