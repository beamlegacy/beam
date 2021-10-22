import XCTest
import Nimble

@testable import Beam

class TopDomainDelegateTests: XCTestCase {
    func testTopDomainDelegateTask() throws {
        let db = try TopDomainDatabase.empty()
//        let topDomainDelegate = TopDomainDelegate(db)
//        let session = URLSession(configuration: .default, delegate: topDomainDelegate, delegateQueue: nil)
//        let task = session.dataTask(with: Bundle.main.url(forResource: "majestic_million_test", withExtension: "csv")!)
//        task.resume()
//        waitUntil { done in
//            while !topDomainDelegate.hasStopped {
//                continue
//            }
//            done()
//        }
        let topDomains: [String] = {
            let filePath = Bundle.main.path(forResource: "topdomains_test", ofType: "txt")
            return try! String(contentsOfFile: filePath!).components(separatedBy: "\n")
        }()
        db.add(topDomains)

//        expect(topDomainDelegate.processedRecordCount) == 9

        // Prefix match
        let bestHit = try db.search(withPrefix: "face")
        expect(bestHit?.url) == "facebook.com"
//        expect(bestHit?.globalRank) == 2
    }
}
