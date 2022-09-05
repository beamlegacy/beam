import Foundation
import XCTest
import GRDB

@testable import Beam
@testable import BeamCore

class BeamLinkDBTests: XCTestCase {
    let beamHelper = BeamTestsHelper()
    let beamObjectHelper = BeamObjectTestsHelper()
    let linkDB = BeamData.shared.linkDB
    let objectManager = BeamData.shared.objectManager

    override func tearDown() {
        super.tearDown()
        linkDB.deleteAll(includedRemote: false)
        try? EncryptionManager.shared.replacePrivateKey(for: Configuration.testAccountEmail, with: Configuration.testPrivateKey)
    }

    func testDomain() throws {
        //not a domain case
        let url0 = "http://123.fr/yourdestiny.html"
        let id0 = linkDB.getOrCreateId(for: url0, title: nil, content: nil, destination: nil)
        var isDomain = linkDB.isDomain(id: id0)
        XCTAssertFalse(isDomain)
        var domainId = try XCTUnwrap(linkDB.getDomainId(id: id0))
        var domainLink = try XCTUnwrap(linkDB.linkFor(id: domainId))
        XCTAssertEqual(domainLink.url, "http://123.fr/")

        //domain case
        let url1 = "http://depannage.com"
        let id1 = linkDB.getOrCreateId(for: url1, title: nil, content: nil, destination: nil)
        isDomain = linkDB.isDomain(id: id1)
        XCTAssert(isDomain)
        domainId = try XCTUnwrap(linkDB.getDomainId(id: id1))
        domainLink = try XCTUnwrap(linkDB.linkFor(id: domainId))
        XCTAssertEqual(domainLink.url, "http://depannage.com/")

        //no existing id case
        XCTAssertFalse(linkDB.isDomain(id: UUID()))
        XCTAssertNil(linkDB.getDomainId(id: UUID()))
    }

    func testTopFrecenciesMatching() throws {
        let destinationLink = Link(url: "http://pet.com/dog", title: nil, content: nil, destination: nil, frecencyVisitSortScore: 3)
        let links = [
            Link(url: "http://animal.com/cat", title: nil, content: nil, destination: nil, frecencyVisitSortScore: 5),
            Link(url: "http://animal.com/dog", title: nil, content: nil, destination: destinationLink.id, frecencyVisitSortScore: 1),
            Link(url: "http://animal.com/cow", title: nil, content: nil, destination: nil), //is missing frecency
            Link(url: "http://animal.com/pig", title: nil, content: nil, destination: nil, frecencyVisitSortScore: 2),
            Link(url: "http://blabla.fr/", title: nil, content: nil, destination: nil, frecencyVisitSortScore: 5),
            destinationLink,
        ]
        let store = GRDBStore(writer: DatabaseQueue())
        let db = try UrlHistoryManager(holder: nil, objectManager: objectManager, store: store)
        try store.migrate()

        try db.insert(links: links)

        let results = db.getTopScoredLinks(matchingUrl: "animal", frecencyParam: .webVisit30d0, limit: 2)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].url, links[0].url)
        XCTAssertEqual(results[0].frecencySortScore, links[0].frecencyVisitSortScore)
        XCTAssertNil(results[0].destinationURL)
        XCTAssertEqual(results[1].url, links[1].url)
        XCTAssertEqual(results[1].frecencySortScore, destinationLink.frecencyVisitSortScore)
        XCTAssertEqual(results[1].destinationURL, destinationLink.url)
    }

    func testMoveFrecencyToLinkDB() throws {
        BeamDate.freeze("2001-01-01T00:00:00+000")
        let creationDate = BeamDate.now
        let dbQueue = DatabaseQueue()
        let store = GRDBStore(writer: dbQueue)
        let inMemoryGrdb = try UrlHistoryManager(holder: nil, objectManager: objectManager, store: store)
        try store.migrate(upTo: "flattenBrowsingTrees")

        //insertion of separated link and frecency records
        let urls = ["http://abc.com", "http://def.fr"]
        let linkStore = BeamLinkDB(objectManager: objectManager, overridenManager: inMemoryGrdb)
        let ids = urls.map { _ in UUID() }
        try zip(urls, ids).forEach { (url, id) in
            try dbQueue.write { db in
                try db.execute(sql: """
                INSERT INTO Link (id, url, createdAt, updatedAt)
                 VALUES (:id, :url, :date, :date)
                """, arguments: ["id": id, "url": url, "date": creationDate])
            }
        }
        let lastAccessAt = creationDate - Double(2)
        let scoreStore = GRDBUrlFrecencyStorage(overridenManager: inMemoryGrdb)
        let visitScore = FrecencyScore(id: ids[0], lastTimestamp: lastAccessAt, lastScore: 2.0, sortValue: 2.5)
        let readTimeScore = FrecencyScore(id: ids[0], lastTimestamp: lastAccessAt, lastScore: 1.0, sortValue: 1.0)
        try scoreStore.save(score: visitScore, paramKey: .webVisit30d0)
        try scoreStore.save(score: readTimeScore, paramKey: .webReadingTime30d0)

        //tested migration
        BeamDate.travel(1)
        let migrationDate = BeamDate.now
        try store.migrate(upTo: "moveUrlVisitFrecenciesToLinkDB")

        //link 0 frecency fields have been filled with visitScore values
        let link0 = try XCTUnwrap(linkStore.linkFor(id: ids[0]))
        XCTAssertEqual(link0.createdAt, creationDate)
        XCTAssertEqual(link0.updatedAt, migrationDate)
        XCTAssertEqual(link0.frecencyVisitLastAccessAt, lastAccessAt)
        XCTAssertEqual(link0.frecencyVisitScore, 2.0)
        XCTAssertEqual(link0.frecencyVisitSortScore, 2.5)

        //link 1 had no frecency record so it's new frecency field are nil
        let link1 = try XCTUnwrap(linkStore.linkFor(id: ids[1]))
        XCTAssertEqual(link1.createdAt, creationDate)
        XCTAssertEqual(link1.updatedAt, creationDate)
        XCTAssertNil(link1.frecencyVisitLastAccessAt)
        XCTAssertNil(link1.frecencyVisitScore)
        XCTAssertNil(link1.frecencyVisitSortScore)
        BeamDate.reset()
    }

    func testReceivedLinkFrecencyOverwrite() throws {
        let dbQueue = DatabaseQueue()
        let store = GRDBStore(writer: dbQueue)
        let inMemoryGrdb = try UrlHistoryManager(holder: nil, objectManager: objectManager, store: store)
        let db = BeamLinkDB(objectManager: objectManager, overridenManager: inMemoryGrdb)
        try store.migrate()
        let now = BeamDate.now
        let urls = ["http://coucou.fr", "http://hello.fr"]
        let localRecord0 = Link(url: urls[0], title: nil, content: nil, frecencyVisitLastAccessAt: now, frecencyVisitScore: 1.0, frecencyVisitSortScore: 1.0)
        let localRecord1 = Link(url: urls[1], title: nil, content: nil, frecencyVisitLastAccessAt: now, frecencyVisitScore: 1.0, frecencyVisitSortScore: 1.0)
        try inMemoryGrdb.insert(links: [localRecord0, localRecord1])
        let remoteRecord0 = Link(url: urls[0], title: "coucou", content: nil, frecencyVisitLastAccessAt: nil, frecencyVisitScore: nil, frecencyVisitSortScore: nil)
        let remoteRecord1 = Link(url: urls[1], title: "hello", content: nil, frecencyVisitLastAccessAt: now + Double(1), frecencyVisitScore: 2.0, frecencyVisitSortScore: 2.0)
        try db.receivedObjects([remoteRecord0, remoteRecord1])

        //link frecency fields are not reset to nil when receiving a frecencyless record
        let savedRecord0 = try XCTUnwrap(db.linkFor(url: urls[0]))
        XCTAssertEqual(savedRecord0.title, "coucou")
        let lastAccessAt0 = try XCTUnwrap(savedRecord0.frecencyVisitLastAccessAt)
        XCTAssert(abs(lastAccessAt0.timeIntervalSince(now)) < 0.001)
        XCTAssertEqual(savedRecord0.frecencyVisitScore, 1.0)
        XCTAssertEqual(savedRecord0.frecencyVisitSortScore, 1.0)

        //link frecency fields are updated when receiving a link with frecency
        let savedRecord1 = try XCTUnwrap(db.linkFor(url: urls[1]))
        XCTAssertEqual(savedRecord1.title, "hello")
        let lastAccessAt1 = try XCTUnwrap(savedRecord1.frecencyVisitLastAccessAt)
        XCTAssert(abs(lastAccessAt1.timeIntervalSince(now + Double(1))) < 0.001)
        XCTAssertEqual(savedRecord1.frecencyVisitScore, 2.0)
        XCTAssertEqual(savedRecord1.frecencyVisitSortScore, 2.0)
    }
    
    func testFrecencyStore() throws {
        let dbQueue = DatabaseQueue()
        let store = GRDBStore(writer: dbQueue)
        let inMemoryGrdb = try UrlHistoryManager(holder: nil, objectManager: objectManager, store: store)
        let linkstore = BeamLinkDB(objectManager: objectManager, overridenManager: inMemoryGrdb)
        let frecencyStorage = LinkStoreFrecencyUrlStorage(overridenManager: inMemoryGrdb, objectManager: objectManager, linkStore: linkstore)
        try store.migrate()
        BeamDate.freeze("2001-01-01T00:00:00+000")
        let t0 = BeamDate.now
        
        let linkId0 = linkstore.getOrCreateId(for: "http://moon.fr", title: nil, content: nil, destination: nil)
        let score = FrecencyScore(id: linkId0, lastTimestamp: t0, lastScore: 1, sortValue: 2)
        //storing frecency using readingTime param key doesn't fill link frecency fields
        try frecencyStorage.save(score: score, paramKey: .webReadingTime30d0)
        XCTAssertNil(try frecencyStorage.fetchOne(id: linkId0, paramKey: .webVisit30d0))
        //storing frecency using visit paramKey allows to retreive it
        try frecencyStorage.save(score: score, paramKey: .webVisit30d0)
        var fetched = try XCTUnwrap(frecencyStorage.fetchOne(id: linkId0, paramKey: .webVisit30d0))
        XCTAssertEqual(fetched.lastTimestamp, BeamDate.now)
        XCTAssertEqual(fetched.lastScore, 1)
        XCTAssertEqual(fetched.sortValue, 2)
        //update of single frecency
        BeamDate.travel(1.0)
        let t1 = BeamDate.now
        var updatedScore = FrecencyScore(id: linkId0, lastTimestamp: t1, lastScore: 1.5, sortValue: 3)
        try frecencyStorage.save(score: updatedScore, paramKey: .webVisit30d0)
        fetched = try XCTUnwrap(frecencyStorage.fetchOne(id: linkId0, paramKey: .webVisit30d0))
        XCTAssertEqual(fetched.lastTimestamp, t1)
        XCTAssertEqual(fetched.lastScore, 1.5)
        XCTAssertEqual(fetched.sortValue, 3)
        var link0 = try XCTUnwrap(linkstore.linkFor(id: linkId0))
        XCTAssertEqual(link0.createdAt, t0)
        XCTAssertEqual(link0.updatedAt, t1)
        
        //test of save many
        BeamDate.travel(1.0)
        let t2 = BeamDate.now
        let linkId1 = linkstore.getOrCreateId(for: "http://sun.com", title: nil, content: nil, destination: nil)
        let otherScore = FrecencyScore(id: linkId1, lastTimestamp: t2, lastScore: 2, sortValue: 7)
        updatedScore = FrecencyScore(id: linkId0, lastTimestamp: t2, lastScore: 1, sortValue: 2)
        try frecencyStorage.save(scores: [otherScore, updatedScore], paramKey: .webReadingTime30d0)
        XCTAssertNil(try frecencyStorage.fetchOne(id: linkId1, paramKey: .webVisit30d0))
        try frecencyStorage.save(scores: [otherScore, updatedScore], paramKey: .webVisit30d0)

        //updated score
        fetched = try XCTUnwrap(frecencyStorage.fetchOne(id: linkId0, paramKey: .webVisit30d0))
        XCTAssertEqual(fetched.lastTimestamp, t2)
        XCTAssertEqual(fetched.lastScore, 1)
        XCTAssertEqual(fetched.sortValue, 2)
        link0 = try XCTUnwrap(linkstore.linkFor(id: linkId0))
        XCTAssertEqual(link0.createdAt, t0)
        XCTAssertEqual(link0.updatedAt, t2)
        
        //created score
        fetched = try XCTUnwrap(frecencyStorage.fetchOne(id: linkId1, paramKey: .webVisit30d0))
        XCTAssertEqual(fetched.lastTimestamp, t2)
        XCTAssertEqual(fetched.lastScore, 2)
        XCTAssertEqual(fetched.sortValue, 7)
        let link1 = try XCTUnwrap(linkstore.linkFor(id: linkId1))
        XCTAssertEqual(link1.createdAt, t2)
        XCTAssertEqual(link1.updatedAt, t2)
        
        BeamDate.reset()
    }

    func testConflictManagement() throws {
        let store = GRDBStore(writer: DatabaseQueue())
        let db = try UrlHistoryManager(holder: nil, objectManager: objectManager, store: store)
        let linkstore = BeamLinkDB(objectManager: objectManager, overridenManager: db)
        try store.migrate()
        let now = BeamDate.now
        let remoteLink = Link(
            url: "httpl://abc.fr/",
            title: "Alphabet", content: nil,
            destination: nil,
            frecencyVisitLastAccessAt: nil,
            frecencyVisitScore: nil,
            frecencyVisitSortScore: nil,
            createdAt: now,
            updatedAt: now
        )
        let link = Link(
            url: "httpl://abc.fr/",
            title: "Something Else", content: nil,
            destination: nil,
            frecencyVisitLastAccessAt: now,
            frecencyVisitScore: 2,
            frecencyVisitSortScore: 1,
            createdAt: now,
            updatedAt: now - Double(1)
        )
        let postConflictLink = try linkstore.manageConflict(link, remoteLink)

        //local non nul frecency fields are kept
        XCTAssertEqual(postConflictLink.frecencyVisitScore, 2)
        XCTAssertEqual(postConflictLink.frecencyVisitSortScore, 1)
        XCTAssertEqual(postConflictLink.frecencyVisitLastAccessAt, now)
        //while remote more recent fields are chosen
        XCTAssertEqual(postConflictLink.title, "Alphabet")
    }
    func testTitleNotReplacedByEmpty() throws {
        let linkstore = BeamLinkDB(objectManager: objectManager)

        var link = linkstore.visit("http://site.cool/page", title: "A page", content: nil, destination: nil)
        link = linkstore.visit("http://site.cool/page", title: nil, content: nil, destination: nil)
        XCTAssertEqual(link.title, "A page")

        link = linkstore.visit("http://site.cool/page2", title: "Another page", content: nil, destination: nil)
        link = linkstore.visit("http://site.cool/page2", title: "", content: nil, destination: nil)
        XCTAssertEqual(link.title, "Another page")

    }
    func testYoutubeAliasesCleanup() throws {
        BeamDate.freeze("2001-01-01T12:21:03Z")
        let t0 = BeamDate.now
        let grdbStore = GRDBStore.empty()
        let urlHistoryManager = try UrlHistoryManager(objectManager: BeamObjectManager(),store: grdbStore)
        try grdbStore.migrate(upTo: "createUrlHistoryManager")
        let youtubeLink = urlHistoryManager.visit(url: "https://www.youtube.com/abc", content: nil, destination: nil)
        let otherLink = urlHistoryManager.visit(url: "https://www.somewhere.else/abc", content: nil, destination: youtubeLink.url)
        let aliasToErase = urlHistoryManager.visit(url: "https://www.youtube.com/def", content: nil, destination: youtubeLink.url)
        let aliasToKeep = urlHistoryManager.visit(url: "https://www.youtube.com/ght", content: nil, destination: otherLink.url)

        BeamDate.travel(24 * 60 * 60)
        let t1 = BeamDate.now
        try grdbStore.migrate(upTo: "linkAliasesCleanup")

        //not an alias: untouched
        let postCleanupYoutubeLink = try XCTUnwrap(urlHistoryManager.linkFor(id: youtubeLink.id))
        XCTAssertNil(postCleanupYoutubeLink.destination)
        XCTAssertEqual(postCleanupYoutubeLink.updatedAt, t0)

        //not a youtube link: untouched
        let postCleanupOtherLink = try XCTUnwrap(urlHistoryManager.linkFor(id: otherLink.id))
        XCTAssertEqual(postCleanupOtherLink.destination, youtubeLink.id)
        XCTAssertEqual(postCleanupOtherLink.updatedAt, t0)

        //youtube to youtube alias: cleaned
        let postCleanupAliasToErase = try XCTUnwrap(urlHistoryManager.linkFor(id: aliasToErase.id))
        XCTAssertNil(postCleanupAliasToErase.destination)
        XCTAssertEqual(postCleanupAliasToErase.updatedAt, t1)

        //youtube to somewhere else: untouched
        let postCleanupAliasToKeep = try XCTUnwrap(urlHistoryManager.linkFor(id: aliasToKeep.id))
        XCTAssertEqual(postCleanupAliasToKeep.destination, otherLink.id)
        XCTAssertEqual(postCleanupAliasToKeep.updatedAt, t0)

        BeamDate.reset()
    }

    func testGmailAliasesCleanup() throws {
        BeamDate.freeze("2001-01-01T12:21:03Z")
        let t0 = BeamDate.now
        let grdbStore = GRDBStore.empty()
        let urlHistoryManager = try UrlHistoryManager(objectManager: BeamObjectManager(),store: grdbStore)
        try grdbStore.migrate(upTo: "createUrlHistoryManager")
        let gmailLink = urlHistoryManager.visit(url: "https://mail.google.com/abc", content: nil, destination: nil)
        let aliasToErase = urlHistoryManager.visit(url: "https://www.some.thing/truc", content: nil, destination: gmailLink.url)
        let aliasToKeep = urlHistoryManager.visit(url: "http://gmail.com/", content: nil, destination: gmailLink.url)
        let otherAliasToKeep = urlHistoryManager.visit(url: "https://www.some.thing/truc2", content: nil, destination: aliasToErase.url)

        BeamDate.travel(24 * 60 * 60)
        let t1 = BeamDate.now
        try grdbStore.migrate(upTo: "linkAliasesCleanup")

        //not an alias: untouched
        let postCleanupGmailLink = try XCTUnwrap(urlHistoryManager.linkFor(id: gmailLink.id))
        XCTAssertNil(postCleanupGmailLink.destination)
        XCTAssertEqual(postCleanupGmailLink.updatedAt, t0)

        //somewhere else to gmail alias: cleaned
        let postCleanupAliasToErase = try XCTUnwrap(urlHistoryManager.linkFor(id: aliasToErase.id))
        XCTAssertNil(postCleanupAliasToErase.destination)
        XCTAssertEqual(postCleanupAliasToErase.updatedAt, t1)

        //gmail to gmail else: untouched
        let postCleanupAliasToKeep = try XCTUnwrap(urlHistoryManager.linkFor(id: aliasToKeep.id))
        XCTAssertEqual(postCleanupAliasToKeep.destination, gmailLink.id)
        XCTAssertEqual(postCleanupAliasToKeep.updatedAt, t0)

        //no gmail to not gmail: untouched
        let postCleanupotherAliasToKeep = try XCTUnwrap(urlHistoryManager.linkFor(id: otherAliasToKeep.id))
        XCTAssertEqual(postCleanupotherAliasToKeep.destination, aliasToErase.id)
        XCTAssertEqual(postCleanupotherAliasToKeep.updatedAt, t0)

        BeamDate.reset()
    }

    private func beforeNetworkTests() {
        // Need to freeze date to compare objects, as `createdAt` would be different from the network stubs we get
        // back from Vinyl.
        BeamDate.freeze("2021-03-19T12:21:03Z")

        BeamTestsHelper.logout()
        beamHelper.beginNetworkRecording(test: self)
        BeamTestsHelper.login()
        Configuration.beamObjectDirectCall = false
        Configuration.beamObjectOnRest = false
        try? EncryptionManager.shared.replacePrivateKey(for: Configuration.testAccountEmail, with: Configuration.testPrivateKey)
    }
}
