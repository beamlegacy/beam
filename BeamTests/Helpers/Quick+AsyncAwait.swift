// see https://gist.github.com/gshahbazian/e5b01c8e9df60778a19ca91155b1a7fa and https://github.com/Quick/Quick/issues/1084

import Nimble
import Quick
import XCTest

public func asyncIt(_ description: String, flags: FilterFlags = [:], file: FileString = #file, line: UInt = #line, closure: @MainActor @escaping () async throws -> Void) {
    it(description, flags: flags, file: file, line: line) {
        var thrownError: Error?
        let errorHandler = { thrownError = $0 }
        let expectation = QuickSpec.current.expectation(description: description)

        Task {
            do {
                try await closure()
            } catch {
                errorHandler(error)
            }

            expectation.fulfill()
        }

        QuickSpec.current.wait(for: [expectation], timeout: 60)

        if let error = thrownError {
            XCTFail("Async error thrown: \(error)")
        }
    }
}

public func asyncBeforeEach(_ closure: @MainActor @escaping (ExampleMetadata) async -> Void) {
    beforeEach({ exampleMetadata in
        let expectation = QuickSpec.current.expectation(description: "asyncBeforeEach")
        Task {
            await closure(exampleMetadata)
            expectation.fulfill()
        }
        QuickSpec.current.wait(for: [expectation], timeout: 60)
    })
}

public func asyncAfterEach(_ closure: @MainActor @escaping (ExampleMetadata) async -> Void) {
    afterEach({ exampleMetadata in
        let expectation = QuickSpec.current.expectation(description: "asyncAfterEach")
        Task {
            await closure(exampleMetadata)
            expectation.fulfill()
        }
        QuickSpec.current.wait(for: [expectation], timeout: 60)
    })
}
