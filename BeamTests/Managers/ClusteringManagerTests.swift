import Quick
import Nimble
import XCTest
import Foundation

@testable import Beam
@testable import BeamCore

class ClusteringManagerTests: XCTestCase {
    var documentManager: DocumentManager!
    var sessionLinkRanker: SessionLinkRanker!
    var activeSources: ActiveSources!
    var clusteringManager: ClusteringManager!

    var documents: [IndexDocument]!
    var informations: [TabInformation]!
    var notes: [BeamNote]!

    override func setUp() {
        documentManager = DocumentManager()
        sessionLinkRanker = SessionLinkRanker()
        activeSources = ActiveSources()
        clusteringManager = ClusteringManager(ranker: sessionLinkRanker, documentManager: documentManager, candidate: 2, navigation: 0.5, text: 0.8, entities: 0.5, sessionId: UUID(), activeSources: activeSources)

        clusteringManager.initialiseNotes = false
        
        documents = [
            IndexDocument(id: 0, title: "Roger Federer"),
            IndexDocument(id: 1, title: "Rafael Nadal"),
            IndexDocument(id: 2, title: "Novak Djokovic"),
            IndexDocument(id: 3, title: "Richard Gasquet")
        ]
        informations = [
            TabInformation(url: URL(string: "http://www.rogerfederer.com")!, document: documents[0], textContent: "Roger Federer is the best tennis player ever", cleanedTextContentForClustering: "Roger Federer is the best tennis player ever"),
            TabInformation(url: URL(string: "https://rafaelnadal.com/en/")!, document: documents[1], textContent: "Rafael Nadal is also pretty good", cleanedTextContentForClustering: "Rafael Nadal is also pretty good"),
            TabInformation(url: URL(string: "https://novakdjokovic.com/en/")!, document: documents[2], textContent: "Not you", cleanedTextContentForClustering: "Not you"),
            TabInformation(url: URL(string: "http://www.richardgasquet.net")!, document: documents[3], textContent: "Richard Gasquet has a wonderful one-handed backhand", cleanedTextContentForClustering: "Not you")
        ]
        notes = [
            BeamNote(title: "Tennis"),
            BeamNote(title: "Paris"),
            BeamNote(title: "Machine Learning")
        ]
    }

    /// Test that adding pages and then notes works correctly
    func testAddPagesThenNotes() throws {
        clusteringManager.addPage(id: documents[0].id, parentId: nil, value: informations[0])
        expect(self.clusteringManager.clusteredPagesId).toEventually(equal([[0]]))

        clusteringManager.addPage(id: documents[1].id, parentId: nil, value: informations[1])
        expect(self.clusteringManager.clusteredPagesId).toEventually(equal([[0,1]]) || contain([1]))

        clusteringManager.addNote(note: notes[0])
        expect(self.clusteringManager.clusteredNotesId).toEventually(contain([notes[0].id]))

        clusteringManager.addNote(note: notes[1])
        expect(self.clusteringManager.clusteredNotesId).toEventually(contain([notes[1].id]) || contain([notes[0].id, notes[1].id]))
        expect(self.clusteringManager.clusteredPagesId).toEventually(contain([0,1]) || contain([1]))

        clusteringManager.addPage(id: documents[2].id, parentId: nil, value: informations[2])
        expect(self.clusteringManager.clusteredPagesId).toEventually(contain([0, 1, 2]) || contain([2]) || contain([0, 2]) || contain([1, 2]))
    }

    /// Test that adding notes and then pages works correctly
    func testAddNotesThenPages() throws {
        clusteringManager.addNote(note: notes[0])
        expect(self.clusteringManager.clusteredNotesId).toEventually(contain([notes[0].id]))

        clusteringManager.addNote(note: notes[1])
        expect(self.clusteringManager.clusteredNotesId).toEventually(contain([notes[1].id]) || contain([notes[0].id, notes[1].id]))

        clusteringManager.addPage(id: documents[0].id, parentId: nil, value: informations[0])
        expect(self.clusteringManager.clusteredPagesId).toEventually(contain([0]))

        clusteringManager.addPage(id: documents[1].id, parentId: nil, value: informations[1])
        expect(self.clusteringManager.clusteredPagesId).toEventually(contain([0,1]) || contain([1]))

        clusteringManager.addNote(note: notes[2])
        if !self.clusteringManager.clusteredNotesId.contains([notes[0].id, notes[1].id, notes[2].id]) {
            expect(self.clusteringManager.clusteredNotesId).toEventually(contain([notes[2].id]) || contain([notes[0].id, notes[2].id]) || contain([notes[1].id, notes[2].id]))
        }
    }

    /// Test that the clusteringManager knows how to extract id-s and parenting relations correctly
    func testGetIdAndParent() throws {
        // Start a new browsing tree
        let tree = BrowsingTree(nil)
        var nodes = [tree.current]

        // Navigate to first page, no parent
        tree.navigateTo(url: informations[0].url.string, title: nil, startReading: false, isLinkActivation: false, readCount: 400)
        nodes.append(tree.current)
        informations[0].currentTabTree = tree
        informations[0].parentBrowsingNode = nodes[0]
        expect(self.clusteringManager.getIdAndParent(tabToIndex: self.informations[0]).0) == nodes[1]?.link
        expect(self.clusteringManager.getIdAndParent(tabToIndex: self.informations[0]).1).to(beNil())

        // Navigate to second page from first page
        tree.navigateTo(url: informations[1].url.string, title: nil, startReading: false, isLinkActivation: true, readCount: 400)
        nodes.append(tree.current)
        informations[1].currentTabTree = tree
        informations[1].parentBrowsingNode = nodes[1]
        expect(self.clusteringManager.getIdAndParent(tabToIndex: self.informations[1]).0) == nodes[2]?.link
        expect(self.clusteringManager.getIdAndParent(tabToIndex: self.informations[1]).1) == nodes[1]?.link

        // Navigate to third page in a new tab
        tree.openLinkInNewTab()
        let newTabTree = BrowsingTree(nil)
        newTabTree.navigateTo(url: informations[2].url.string, title: nil, startReading: false, isLinkActivation: true, readCount: 400)
        nodes.append(newTabTree.current)
        informations[2].currentTabTree = newTabTree
        informations[2].parentBrowsingNode = nodes[2]
        expect(self.clusteringManager.getIdAndParent(tabToIndex: self.informations[2]).0) == nodes[3]?.link
        expect(self.clusteringManager.getIdAndParent(tabToIndex: self.informations[2]).1) == nodes[2]?.link

        // Go back on the original tree, then open a new page
        tree.goBack()
        tree.openLinkInNewTab()
        let anotherNewTabTree = BrowsingTree(nil)
        anotherNewTabTree.navigateTo(url: informations[3].url.string, title: nil, startReading: false, isLinkActivation: true, readCount: 400)
        nodes.append(anotherNewTabTree.current)
        informations[3].currentTabTree = anotherNewTabTree
        informations[3].parentBrowsingNode = nodes[1]
        expect(self.clusteringManager.getIdAndParent(tabToIndex: self.informations[3]).0) == nodes[4]?.link
        expect(self.clusteringManager.getIdAndParent(tabToIndex: self.informations[3]).1) == nodes[1]?.link
    }
    func testOrphanedUrls() throws {
        let noteId = UUID()
        let noteGroups = [[noteId], [], []]
        let urlGroups: [[UInt64]] = [
            [0], //this page is in the same cluster as noteId note
            [1, 2], //this cluster contains noteId's note active source
            [3]] //this cluster can't be linked to any note
        let activeSources = ActiveSources()
        activeSources.activeSources = [noteId: [2]]
        expect(self.clusteringManager.getOrphanedUrlGroups(urlGroups: urlGroups, noteGroups: noteGroups, activeSources: activeSources)) == [[3]]
    }
}
