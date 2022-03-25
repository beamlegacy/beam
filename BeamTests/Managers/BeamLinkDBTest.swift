import Foundation
import XCTest
import GRDB

@testable import Beam
@testable import BeamCore

class BeamLinkDBTests: XCTestCase {
    let beamHelper = BeamTestsHelper()
    let beamObjectHelper = BeamObjectTestsHelper()

    override func tearDown() {
        super.tearDown()
        BeamLinkDB.shared.deleteAll(includedRemote: false)
        try? EncryptionManager.shared.replacePrivateKey(for: Configuration.testAccountEmail, with: Configuration.testPrivateKey)
    }

    func testDomain() throws {
        //not a domain case
        let url0 = "http://123.fr/yourdestiny.html"
        let id0 = BeamLinkDB.shared.getOrCreateIdFor(url: url0, title: nil, content: nil, destination: nil)
        var isDomain = BeamLinkDB.shared.isDomain(id: id0)
        XCTAssertFalse(isDomain)
        var domainId = try XCTUnwrap(BeamLinkDB.shared.getDomainId(id: id0))
        var domainLink = try XCTUnwrap(BeamLinkDB.shared.linkFor(id: domainId))
        XCTAssertEqual(domainLink.url, "http://123.fr/")

        //domain case
        let url1 = "http://depannage.com"
        let id1 = BeamLinkDB.shared.getOrCreateIdFor(url: url1, title: nil, content: nil, destination: nil)
        isDomain = BeamLinkDB.shared.isDomain(id: id1)
        XCTAssert(isDomain)
        domainId = try XCTUnwrap(BeamLinkDB.shared.getDomainId(id: id1))
        domainLink = try XCTUnwrap(BeamLinkDB.shared.linkFor(id: domainId))
        XCTAssertEqual(domainLink.url, "http://depannage.com/")

        //no existing id case
        XCTAssertFalse(BeamLinkDB.shared.isDomain(id: UUID()))
        XCTAssertNil(BeamLinkDB.shared.getDomainId(id: UUID()))
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
        let db = GRDBDatabase.empty()
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

    func testMissingLinkHandling() {
        //when getting id for missing url, it retreives the link but doesn't save it in db
        let createdLinkId: UUID = BeamLinkDB.shared.getOrCreateIdFor(url: "<???>", title: nil, content: nil, destination: nil)
        XCTAssertEqual(createdLinkId, Link.missing.id)
        XCTAssertNil(GRDBDatabase.shared.linkFor(url: "<???>"))

        //when visiting missing url, it retreives the link but doesn't save it in db
        let visitedLinkId: UUID = BeamLinkDB.shared.visit("<???>", title: nil, content: nil, destination: nil).id
        XCTAssertEqual(visitedLinkId, Link.missing.id)
        XCTAssertNil(GRDBDatabase.shared.linkFor(url: "<???>"))
    }

    func testMoveFrecencyToLinkDB() throws {
        BeamDate.freeze("2001-01-01T00:00:00+000")
        let creationDate = BeamDate.now
        let dbQueue = DatabaseQueue()
        let inMemoryGrdb = try GRDBDatabase(dbQueue, migrate: false)
        try inMemoryGrdb.migrate(upTo: "flattenBrowsingTrees")

        //insertion of separated link and frecency records
        let urls = ["http://abc.com", "http://def.fr"]
        let linkStore = BeamLinkDB(db: inMemoryGrdb)
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
        let scoreStore = GRDBUrlFrecencyStorage(db: inMemoryGrdb)
        let visitScore = FrecencyScore(id: ids[0], lastTimestamp: lastAccessAt, lastScore: 2.0, sortValue: 2.5)
        let readTimeScore = FrecencyScore(id: ids[0], lastTimestamp: lastAccessAt, lastScore: 1.0, sortValue: 1.0)
        try scoreStore.save(score: visitScore, paramKey: .webVisit30d0)
        try scoreStore.save(score: readTimeScore, paramKey: .webReadingTime30d0)

        //tested migration
        BeamDate.travel(1)
        let migrationDate = BeamDate.now
        try inMemoryGrdb.migrate(upTo: "moveUrlVisitFrecenciesToLinkDB")

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
        let db = GRDBDatabase.empty()
        let store = BeamLinkDB(db: db)
        let now = BeamDate.now
        let urls = ["http://coucou.fr", "http://hello.fr"]
        let localRecord0 = Link(url: urls[0], title: nil, content: nil, frecencyVisitLastAccessAt: now, frecencyVisitScore: 1.0, frecencyVisitSortScore: 1.0)
        let localRecord1 = Link(url: urls[1], title: nil, content: nil, frecencyVisitLastAccessAt: now, frecencyVisitScore: 1.0, frecencyVisitSortScore: 1.0)
        try db.insert(links: [localRecord0, localRecord1])
        let remoteRecord0 = Link(url: urls[0], title: "coucou", content: nil, frecencyVisitLastAccessAt: nil, frecencyVisitScore: nil, frecencyVisitSortScore: nil)
        let remoteRecord1 = Link(url: urls[1], title: "hello", content: nil, frecencyVisitLastAccessAt: now + Double(1), frecencyVisitScore: 2.0, frecencyVisitSortScore: 2.0)
        try store.receivedObjects([remoteRecord0, remoteRecord1])

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
    
    func testFrencencyStore() throws {
        let db = GRDBDatabase.empty()
        let linkstore = BeamLinkDB(db: db)
        let frencencyStorage = LinkStoreFrecencyUrlStorage(db: db)
        BeamDate.freeze("2001-01-01T00:00:00+000")
        let t0 = BeamDate.now
        
        let linkId0 = linkstore.getOrCreateIdFor(url: "http://moon.fr", title: nil, content: nil, destination: nil)
        let score = FrecencyScore(id: linkId0, lastTimestamp: t0, lastScore: 1, sortValue: 2)
        //storing frecency using readingTime param key doesn't fill link frecency fields
        try frencencyStorage.save(score: score, paramKey: .webReadingTime30d0)
        XCTAssertNil(try frencencyStorage.fetchOne(id: linkId0, paramKey: .webVisit30d0))
        //storing frecency using visit paramKey allows to retreive it
        try frencencyStorage.save(score: score, paramKey: .webVisit30d0)
        var fetched = try XCTUnwrap(frencencyStorage.fetchOne(id: linkId0, paramKey: .webVisit30d0))
        XCTAssertEqual(fetched.lastTimestamp, BeamDate.now)
        XCTAssertEqual(fetched.lastScore, 1)
        XCTAssertEqual(fetched.sortValue, 2)
        //update of single frecency
        BeamDate.travel(1.0)
        let t1 = BeamDate.now
        var updatedScore = FrecencyScore(id: linkId0, lastTimestamp: t1, lastScore: 1.5, sortValue: 3)
        try frencencyStorage.save(score: updatedScore, paramKey: .webVisit30d0)
        fetched = try XCTUnwrap(frencencyStorage.fetchOne(id: linkId0, paramKey: .webVisit30d0))
        XCTAssertEqual(fetched.lastTimestamp, t1)
        XCTAssertEqual(fetched.lastScore, 1.5)
        XCTAssertEqual(fetched.sortValue, 3)
        var link0 = try XCTUnwrap(linkstore.linkFor(id: linkId0))
        XCTAssertEqual(link0.createdAt, t0)
        XCTAssertEqual(link0.updatedAt, t1)
        
        //test of save many
        BeamDate.travel(1.0)
        let t2 = BeamDate.now
        let linkId1 = linkstore.getOrCreateIdFor(url: "http://sun.com", title: nil, content: nil, destination: nil)
        let otherScore = FrecencyScore(id: linkId1, lastTimestamp: t2, lastScore: 2, sortValue: 7)
        updatedScore = FrecencyScore(id: linkId0, lastTimestamp: t2, lastScore: 1, sortValue: 2)
        try frencencyStorage.save(scores: [otherScore, updatedScore], paramKey: .webReadingTime30d0)
        XCTAssertNil(try frencencyStorage.fetchOne(id: linkId1, paramKey: .webVisit30d0))
        try frencencyStorage.save(scores: [otherScore, updatedScore], paramKey: .webVisit30d0)

        //updated score
        fetched = try XCTUnwrap(frencencyStorage.fetchOne(id: linkId0, paramKey: .webVisit30d0))
        XCTAssertEqual(fetched.lastTimestamp, t2)
        XCTAssertEqual(fetched.lastScore, 1)
        XCTAssertEqual(fetched.sortValue, 2)
        link0 = try XCTUnwrap(linkstore.linkFor(id: linkId0))
        XCTAssertEqual(link0.createdAt, t0)
        XCTAssertEqual(link0.updatedAt, t2)
        
        //created score
        fetched = try XCTUnwrap(frencencyStorage.fetchOne(id: linkId1, paramKey: .webVisit30d0))
        XCTAssertEqual(fetched.lastTimestamp, t2)
        XCTAssertEqual(fetched.lastScore, 2)
        XCTAssertEqual(fetched.sortValue, 7)
        let link1 = try XCTUnwrap(linkstore.linkFor(id: linkId1))
        XCTAssertEqual(link1.createdAt, t2)
        XCTAssertEqual(link1.updatedAt, t2)
        
        BeamDate.reset()
    }

    func testUrlNormalization() {
        let nonStandardUrl = "http://lemonde.fr"
        let standardUrl = "http://lemonde.fr/"
        let id0 = BeamLinkDB.shared.getOrCreateIdFor(url: nonStandardUrl, title: nil, content: nil, destination: nil)
        let id1 = BeamLinkDB.shared.getOrCreateIdFor(url: standardUrl, title: nil, content: nil, destination: nil)
        XCTAssertEqual(id0, id1)

        let link0 = BeamLinkDB.shared.visit(nonStandardUrl, title: nil, content: nil, destination: nil)
        let link1 = BeamLinkDB.shared.visit(standardUrl, title: nil, content: nil, destination: nil)
        XCTAssertEqual(link0.id, id0)
        XCTAssertEqual(link1.id, id0)
        XCTAssertEqual(link0.url, standardUrl)
        XCTAssertEqual(link1.url, standardUrl)
    }

    func testConflictManagement() throws {
        beforeNetworkTests()
        let beamObjectHelper = BeamObjectTestsHelper()
        let db = GRDBDatabase.empty()
        let linkstore = BeamLinkDB(db: db)
        let now = BeamDate.now
        var link = Link(
            url: "httpl://abc.fr/",
            title: "Alphabet", content: nil,
            destination: nil,
            frecencyVisitLastAccessAt: nil,
            frecencyVisitScore: nil,
            frecencyVisitSortScore: nil,
            createdAt: now,
            updatedAt: now
        )
        beamObjectHelper.saveOnAPIAndSaveChecksum(link)
        //create a conflict by making local previous checksum different from remote checksum
        link.frecencyVisitScore = 1
        link.frecencyVisitSortScore = 1
        link.frecencyVisitLastAccessAt = now
        link.title = "Something Else"
        link.updatedAt = now - Double(1) //forces to choose remote version in merge
        try db.insert(links: [link])
        try? BeamObjectChecksum.savePreviousChecksum(object: link)
        //making current local checksum differ from local previous checksum to allow for remote save
        link.frecencyVisitScore = 2
        try db.insert(links: [link])
        let expectation = self.expectation(description: "network save")
        try _ = linkstore.saveAllOnBeamObjectApi { _ in expectation.fulfill() }
        waitForExpectations(timeout: 5, handler: nil)

        let postConflictLink = try XCTUnwrap(linkstore.linkFor(id: link.id))
        //local non nul frecency fields are kept
        XCTAssertEqual(postConflictLink.frecencyVisitScore, 2)
        XCTAssertEqual(postConflictLink.frecencyVisitSortScore, 1)
        XCTAssertEqual(postConflictLink.frecencyVisitLastAccessAt, now)
        //while remote more recent fields are chosen
        XCTAssertEqual(postConflictLink.title, "Alphabet")

        stopNetworkTests()
    }

    private func beforeNetworkTests() {
        // Need to freeze date to compare objects, as `createdAt` would be different from the network stubs we get
        // back from Vinyl.
        BeamDate.freeze("2021-03-19T12:21:03Z")

        BeamTestsHelper.logout()
        beamHelper.beginNetworkRecording(test: self)
        BeamTestsHelper.login()
        Configuration.beamObjectOnRest = false
        try? EncryptionManager.shared.replacePrivateKey(for: Configuration.testAccountEmail, with: Configuration.testPrivateKey)
    }

    private func stopNetworkTests() {
        BeamObjectTestsHelper().deleteAll()
        beamHelper.endNetworkRecording()
        BeamDate.reset()
    }
}
