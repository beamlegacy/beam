//
//  SignPost.swift
//  BeamCore
//
//  Created by Sebastien Metrot on 16/12/2021.
//

import Foundation
import os.signpost
@_exported import os
@_exported import os.log
import _SwiftOSOverlayShims

public struct SignPost {
    var log: OSLog
    public init(_ category: String, subsystem: String = "co.beamapp.beam") {
        log = OSLog(subsystem: subsystem, category: category)
    }

    public func createId(object: AnyObject? = nil) -> SignPostId {
        SignPostId(log, object: object)
    }

    public func begin(_ name: StaticString, id: SignPostId? = nil) {
        if let id = id {
            os_signpost(.begin, log: log, name: name, signpostID: id.id)
        } else {
            os_signpost(.begin, log: log, name: name)
        }
    }

    public func end(_ name: StaticString, id: SignPostId? = nil) {
        if let id = id {
            os_signpost(.end, log: log, name: name, signpostID: id.id)
        } else {
            os_signpost(.end, log: log, name: name)
        }
    }

    public func event(_ name: StaticString, id: SignPostId? = nil) {
        if let id = id {
            os_signpost(.event, log: log, name: name, signpostID: id.id)
        } else {
            os_signpost(.event, log: log, name: name)
        }
    }

    // With parameters:
    public func begin(_ name: StaticString, id: SignPostId? = nil, _ format: StaticString) {
        if let id = id {
            os_signpost(.begin, log: log, name: name, signpostID: id.id, format)
        } else {
            os_signpost(.begin, log: log, name: name, format)
        }
    }

    public func end(_ name: StaticString, id: SignPostId? = nil, _ format: StaticString) {
        if let id = id {
            os_signpost(.end, log: log, name: name, signpostID: id.id, format)
        } else {
            os_signpost(.end, log: log, name: name, format)
        }
    }

    public func event(_ name: StaticString, id: SignPostId? = nil, _ format: StaticString) {
        if let id = id {
            os_signpost(.event, log: log, name: name, signpostID: id.id, format)
        } else {
            os_signpost(.event, log: log, name: name, format)
        }
    }
}

public struct SignPostId {
    public var id: OSSignpostID
    public var log: OSLog

    init(_ log: OSLog, object: AnyObject?) {
        self.log = log
        if let object = object {
            id = OSSignpostID(log: log, object: object)
        } else {
            id = OSSignpostID(log: log)
        }
    }

    public func begin(_ name: StaticString) {
        os_signpost(.begin, log: log, name: name, signpostID: id)
    }

    public func end(_ name: StaticString) {
        os_signpost(.end, log: log, name: name, signpostID: id)
    }

    public func event(_ name: StaticString) {
        os_signpost(.event, log: log, name: name, signpostID: id)
    }

    public func begin(_ name: StaticString, _ format: StaticString) {
        os_signpost(.begin, log: log, name: name, signpostID: id, format)
    }

    public func end(_ name: StaticString, _ format: StaticString) {
        os_signpost(.end, log: log, name: name, signpostID: id, format)
    }

    public func event(_ name: StaticString, _ format: StaticString) {
        os_signpost(.event, log: log, name: name, signpostID: id, format)
    }
}
