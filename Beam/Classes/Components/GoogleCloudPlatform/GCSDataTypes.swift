//
//  GCSDataTypes.swift
//  Beam
//
//  Created by Julien Plu on 09/03/2022.
//

import Foundation

public struct GCSUploadPayload: Codable, CustomStringConvertible {
    var kind = ""
    var id = ""
    var selfLink = ""
    var mediaLink = ""
    var name = ""
    var bucket = ""
    var generation = ""
    var metageneration = ""
    var contentType = ""
    var storageClass = ""
    var size = ""
    var md5Hash = ""
    var crc32c = ""
    var etag = ""
    var timeCreated = ""
    var updated = ""
    var timeStorageClassUpdated = ""

    public var description: String {
        return """
        {
            "kind": \(kind),
            "id": \(id),
            "selfLink": \(selfLink),
            "mediaLink": \(mediaLink),
            "name": \(name),
            "bucket": \(bucket),
            "generation": \(generation),
            "metageneration": \(metageneration),
            "contentType": \(contentType),
            "storageClass": \(storageClass),
            "size": \(size),
            "md5hash": \(md5Hash),
            "crc32c": \(crc32c),
            "etag": \(etag),
            "timeCreated": \(timeCreated),
            "updated": \(updated),
            "timeStorageClassUpdated": \(timeStorageClassUpdated)
        }
        """
    }
}

public struct GCSUploadError: Codable, CustomStringConvertible {
    struct Err: Codable {
        var errors: [ErrInfo] = []
        var code = 0
        var message = ""
    }

    struct ErrInfo: Codable {
        var message = ""
        var domain = ""
        var reason = ""
        var locationType = ""
        var location = ""
    }

    var error = Err()

    public var description: String {
        return """
        {
            "error": {
                errors : \(error.errors),
                code: \(error.code),
                message: \(error.message)
            }
        }
        """
    }
}
