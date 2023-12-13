t# Overview

SQLiteChangesetSync is a Swift package that enables the synchronization of SQLite databases across multiple devices by leveraging the [SQLite Session Extension](https://www.sqlite.org/sessionintro.html). It primarily focuses on an offline-first approach, allowing changes to be captured as binary data blobs in a `changeset` table within the SQLite database. After being committed, these changesets can be pushed to, and fetched from a remote repository, and then merged into local databases. This functionality mirrors key actions of git, adapting them to the context of database synchronization. The package is designed for scenarios requiring consistent data across different instances, particularly useful in environments with intermittent network connectivity.

_Note_: This package is an experimental concept that I've developed and am excited to share with the community. While it functions well on my machine, your experience may vary! 😄 I'm very interested in receiving feedback about the idea and its implementation. Insights from anyone who tries to use it would be incredibly valuable and greatly appreciated.

# Advantages of SQLiteChangesetSync Approach

- **Offline first**: Changes to the database are captured and stored locally without requiring any network connectivity.
- **Simple Requirements**: Only requirement is that SQLite has been compiled with the [SQLite Session Extension](https://www.sqlite.org/sessionintro.html). This extension is included by default in the versions of SQLite distributed with MacOS and iOS.
- **Simple Integration**: Works with existing SQLite databases, without requiring modifications to the existing database structure or extensive changes to the application code.
- **Efficient Data Synchronization**: The use of changesets for recording database modifications allows for efficient data transfer when syncing, as only the changes are transmitted rather than the entire database.
- **Flexible Data Synchronization**: An example of using a CloudKit database to sync changesets is included, but the package’s design allows for easy adaptation to different backend services for syncing. Like git commits, changesets are idepontent and have unique UUIDs making syncing them simple.
- **Flexible Sync Timing**: Syncing of changeset data is independent of syncing of application data. Like git, pushing or fetching changeset data to or from the backend service does not effect the application data. Pushing and fetching could be scheduled with a timer or in response to notification events that new data is available to fetch. The application can later choose to apply the new changesets when desired.
- - **Granular Change Tracking**: Similar to version control systems, this method offers detailed tracking of each modification, enabling precise control and understanding of database evolution over time.
- **Flexible Conflict Resolution**: The git-like functionality (merge, pull, etc.) provides a structured way to handle conflicts that may arise when different instances of the database are modified independently. Applications can define their own conflict resolution logic with full access to the database at the state of conflict.

# Running the Demo

A demo iOS app `SQLiteChangesetSyncDemo` is included in the package. To enable CloudKit support, edit the `CloudKitConfig` settings in `SQLiteChangesetSyncDemoApp.swift`. The app UI is basic not "responsive", so please watch the app log to see the results of each operation. There are two targets in the project `SQLiteChangesetSyncDemoApp` and `SQLiteChangesetSyncDemoAppCopy". It is possible to run each target on a separate simulator and experiment with syncing data between the two instances.

The demo depends on the [GRDB](https://github.com/groue/GRDB.swift) and [GRDBQuery](https://github.com/groue/GRDBQuery) packages.

## Operations

- **Push**: Transfers unpushed changesets to a remote repository.
- **Fetch**: Retrieves new changesets from a remote source. 
- **Pull**: Applies changesets saved in the local database to the application data synchronizing with the latest state. _Note:_ Unlike git, the pull command does not run a fetch first. To sync new data, run fetch before pull.
- **Merge**: Combines changes from different branches into the current branch

# Implementing in your own Project

## Requirements

- `@available(iOS 14.0, *)` for ChangeSetRepository
- `@available(iOS 15.0, *)` for CloudKitManager
- SQLite that has been compiled with the [SQLite Session Extension](https://www.sqlite.org/sessionintro.html). Should be the default in MacOS and iOS. To check your version, run `PRAGMA compile_options` and confirm that both `ENABLE_SESSION` and `ENABLE_PREUPDATE_HOOK` are included.

## Package Dependencies

- [GRDB](https://github.com/groue/GRDB.swift) For ease of implementation, `GRDB` is used for database operations. _NOTE_: `GRDB` is not a strict requirement and a version of the package could be developed without depending on `GRDB` and using low-level SQLite functions instead.

## Integrating in your Project

The best place to understand how to integrate the package is by reviewing the included demo app `SQLiteChangesetSyncDemo`. Roughly, to get started, add the following to your APP init:

```
            self.changesetRepository = try ChangesetRepository(dbWriter)
            self.cloudKitManager = CloudKitManager(dbWriter, config: SQLiteChangesetSyncDemo.getCloudKitManagerConfig())
            self.playerRepository = try PlayerRepository(changesetRepository)

```

and then pass them to your views as enviroment objects like this:

```
                .environment(\.changesetRepository, changesetRepository)
                .environment(\.cloudKitManager, cloudKitManager)
                .environment(\.playerRepository, playerRepository)
```

finally, modify all `database.write()` calls to use `changesetRepository.commit()` instead:

```
        return try changesetRepository.commit { db in
            try player.inserted(db)
        }
```

How to implement SQLiteChangesetSync in a project
Code snippets and examples
Explanation of key functions (commit, push, fetch, pull, merge)
5. How It Works

Technical explanation of the underlying mechanisms
Description of the SQLite Session Extension and changeset handling
Flow diagrams or architecture charts (if applicable)
6. Example Project

Description of an example project (e.g., using CloudKit)
Instructions on how to run the example
Screenshots or code snippets for clarity
7. API Reference

- [ ] TODOS
Detailed documentation of the API endpoints
Parameters and return types for each function/method
8. Contributing

Guidelines for contributing to the project
How to submit issues or pull requests
Code of conduct and contact information
9. License

License information for the package
10. FAQ

Answers to commonly asked questions
Troubleshooting tips
11. Acknowledgements

Credits to contributors and acknowledgments
12. Contact Information

Ways to reach out for support or inquiries
