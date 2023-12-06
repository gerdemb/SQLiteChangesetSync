//
//  Head.swift
//
//
//  Created by Ben Gerdemann on 12/5/23.
//

import Foundation
import GRDB

public struct Head: Codable, Equatable {
    let uuid: String?
}

extension Head: FetchableRecord, PersistableRecord { }
