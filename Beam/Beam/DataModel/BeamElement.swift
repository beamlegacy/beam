//
//  Elements.swift
//  Beam
//
//  Created by Sebastien Metrot on 27/11/2020.
//

import Foundation

// Editable Text Data:
public class BeamElement: Codable, Identifiable, Hashable {
    public var id = UUID()
    var text = ""
    var open = true
    var children = [BeamElement]()
    var readOnly = false
    var ast: Parser.Node?
    var score: Float = 0

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case open
        case children
        case readOnly
        case ast
    }

    init() {
    }

    init(_ text: String) {
        self.text = text
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        open = try container.decode(Bool.self, forKey: .open)
        readOnly = try container.decode(Bool.self, forKey: .readOnly)
        if container.contains(.children) {
            children = try container.decode([BeamElement].self, forKey: .children)
            for child in children {
                child.parent = self
            }
        }

        if container.contains(.ast) {
            ast = try container.decode(Parser.Node.self, forKey: .ast)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(open, forKey: .open)
        try container.encode(readOnly, forKey: .readOnly)
        if !children.isEmpty {
            try container.encode(children, forKey: .children)
        }
        if let ast = ast {
            try container.encode(ast, forKey: .ast)
        }
    }

    func removeChild(_ child: BeamElement) {
        guard let index = children.firstIndex(where: { (e) -> Bool in
            e === child
        }) else { return }
        children.remove(at: index)
        child.parent = nil
    }

    func indexOfChild(_ child: BeamElement) -> Int? {
        return children.firstIndex(where: { (e) -> Bool in
            e === child
        })
    }

    func addChild(_ child: BeamElement) {
        insert(child, after: children.last) // append
    }

    func insert(_ child: BeamElement, after: BeamElement?) {
        if let oldParent = child.parent {
            oldParent.removeChild(child)
        }

        child.parent = self
        guard let after = after, let index = indexOfChild(after) else {
            children.insert(child, at: 0)
            return
        }

        children.insert(child, at: index + 1)
    }

    var parent: BeamElement?

    public static func == (lhs: BeamElement, rhs: BeamElement) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        return hasher.combine(id)
    }
}
