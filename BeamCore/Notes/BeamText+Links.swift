//
//  BeamText+Links.swift
//  Beam
//
//  Created by Sebastien Metrot on 01/04/2021.
//

import Foundation

public extension BeamText {
    var linkCharacterSet: CharacterSet {
        // only refuse new line characters
        CharacterSet.newlines.inverted
    }

    var internalLinks: [Range] {
        var links = [Range]()
        for range in ranges {
            for attribute in range.attributes {
                switch attribute {
                case .internalLink:
                    links.append(range)
                default:
                    break
                }
            }
        }

        return links
    }

    var linkRanges: [Range] {
        ranges.flatMap { range in
          range.attributes.compactMap { attribute -> Range? in // might not need -> Range?
            if case .link = attribute { return range }
            return nil
          }
        }

    }

    var links: [String] {
        var links = [String]()
        for range in ranges {
            for attribute in range.attributes {
                switch attribute {
                case let .link(link):
                    links.append(link)
                default:
                    break
                }
            }
        }

        return links
    }

    static func removeLinks(from attributes: [Attribute]) -> [Attribute] {
        return attributes.compactMap({ $0.isLink ? nil : $0 })
    }

    static func removeInternalLinks(from attributes: [Attribute]) -> [Attribute] {
        return attributes.compactMap({ $0.isInternalLink ? nil : $0 })
    }

    mutating func replaceInternalLink(_ internalLink: BeamText.Range, withText: String) {
        let rangeStart = internalLink.position
        self.removeSubrangeSilent(rangeStart..<internalLink.end)
        self.insert(withText, at: rangeStart, withAttributes: [.internalLink(withText)])
    }

    func hasLinkToNote(named noteTitle: String) -> Bool {
        let titleLowercased = noteTitle.lowercased()
        return internalLinks.contains(where: { range -> Bool in
            range.string.lowercased() == titleLowercased
        })
    }

    func hasReferenceToNote(titled noteTitle: String) -> Bool {
        textWithInternalLinksErased.lowercased().contains(noteTitle.lowercased())
    }

    var textWithInternalLinksErased: String {
        ranges.compactMap({ range -> Range? in
            for attribute in range.attributes {
                switch attribute {
                case .internalLink:
                    return nil
                default:
                    break
                }
            }
            return range
        }).reduce(String()) { (string, range) -> String in
            string + range.string
        }
    }
}
