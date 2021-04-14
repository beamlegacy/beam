//
//  BeamElementTextStatsTests.swift
//  BeamCoreTests
//
//  Created by Remi Santos on 13/04/2021.
//

import Foundation
import XCTest
import Quick
import Nimble

@testable import BeamCore

class BeamElementTextStatsTests: QuickSpec {

    override func spec() {
        describe("words count") {

            context("without children") {
                it("count words correctly on init") {
                    let element = BeamElement("This has four words.")
                    expect(element.textStats.wordsCount) == 4
                }

                it("updates when editing") {
                    let element = BeamElement("This has four words.")
                    expect(element.textStats.wordsCount) == 4
                    element.text = BeamText(text: "This has six words now right?")
                    expect(element.textStats.wordsCount) == 6
                }
            }

            context("with children") {

                it("when insert/remove children") {
                    let children = ["One", "Two Words", "Three Words Here"].map { BeamElement($0) }
                    let parent = BeamElement("Parent")
                    children.forEach { parent.addChild($0) }
                    expect(parent.textStats.wordsCount) == 7
                    parent.removeChild(children[2])
                    expect(parent.textStats.wordsCount) == 4
                }

                it("when updating a child") {
                    let children = ["One", "Two Words", "Three Words Here"].map { BeamElement($0) }
                    let parent = BeamElement("Parent")
                    children.forEach { parent.addChild($0) }
                    expect(parent.textStats.wordsCount) == 7
                    let three = children[2]
                    three.text = BeamText(text: "Four words here now")
                    expect(parent.textStats.wordsCount) == 8
                }
            }
        }
    }

}
