//
//  BrowserPasswordImporter.swift
//  Beam
//
//  Created by Frank Lefebvre on 20/12/2021.
//

import Foundation
import Combine
import BeamCore

protocol BrowserPasswordItem {
    var url: URL { get }
    var username: String { get }
    var password: Data { get }
    var dateCreated: Date? { get }
    var dateLastUsed: Date? { get }
}

struct BrowserPasswordResult {
    var itemCount: Int
    var item: BrowserPasswordItem
}

protocol BrowserPasswordImporter: BrowserImporter {
    var passwordsPublisher: AnyPublisher<BrowserPasswordResult, Error> { get }
    func importPasswords() throws
}
