//
//  ChangesetButtons.swift
//  SQLiteChangesetSyncDemo
//
//  Created by Ben Gerdemann on 12/7/23.
//

import SwiftUI

struct PullButton: View {
    @Environment(\.changesetRepository) private var changesetRepository
    private var titleKey: LocalizedStringKey
    
    init(_ titleKey: LocalizedStringKey) {
        self.titleKey = titleKey
    }
    
    var body: some View {
        Button {
            _ = try! changesetRepository.pull()
        } label: {
            Label(titleKey, systemImage: "plus")
        }
    }
}

struct MergeButton: View {
    @Environment(\.changesetRepository) private var changesetRepository
    private var titleKey: LocalizedStringKey
    
    init(_ titleKey: LocalizedStringKey) {
        self.titleKey = titleKey
    }
    
    var body: some View {
        Button {
            _ = try! changesetRepository.mergeAll()
        } label: {
            Label(titleKey, systemImage: "plus")
        }
    }
}
