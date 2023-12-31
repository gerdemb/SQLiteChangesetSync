//
//  CloudKitButtons.swift
//  SQLiteChangesetSyncDemo
//
//  Created by Ben Gerdemann on 12/7/23.
//

import SwiftUI
import OSLog

struct PushButton: View {
    @Environment(\.cloudKitManager) private var cloudKitManager
    private var titleKey: LocalizedStringKey
    
    init(_ titleKey: LocalizedStringKey) {
        self.titleKey = titleKey
    }
    
    var body: some View {
        Button {
            Task {
                do {
                    _ = try await cloudKitManager.push()
                } catch {
                    Logger.sqliteChangesetSyncDemo.error("Push error \(error)")
                }
            }
        } label: {
            Label(titleKey, systemImage: "plus")
        }
    }
}

struct FetchButton: View {
    @Environment(\.cloudKitManager) private var cloudKitManager
    private var titleKey: LocalizedStringKey
    
    init(_ titleKey: LocalizedStringKey) {
        self.titleKey = titleKey
    }
    
    var body: some View {
        Button {
            Task {
                do {
                    _ = try await cloudKitManager.fetch()
                } catch {
                    Logger.sqliteChangesetSyncDemo.error("Fetch error \(error)")
                }
            }
        } label: {
            Label(titleKey, systemImage: "plus")
        }
    }
}


struct ResetDatabaseButton: View {
    @Environment(\.changesetRepository) private var changesetRepository
    @Environment(\.cloudKitManager) private var cloudKitManager
    @Environment(\.playerRepository) private var playerRepository
    private var titleKey: LocalizedStringKey
    
    init(_ titleKey: LocalizedStringKey) {
        self.titleKey = titleKey
    }
    
    var body: some View {
        Button {
            // Order is important here. playerRepository.reset() will commit a changeset for deleting all the players.
            // Then, changesetRepository.reset() will delete all the changesets
            try! playerRepository.reset()
            try! changesetRepository.reset()
            cloudKitManager.resetLastChangeToken()
        } label: {
            Label(titleKey, systemImage: "plus")
        }
    }
}

struct ResetCloudKitButton: View {
    @Environment(\.cloudKitManager) private var cloudKitManager
    private var titleKey: LocalizedStringKey
    
    init(_ titleKey: LocalizedStringKey) {
        self.titleKey = titleKey
    }
    
    var body: some View {
        Button {
            Task {
                do {
                    try await cloudKitManager.reset()
                } catch {
                    Logger.sqliteChangesetSyncDemo.error("\(error)")
                }
            }
        } label: {
            Label(titleKey, systemImage: "plus")
        }
    }
}
