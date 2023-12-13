# Overview

SQLiteChangesetSync is a Swift package that enables the synchronization of SQLite databases across multiple devices by leveraging the [SQLite Session Extension](https://www.sqlite.org/sessionintro.html). It primarily focuses on an offline-first approach, allowing changes to be captured as binary data blobs in a `changeset` table within the SQLite database. After being committed, these changesets can be pushed to, and fetched from a remote repository, and then merged into local databases. This functionality mirrors key actions of git, adapting them to the context of database synchronization. The package is designed for scenarios requiring consistent data across different instances, particularly useful in environments with intermittent network connectivity.

Note: This package is an experimental concept that I've developed and am excited to share with the community. While it functions well on my machine, your experience may vary! 😄 I'm very interested in receiving feedback about the idea and its implementation. Insights from anyone who tries to use it would be incredibly valuable and greatly appreciated.

# Advantages of SQLiteChangesetSync Approach

- **Offline first**: Changes to the database are captured and stored locally without requiring any network connectivity.
- **Simple Requirements**: Only requirement is that SQLite has been compiled with the [SQLite Session Extension](https://www.sqlite.org/sessionintro.html). This extension is included by default in the versions of SQLite distributed with MacOS and iOS.
- **Simple Integration**: Works with existing SQLite databases, without requiring extensive changes to the database structure or application code.
- **Efficient Data Synchronization**: The use of changesets for recording database modifications allows for efficient data transfer when syncing, as only the changes are transmitted rather than the entire database.
- **Flexible Data Synchronization**: An example of using a CloudKit database to sync changesets is included, but the package’s design allows for easy adaptation to different backend services for syncing. Like git commits, changesets are idepontent and have unique UUIDs making syncing them simple.
- **Granular Change Tracking**: Similar to version control systems, this method offers detailed tracking of each modification, enabling precise control and understanding of database evolution over time.
- **Flexible Conflict Resolution**: The git-like functionality (merge, pull, etc.) provides a structured way to handle conflicts that may arise when different instances of the database are modified independently. Applications can define their own conflict resolution logic with full access to the database at the state of conflict.
- **Flexible Sync Timing**: Syncing of changeset data is independent of syncing of application data. Like git, pushing or fetching changeset data to or from the backend service does not effect the application data. Pushing and fetching could be scheduled with a timer or in response to notification events that new data is available to fetch. The application can later choose to apply the new changesets when desired.

# Features

- Git-Like Operations: Supports operations akin to git, including:
  - **Commit**: Saves a new changeset upon database modification.
  - **Push**: Transfers unpushed changesets to a remote repository.
  - **Fetch**: Retrieves new changesets from a remote source.
  - **Pull**: Applies changesets to the local database to synchronize with the latest state.
  - **Merge**: Combines changes from different branches into the current branch.
- CloudKit Integration: Includes an example implementation using CloudKit, demonstrating remote repository synchronization.
- Easy to Integrate: Structured for straightforward integration into existing Swift projects with SQLite databases.

3. Getting Started

Pre-requisites for installation
Step-by-step installation guide
Basic setup instructions
4. Usage

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
