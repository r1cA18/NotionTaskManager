# Requirements Document

## Introduction

NotionTaskManagerアプリにおいて、タスクリフレッシュのパフォーマンス改善と日付ナビゲーション機能を追加します。現在はTodayビューのみですが、任意の日付のタスクを閲覧できるようにし、ユーザーが快適にタスクを管理できる体験を提供します。

## Glossary

- **System**: NotionTaskManagerアプリケーション
- **User**: iPhoneでアプリを使用するエンドユーザー
- **Notion API**: タスクデータを取得・更新するための外部API
- **Task Refresh**: Notion APIからタスクデータを取得してローカルキャッシュを更新する処理
- **Bookmark Fetch**: 各タスクページ内のブックマークURLを取得する処理
- **Date Selector**: 日付を選択するための水平スクロールUI
- **Calendar Popup**: 日付を選択するためのカレンダー形式のモーダル
- **Pull-to-Refresh**: 画面を下にスワイプしてリフレッシュを実行する操作
- **Refresh Button**: ツールバーにあるリフレッシュを実行するボタン
- **JST**: 日本標準時（Asia/Tokyo）

## Requirements

### Requirement 1: リフレッシュパフォーマンスの改善

**User Story:** As a User, I want task refresh to complete quickly, so that I can see updated tasks without waiting.

#### Acceptance Criteria

1. WHEN THE User triggers a refresh, THE System SHALL fetch task data from Notion API within 3 seconds for up to 100 tasks
2. WHEN THE System fetches bookmark URLs, THE System SHALL execute bookmark fetches in parallel with a maximum concurrency of 5 requests
3. WHEN THE System encounters a bookmark fetch failure, THE System SHALL continue processing remaining tasks without blocking the entire refresh operation
4. WHEN THE User triggers pull-to-refresh, THE System SHALL display a loading indicator until the refresh operation completes
5. WHEN THE System completes a refresh operation, THE System SHALL update the UI with the latest task data within 500 milliseconds

### Requirement 2: 日付選択UIの実装

**User Story:** As a User, I want to select different dates to view tasks, so that I can see tasks scheduled for any day.

#### Acceptance Criteria

1. WHEN THE User opens the app, THE System SHALL display today's date in JST as the initially selected date
2. WHEN THE User views the main screen, THE System SHALL display the currently selected date in large text at the top of the screen
3. WHEN THE User swipes horizontally on the date selector, THE System SHALL scroll through dates with smooth animation
4. WHEN THE User releases their finger after scrolling, THE System SHALL snap the nearest date to the center position within 300 milliseconds
5. WHEN THE date selector snaps to a new date, THE System SHALL load and display tasks for that date
6. WHERE THE User has scrolled the date selector, THE System SHALL display dates for 30 days before and 30 days after the current date

### Requirement 3: カレンダーポップアップの実装

**User Story:** As a User, I want to open a calendar to quickly jump to a specific date, so that I can navigate to distant dates efficiently.

#### Acceptance Criteria

1. WHEN THE User taps on the large date display, THE System SHALL present a calendar popup within 200 milliseconds
2. WHEN THE calendar popup is displayed, THE System SHALL highlight the currently selected date
3. WHEN THE User selects a date in the calendar, THE System SHALL dismiss the calendar and navigate to the selected date
4. WHEN THE User dismisses the calendar without selecting a date, THE System SHALL maintain the previously selected date
5. WHEN THE calendar is displayed, THE System SHALL show dates for the current month and allow navigation to adjacent months

### Requirement 4: 日付ごとのタスク表示

**User Story:** As a User, I want to see tasks filtered by the selected date, so that I can focus on tasks relevant to that day.

#### Acceptance Criteria

1. WHEN THE User selects a date, THE System SHALL display tasks where Timestamp equals the selected date in JST
2. WHEN THE User selects a date, THE System SHALL display completed tasks where EndTime falls on the selected date in JST
3. WHEN THE User selects a date, THE System SHALL display in-progress tasks where StartTime falls on the selected date in JST
4. WHEN THE System displays tasks for a selected date, THE System SHALL group To Do tasks by Timeslot in the order Morning, Forenoon, Afternoon, Evening, Unscheduled
5. WHEN THE System displays completed tasks for a selected date, THE System SHALL sort them by EndTime in descending order

### Requirement 5: リフレッシュ動作の明確化

**User Story:** As a User, I want to understand the difference between refresh button and pull-to-refresh, so that I can choose the appropriate refresh method.

#### Acceptance Criteria

1. WHEN THE User taps the refresh button, THE System SHALL fetch fresh data from Notion API and update the local cache
2. WHEN THE User performs pull-to-refresh, THE System SHALL fetch fresh data from Notion API and update the local cache
3. WHEN THE System is already performing a refresh operation, THE System SHALL ignore additional refresh requests until the current operation completes
4. WHEN THE refresh button is tapped, THE System SHALL replace the button with a loading spinner until the operation completes
5. WHEN THE System completes a refresh operation with errors, THE System SHALL display an error alert with the error message

### Requirement 6: キャッシュとリフレッシュ戦略

**User Story:** As a User, I want to see the most up-to-date tasks from Notion, so that I can trust the information displayed in the app.

#### Acceptance Criteria

1. WHEN THE User opens the app, THE System SHALL immediately fetch fresh data from Notion API
2. WHEN THE User selects a date, THE System SHALL display cached tasks within 300 milliseconds while fetching fresh data in the background
3. WHEN THE background refresh completes, THE System SHALL update the displayed tasks within 500 milliseconds
4. WHEN THE System successfully fetches fresh data, THE System SHALL update the local cache with the new data
5. WHEN THE System has no cached data for a selected date, THE System SHALL display a loading indicator until fresh data is fetched and cached

### Requirement 7: エラーハンドリングの改善

**User Story:** As a User, I want clear error messages when refresh fails, so that I can understand what went wrong and take appropriate action.

#### Acceptance Criteria

1. WHEN THE Notion API returns an HTTP error, THE System SHALL display an alert with the HTTP status code and error message
2. WHEN THE network connection is unavailable, THE System SHALL display an alert indicating no network connection
3. WHEN THE Notion credentials are missing or invalid, THE System SHALL display an alert prompting the user to check settings
4. WHEN THE System encounters a timeout during refresh, THE System SHALL display an alert indicating the operation timed out
5. WHEN THE System displays an error alert, THE System SHALL provide a dismiss button to close the alert

