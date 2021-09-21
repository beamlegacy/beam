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
            IndexDocument(id: 2, title: "Novak Djokovic")
        ]
        informations = [
            TabInformation(url: URL(string: "http://www.rogerfederer.com")!, document: documents[0], textContent: "Roger Federer is the best tennis player ever", cleanedTextContentForClustering: "Roger Federer is the best tennis player ever"),
            TabInformation(url: URL(string: "https://rafaelnadal.com/en/")!, document: documents[1], textContent: "Rafael Nadal is also pretty good", cleanedTextContentForClustering: "Rafael Nadal is also pretty good"),
            TabInformation(url: URL(string: "https://novakdjokovic.com/en/")!, document: documents[2], textContent: "Not you", cleanedTextContentForClustering: "Not you")
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
}
