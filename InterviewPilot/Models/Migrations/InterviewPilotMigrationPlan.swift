import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    /// Every `@Model` type the app persists MUST appear here. SwiftData silently
    /// excludes models missing from this list, which surfaces only as
    /// "no such table" runtime errors on first write — verify on every new model.
    static var models: [any PersistentModel.Type] {
        [InterviewSession.self]
    }
}

enum InterviewPilotMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
