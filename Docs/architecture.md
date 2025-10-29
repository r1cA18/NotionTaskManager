# Architecture Draft

## Layers
- App entry composes `AppState` observable object injected into feature views via environment.
- Data layer exposes `NotionTaskRepository` protocol backed by `NotionClient` (network) and `TaskCacheStore` (SwiftData mirror).
- Feature layer split by scenes: TodayDashboard, CardCarousel, Calendar, DetailEditor, Settings.

## Persistence
- SwiftData schema with `TaskEntity`, `TagEntity`, `ProjectEntity`; mirrors Notion IDs and timestamps; store in default container with iCloud sync disabled.
- Cache refresh flow: on launch load from SwiftData, then fetch delta from Notion API filtering on updated time, merge and persist.

## Configuration
- `AppSettings` struct saved via `AppStorage` for db id + staging flags; `SecureTokenStore` wraps Keychain for Notion token.
- Settings view surfaces text fields and validation for both values; network calls gated until credentials exist.

## Networking
- `NotionClient` uses official REST endpoints (`/v1/databases/<db_id>/query`, `/v1/pages/<page_id>` updates) with `Notion-Version` header.
- Decoding relies on typed structs for select/status enums aligned with spec Section 4; ensure conversions between Notion multi-select and local models.

## UI Overview
- TodayDashboard sections: Inbox, Overdue (Yesterday), Today Unscheduled; each uses `TaskCardView` with swipe gestures hooking into `ui.command` logic.
- FAB visibility derived from repository query counts; navigation via `NavigationStack`. Modal flows for completion requirements and detail edits.

## Testing
- XCTest bundle targets repository merging, timezone helpers, swipe rule enforcement; leverage sample JSON in `Tests/Fixtures` to cover JST boundaries.

## Next Milestones
- Ship swipe workflows: build CardCarousel scene, enforce completion modal, and wire Notion PATCH requests for right/left swipe actions.
- Add detail editing modal plus validation for priority/timeslot requirements before completion.
- Finish Notion query delta logic (filter by last_edited_time, pagination) and persist sync cursors.
- Expand automated tests for repository filters, mapper conversions, and sync error handling.
- Harden offline strategy: queued mutations, retry policies, and user-facing conflict resolution prompts.

## Open Questions
- Should we support multi-database selection or strictly one DB_TASKS ID per environment?
- How should API errors surface in the UI beyond inline alert (global banner, toast, etc.)?
- Preferred strategy for offline merge conflicts (auto resolve vs. user prompts) per spec §7?
