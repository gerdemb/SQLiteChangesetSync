//
//  ChangesetMeta.swift
//  SQLiteChangesetSyncDemo
//
//  Created by Ben Gerdemann on 12/8/23.
//

import Foundation

struct ChangesetMeta: Codable {
    let message: String
    
    func asJSONString() throws -> String {
        let jsonData = try JSONEncoder().encode(self)
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }
}
