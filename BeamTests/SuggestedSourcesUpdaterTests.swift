import Nimble
import XCTest
import Foundation
@testable import Beam
@testable import BeamCore

class SuggestedNoteSourceUpdaterTests: XCTestCase {
    private var updater: SuggestedNoteSourceUpdater!
    private var pageIDs: [UUID] = []

    override func setUp() {
        super.setUp()
        updater = SuggestedNoteSourceUpdater(sessionId: UUID())
        for _ in 0...6 {
            pageIDs.append(UUID())
        }
    }

    func testNoteToGroup() throws {
        var noteGroups: [[UUID]] = [[], []]
        for i in 0...5 {
            noteGroups[i % 2].append(UUID())
        }
        let noteToGroupDict = updater.noteToGroup(noteGroups: noteGroups)
        for group in noteGroups.enumerated() {
            for id in group.element {
                expect(noteToGroupDict[id]) == group.offset
            }
        }
    }

    func testGroupFromPage() throws {
        let urlGroups = [[self.pageIDs[0], self.pageIDs[1], self.pageIDs[2]], [self.pageIDs[3], self.pageIDs[4], self.pageIDs[5]], [self.pageIDs[6]]]
        expect(self.updater.groupFromPage(pageId: self.pageIDs[3], urlGroups: urlGroups)) == [self.pageIDs[3], self.pageIDs[4], self.pageIDs[5]]
        expect(self.updater.groupFromPage(pageId: self.pageIDs[6], urlGroups: urlGroups)) == [self.pageIDs[6]]
    }

    func testAllSourcesForNote() throws {
        let noteId1 = UUID()
        let noteId2 = UUID()
        let noteId3 = UUID()
        let activeSources: [UUID: [UUID]] = [noteId1: [self.pageIDs[6]], noteId3: [self.pageIDs[1], self.pageIDs[6]]]
        let allSources = updater.allSourcesPerNote(urlGroups: [[self.pageIDs[0], self.pageIDs[1]], [self.pageIDs[2], self.pageIDs[3], self.pageIDs[4]], [self.pageIDs[5], self.pageIDs[6]]], noteGroups: [[noteId1], [noteId2], []], activeSources: activeSources)
        expect(allSources[noteId1]) == Set([self.pageIDs[0], self.pageIDs[1], self.pageIDs[5]])
        expect(allSources[noteId2]) == Set([self.pageIDs[2], self.pageIDs[3], self.pageIDs[4]])
        expect(allSources[noteId3]) == Set([self.pageIDs[0], self.pageIDs[5]])
    }
    
    func testCreateUpdateInstructionsWithoutActiveSources() throws {
        let noteId1 = UUID()
        let noteId2 = UUID()
        let noteId3 = UUID()
        updater.oldAllSources = [noteId1: Set([self.pageIDs[0], self.pageIDs[1], self.pageIDs[2]]),
                                noteId2: Set([self.pageIDs[0], self.pageIDs[1], self.pageIDs[2]]),
                                noteId3: Set([self.pageIDs[6]])]

        if let updateInstructions = updater.createUpdateInstructions(urlGroups: [[self.pageIDs[0], self.pageIDs[1]], [self.pageIDs[2], self.pageIDs[3], self.pageIDs[4], self.pageIDs[5]], [self.pageIDs[6]]], noteGroups: [[noteId1], [noteId2], [noteId3]], activeSources: [UUID: [UUID]]()) {
            expect(updateInstructions.sourcesToAdd[noteId1]).to(beNil())
            expect(Set(updateInstructions.sourcesToAdd[noteId2] ?? [])) == Set([self.pageIDs[3], self.pageIDs[4], self.pageIDs[5]])
            expect(updateInstructions.sourcesToAdd[noteId3]).to(beNil())
            expect(Set(updateInstructions.sourcesToRemove[noteId1] ?? [])) == Set([self.pageIDs[2]])
            expect(Set(updateInstructions.sourcesToRemove[noteId2] ?? [])) == Set([self.pageIDs[0], self.pageIDs[1]])
            expect(updateInstructions.sourcesToRemove[noteId3]).to(beNil())
        } else { XCTFail("createUpdateInstructions doesn't reply")}
    }

    func testCreateUpdateInstructionsWithActiceSources() throws {
        let noteId1 = UUID()
        let noteId2 = UUID()
        let noteId3 = UUID()
        updater.oldAllSources = [noteId1: Set([self.pageIDs[0], self.pageIDs[1], self.pageIDs[2]]),
                                 noteId2: Set([self.pageIDs[3], self.pageIDs[4], self.pageIDs[5]]),
                                 noteId3: Set([self.pageIDs[2], self.pageIDs[6]])]
        let activeSources: [UUID: [UUID]] = [noteId1: [self.pageIDs[6]], noteId3: [self.pageIDs[1], self.pageIDs[6]]]

        if let updateInstructions = updater.createUpdateInstructions(urlGroups: [[self.pageIDs[0], self.pageIDs[1]], [self.pageIDs[2], self.pageIDs[3], self.pageIDs[4]], [self.pageIDs[5], self.pageIDs[6]]], noteGroups: [[noteId1], [noteId2], [noteId3]], activeSources: activeSources) {
            expect(updateInstructions.sourcesToAdd[noteId1]) == [self.pageIDs[5]]
            expect(updateInstructions.sourcesToAdd[noteId2]) == [self.pageIDs[2]]
            expect(Set(updateInstructions.sourcesToAdd[noteId3] ?? [])) == Set([self.pageIDs[0], self.pageIDs[5]])
            expect(updateInstructions.sourcesToRemove[noteId1]) == [self.pageIDs[2]]
            expect(updateInstructions.sourcesToRemove[noteId2]) == [self.pageIDs[5]]
            expect(updateInstructions.sourcesToRemove[noteId3]) == Set([self.pageIDs[2], self.pageIDs[6]])
        } else { fail("sourcesToAdd and sourcesToRemove not created") }
    }
    
    func testCreateUpdateInstreuctionsWithActiveSourcesAndNoNote() throws {
        let noteId1 = UUID()
        let noteId2 = UUID()
        let noteId3 = UUID()
        updater.oldAllSources = [noteId1: Set([self.pageIDs[0], self.pageIDs[1], self.pageIDs[2]]),
                                 noteId3: Set([self.pageIDs[2], self.pageIDs[6]])]
        let activeSources: [UUID: [UUID]] = [noteId2: [self.pageIDs[3]]]
        if let updateInstructions = updater.createUpdateInstructions(urlGroups: [[self.pageIDs[0], self.pageIDs[1]], [self.pageIDs[2], self.pageIDs[3], self.pageIDs[4]], [self.pageIDs[5], self.pageIDs[6]]], noteGroups: [[noteId1], [], [noteId3]], activeSources: activeSources) {
            expect(updateInstructions.sourcesToAdd[noteId1]).to(beNil())
            expect(updateInstructions.sourcesToAdd[noteId2]) == Set([self.pageIDs[2], self.pageIDs[4]])
            expect(updateInstructions.sourcesToAdd[noteId3]) == [self.pageIDs[5]]
            expect(updateInstructions.sourcesToRemove[noteId1]) == [self.pageIDs[2]]
            expect(updateInstructions.sourcesToRemove[noteId2]).to(beNil())
            expect(updateInstructions.sourcesToRemove[noteId3]) == [self.pageIDs[2]]
        } else { fail("sourcesToAdd and sourcesToRemove not created") }
        
    }
}
