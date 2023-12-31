//
//  ChangesetButtons.swift
//  SQLiteChangesetSyncDemo
//
//  Created by Ben Gerdemann on 12/7/23.
//

import SwiftUI
import OSLog

struct PullButton: View {
    @Environment(\.changesetRepository) private var changesetRepository
    private var titleKey: LocalizedStringKey
    
    init(_ titleKey: LocalizedStringKey) {
        self.titleKey = titleKey
    }
    
    var body: some View {
        Button {
            do {
                _ = try changesetRepository.pull()
            } catch {
                Logger.sqliteChangesetSyncDemo.error("Pull error \(error)")
            }
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
            do {
                _ = try changesetRepository.mergeAll()
            } catch {
                Logger.sqliteChangesetSyncDemo.error("Merge error \(error)")
            }
        } label: {
            Label(titleKey, systemImage: "plus")
        }
    }
}
