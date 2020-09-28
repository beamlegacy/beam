//
//  BeamNote.swift
//  testWkWebViewSwiftUI
//
//  Created by Sebastien Metrot on 18/09/2020.
//

import Foundation
import AppKit

/*
 
 Beam contains Notes
 A Note contains a tree of blocks. A Note has a title that has to be unique.
 A Block contains a list of text blocks. An element can be of different type (Bullet point, Numbered bullet point, Quote, Code, Header (1-6?)...). A Block can be referenced by any note
 A text block contains text. It contains the format of the text (Bold, Italic, Underline). There are different text block types to represent different attributes (Code, URL, Link...)
 */

protocol BeamObject: Codable {
    var id: BID { get set }
}

struct BeamNotes {
    public var notes: [BID:BeamNote] = [:]
    public var objects: [BID:BeamObject] = [:]
    public var notesByName: [String:BID] = [:]
}

protocol BeamBlock: BeamObject {
    var elements: [BID] { get set }
    var outLinks: [String] { get }

//    mutating func addElement(_ element: BeamElement)
}

struct BeamNote: BeamBlock {
    var id: BID = BID()
    public var title: String

    var elements: [BID] = []
    var outLinks: [String] = []
}

protocol BeamTextBlock: BeamObject {
    var text: String { get set }
}

struct TextFormat: OptionSet, Codable {
    let rawValue: Int8

    static let regular      = TextFormat([])
    static let bold         = TextFormat(rawValue: 1 << 0)
    static let italic       = TextFormat(rawValue: 1 << 1)
    static let underline    = TextFormat(rawValue: 1 << 2)
}

struct BeamText: BeamTextBlock {
    var id: BID = BID()
    var format: TextFormat = .regular
    var text: String = ""
}

struct BeamTextURL: BeamTextBlock {
    var id: BID = BID()
    var text: String = ""
}

struct BeamTextCode: BeamTextBlock {
    var id: BID = BID()
    var text: String = ""
}

struct BeamTextLink: BeamTextBlock {
    var id: BID = BID()
    var text: String = ""
    var target: BID
}
