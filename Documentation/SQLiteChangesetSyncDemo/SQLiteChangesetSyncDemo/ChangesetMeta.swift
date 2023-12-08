//
//  ChangesetMeta.swift
//  SQLiteChangesetSyncDemo
//
//  Created by Ben Gerdemann on 12/8/23.
//

import Foundation

struct ChangesetMeta: Codable {
    private static var jsonEncoder = JSONEncoder()
    let message: String
    
    func asJSONString() throws -> String {
        let jsonData = try Self.jsonEncoder.encode(self)
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }
}
