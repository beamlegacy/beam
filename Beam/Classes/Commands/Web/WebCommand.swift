//
//  WebCommand.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 31/08/2021.
//

import Foundation
import BeamCore

class WebCommand: Command<BeamState> {
    override init(name: String) {
        super.init(name: name)
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    func encode(tab: BrowserTab) -> Data? {
        var data: Data?
        do {
            let encoder = JSONEncoder()
            data = try encoder.encode(tab)
        } catch {
            Logger.shared.logError("Can't encode BrowserTab", category: .general)
        }
        return data
    }

    func decode(data: Data?) -> BrowserTab? {
        guard let data = data else { return nil }
        var tab: BrowserTab?
        do {
            let decoder = JSONDecoder()
            tab = try decoder.decode(BrowserTab.self, from: data)
        } catch {
            Logger.shared.logError("Can't decode BrowserTab data", category: .general)
        }
        return tab
    }
}

class GroupWebCommand: GroupCommand<BeamState> {
    required public init(from decoder: Decoder) throws {
        try super.init(from: decoder)

        let values = try decoder.container(keyedBy: CodingKeys.self)
        // TODO: Implement generic way to handle this
        // Look at BeamObjectManager and his translator
        if name == ClosedTabDataPersistence.closeTabCmdGrp {
            commands = try values.decode([CloseTab].self, forKey: .commands)
        }
    }
}
