//
//  Changeset.swift
//
//
//  Created by Ben Gerdemann on 12/6/23.
//

import Foundation
import GRDB

public struct Changeset: Codable, Equatable {
    public let uuid: String
    public let parent_uuid: String?
    public let parent_changeset: Data
    public let merge_uuid: String?
    public let merge_changeset: Data?
    public let pushed: Bool
    public let meta: String
    
    public init(
        uuid: String? = nil,
        parent_uuid: String?,
        parent_changeset: Data,
        merge_uuid: String? = nil,
        merge_changeset: Data? = nil,
        pushed: Bool,
        meta: String = "{}"
    ) {
        if let uuid = uuid {
            self.uuid = uuid
        } else {
            self.uuid = UUID().uuidString
        }
        self.parent_uuid = parent_uuid
        self.parent_changeset = parent_changeset
        self.merge_uuid = merge_uuid
        self.merge_changeset = merge_changeset
        self.pushed = pushed
        self.meta = meta
    }
}

extension Changeset: FetchableRecord, PersistableRecord { }
