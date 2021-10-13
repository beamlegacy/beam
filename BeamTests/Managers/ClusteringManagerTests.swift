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
            BeamNote(title: "Machine Learning"),
            BeamNote(title: "Short note")
        ]
        notes[0].children = [BeamElement("The official site of Roger Federer is www.rogerfederer.com"), BeamElement("His Wikipedia page is https://en.wikipedia.org/wiki/Roger_Federer"), BeamElement("I wonder if his email is rogerfederer@gmail.com"), BeamElement("Federer has played in an era where he dominated men's tennis together with Rafael Nadal and Novak Djokovic, who have been collectively referred to as the Big Three and are widely considered three of the greatest tennis players of all-time.[c] A Wimbledon junior champion in 1998, Federer won his first Grand Slam singles title at Wimbledon in 2003 at age 21. In 2004, he won three out of the four major singles titles and the ATP Finals,[d] a feat he repeated in 2006 and 2007. From 2005 to 2010, Federer made 18 out of 19 major singles finals. During this span, he won his fifth consecutive titles at both Wimbledon and the US Open. He completed the career Grand Slam at the 2009 French Open after three previous runner-ups to Nadal, his main rival up until 2010. At age 27, he also surpassed Pete Sampras's then-record of 14 Grand Slam men's singles titles at Wimbledon in 2009.")]
        notes[1].children = [BeamElement("Paris is a major railway, highway, and air-transport hub served by two international airports: Paris–Charles de Gaulle (the second-busiest airport in Europe) and Paris–Orly.[10][11] Opened in 1900, the city's subway system, the Paris Métro, serves 5.23 million passengers daily;[12] it is the second-busiest metro system in Europe after the Moscow Metro. Gare du Nord is the 24th-busiest railway station in the world, but the busiest located outside Japan, with 262 million passengers in 2015.[13] Paris is especially known for its museums and architectural landmarks: the Louvre remained the most-visited museum in the world with 2,677,504 visitors in 2020, despite the long museum closings caused by the COVID-19 virus.[14] The Musée d'Orsay, Musée Marmottan Monet and Musée de l'Orangerie are noted for their collections of French Impressionist art. The Pompidou Centre Musée National d'Art Moderne has the largest collection of modern and contemporary art in Europe. The Musée Rodin and Musée Picasso exhibit the works of two noted Parisians. The historical district along the Seine in the city centre is classified as a UNESCO World Heritage Site; popular landmarks there include the Cathedral of Notre Dame de Paris on the Île de la Cité, now closed for renovation after the 15 April 2019 fire. Other popular tourist sites include the Gothic royal chapel of Sainte-Chapelle, also on the Île de la Cité; the Eiffel Tower, constructed for the Paris Universal Exposition of 1889; the Grand Palais and Petit Palais, built for the Paris Universal Exposition of 1900; the Arc de Triomphe on the Champs-Élysées, and the hill of Montmartre with its artistic history and its Basilica of Sacré-Coeur.")]
        notes[2].children = [BeamElement("Machine learning (ML) is the study of computer algorithms that can improve automatically through experience and by the use of data.[1] It is seen as a part of artificial intelligence. Machine learning algorithms build a model based on sample data, known as 'training data', in order to make predictions or decisions without being explicitly programmed to do so.[2] Machine learning algorithms are used in a wide variety of applications, such as in medicine, email filtering, speech recognition, and computer vision, where it is difficult or unfeasible to develop conventional algorithms to perform the needed tasks. A subset of machine learning is closely related to computational statistics, which focuses on making predictions using computers; but not all machine learning is statistical learning. The study of mathematical optimization delivers methods, theory and application domains to the field of machine learning. Data mining is a related field of study, focusing on exploratory data analysis through unsupervised learning.[5][6] Some implementations of machine learning use data and neural networks in a way that mimics the working of a biological brain.[7][8] In its application across business problems, machine learning is also referred to as predictive analytics.")]
        notes[3].children = [BeamElement("This is just a short note")]
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

    /// Test that adding notes and then pages works correctly. Includes a short note that is not to be added
    func testAddNotesThenPages() throws {
        clusteringManager.addNote(note: notes[0])
        expect(self.clusteringManager.clusteredNotesId).toEventually(contain([notes[0].id]))

        clusteringManager.addNote(note: notes[1])
        expect(self.clusteringManager.clusteredNotesId).toEventually(contain([notes[1].id]) || contain([notes[0].id, notes[1].id]))

        // A short note is to be ignored
        clusteringManager.addNote(note: notes[3])
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

    /// Test that URLs that are not suggested for any note are extracted correctly for the pourposes of monitoring
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

    /// Test that text cleaning for notes is done correctly
    func testNoteTextCleaning() throws {
        let fullText = self.clusteringManager.cleanTextFrom(note: notes[0])
        let separators = CharacterSet(charactersIn: " \n")
        let splittedText = fullText.components(separatedBy: separators)
        expect(splittedText[0]) == "Tennis"
        expect(splittedText[1]) == "The"
        expect(splittedText[8]) == ""
    }
}
