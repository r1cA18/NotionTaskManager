# Repository Guidelines

## Project Structure & Module Organization
- Core SwiftUI sources live in `NotionTaskManager/`, anchored by `NotionTaskManagerApp.swift` and `ContentView.swift`.
- UI assets reside in `NotionTaskManager/Assets.xcassets`; keep colors and symbols aligned with the spec overlays.
- `spec.md` is the product source of truth—treat it as the contract for scopes, flows, and database behavior.
- The Xcode project file `NotionTaskManager.xcodeproj` defines build targets; keep any new bundles or schemes inside this project.

## Build, Test, and Development Commands
- `open NotionTaskManager.xcodeproj` launches the workspace in Xcode for SwiftUI previews and editing.
- `xcodebuild -scheme "NotionTaskManager" -destination 'platform=iOS Simulator,name=iPhone 15' build` validates that the app compiles headlessly.
- `xcodebuild -scheme "NotionTaskManager" -destination 'platform=iOS Simulator,name=iPhone 15' test` runs unit and UI tests once they exist; keep simulators up to date via Xcode.

## Coding Style & Naming Conventions
- Follow Swift API Design Guidelines: PascalCase for types, camelCase for properties/functions, SCREAMING_SNAKE_CASE for constants.
- Use 4-space indentation and group SwiftUI modifiers logically (layout ➝ visuals ➝ interactions) with sparse inline comments for non-obvious behavior.
- Mirror Notion property names exactly when bridging to models (e.g., `timestamp`, `timeslot`, `priority` enums) to avoid sync drift.
- Keep view structs lightweight; move formatting and networking helpers into dedicated files under `NotionTaskManager/` as modules grow.

## Testing Guidelines
- Target XCTest; create `NotionTaskManagerTests/` and `NotionTaskManagerUITests/` sibling folders when adding coverage.
- Name tests with `test_<Behavior>_<Outcome>()`, focusing on JST boundary conditions, swipe flows, and Notion sync transforms described in `spec.md`.
- Prefer simulator automation (XCTest or ViewInspector) for swipe gestures and modal enforcement; document any fixtures under `Tests/Fixtures/`.

## Commit & Pull Request Guidelines
- Git history is not yet established—use Conventional Commits (`feat:`, `fix:`, `refactor:`) to signal intent and scope from the outset.
- Every PR should reference the relevant spec clause, note simulator/device coverage, and include screenshots or screen recordings for UI-affecting changes.
- Keep diffs focused; separate mechanical refactors from behavioral updates, and mention any new environment variables or secrets in the PR description.

## Agent & Configuration Notes
- Maintain JST alignment for all scheduling logic; hardcode `Asia/Tokyo` defaults unless the spec introduces overrides.
- Never write to Notion button/formula fields; gate completion on `Priority` and `Timeslot` as mandated.
- When onboarding new agents, start from `spec.md` Section 10 for tool contracts and Section 12 for validation checklists.
