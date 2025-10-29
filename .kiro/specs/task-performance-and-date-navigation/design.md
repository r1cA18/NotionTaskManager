# Design Document

## Overview

本設計では、NotionTaskManagerアプリのタスクリフレッシュパフォーマンスを改善し、日付ナビゲーション機能を追加します。主な改善点は以下の通りです：

1. **並列ブックマーク取得**: 現在は各タスクのブックマークを順次取得していますが、並列化（最大5並列）することで大幅な高速化を実現
2. **日付選択UI**: 水平スクロール可能な日付セレクターとカレンダーポップアップを実装
3. **キャッシュファースト表示**: ユーザーが日付を選択した際、キャッシュから即座に表示しつつバックグラウンドで最新データを取得

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    DateNavigationView                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Large Date Display (Tappable)                       │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Horizontal Date Scroll (Snap to Center)             │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Todo / Completed Tabs                               │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Task List (Grouped by Timeslot)                     │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              DateNavigationViewModel                         │
│  - selectedDate: Date                                        │
│  - tasks: [TaskDisplayModel]                                 │
│  - isLoading: Bool                                           │
│  + selectDate(Date)                                          │
│  + refreshTasks()                                            │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  TaskSyncService                             │
│  + refresh(for: Date) async                                  │
│  + refreshWithParallelBookmarks(for: Date) async            │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                   NotionClient                               │
│  + queryDatabase(...) async                                  │
│  + fetchBlockChildren(...) async                             │
│  + firstBookmarkURL(...) async                               │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **アプリ起動時**:
   ```
   App Launch → DateNavigationView
              → ViewModel.selectDate(today)
              → TaskRepository.fetchTasks (cache)
              → Display cached tasks
              → TaskSyncService.refresh(today)
              → Update UI with fresh data
   ```

2. **日付選択時**:
   ```
   User scrolls date selector
   → Date snaps to center
   → ViewModel.selectDate(newDate)
   → TaskRepository.fetchTasks (cache) → Display immediately
   → TaskSyncService.refresh(newDate) → Update UI when complete
   ```

3. **リフレッシュボタン押下時**:
   ```
   User taps refresh button
   → Show loading spinner
   → TaskSyncService.refresh(selectedDate)
   → Parallel bookmark fetches (max 5 concurrent)
   → Update cache
   → Update UI
   → Hide loading spinner
   ```

## Components and Interfaces

### 1. DateNavigationView (New)

日付選択UIとタスク一覧を統合した新しいメインビュー。

```swift
struct DateNavigationView: View {
    @StateObject private var viewModel: DateNavigationViewModel
    @State private var showingCalendar = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Large date display (tappable)
            DateHeaderView(
                date: viewModel.selectedDate,
                onTap: { showingCalendar = true }
            )
            
            // Horizontal scrollable date selector
            DateSelectorView(
                selectedDate: $viewModel.selectedDate,
                onDateChanged: { date in
                    Task { await viewModel.selectDate(date) }
                }
            )
            
            // Todo/Completed tabs + Task list
            TaskListView(
                tasks: viewModel.tasks,
                isLoading: viewModel.isLoading
            )
        }
        .sheet(isPresented: $showingCalendar) {
            CalendarPopupView(
                selectedDate: viewModel.selectedDate,
                onDateSelected: { date in
                    showingCalendar = false
                    Task { await viewModel.selectDate(date) }
                }
            )
        }
    }
}
```

### 2. DateSelectorView (New)

水平スクロール可能な日付セレクター。中央にスナップする動作を実装。

```swift
struct DateSelectorView: View {
    @Binding var selectedDate: Date
    let onDateChanged: (Date) -> Void
    
    @State private var scrollOffset: CGFloat = 0
    private let dateRange: [Date] // ±30 days
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(dateRange, id: \.self) { date in
                    DateCell(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    )
                    .onTapGesture {
                        selectedDate = date
                        onDateChanged(date)
                    }
                }
            }
            .padding(.horizontal)
        }
        .scrollTargetBehavior(.viewAligned) // iOS 17+ snap behavior
    }
}
```

### 3. CalendarPopupView (New)

月表示のカレンダーポップアップ。

```swift
struct CalendarPopupView: View {
    let selectedDate: Date
    let onDateSelected: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            // Use native DatePicker in graphical style
            DatePicker(
                "Select Date",
                selection: .constant(selectedDate),
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .onChange(of: selectedDate) { _, newDate in
                onDateSelected(newDate)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
```

### 4. DateNavigationViewModel (New)

日付選択とタスク取得を管理するViewModel。

```swift
@MainActor
final class DateNavigationViewModel: ObservableObject {
    @Published var selectedDate: Date
    @Published var tasks: [TaskDisplayModel] = []
    @Published var isLoading = false
    @Published var lastError: String?
    
    private let repository: TaskRepositoryProtocol
    private let syncService: TaskSyncService
    
    init(repository: TaskRepositoryProtocol, syncService: TaskSyncService) {
        self.repository = repository
        self.syncService = syncService
        self.selectedDate = Self.todayInJST()
    }
    
    func selectDate(_ date: Date) async {
        selectedDate = date
        
        // Load from cache immediately
        do {
            tasks = try repository.fetchTasks(for: .todayTodo, on: date)
                .map(TaskDisplayModel.init)
        } catch {
            lastError = error.localizedDescription
        }
        
        // Refresh from Notion in background
        await syncService.refresh(for: date)
        
        // Update with fresh data
        do {
            tasks = try repository.fetchTasks(for: .todayTodo, on: date)
                .map(TaskDisplayModel.init)
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    func refreshTasks() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        await syncService.refresh(for: selectedDate)
        
        do {
            tasks = try repository.fetchTasks(for: .todayTodo, on: selectedDate)
                .map(TaskDisplayModel.init)
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    private static func todayInJST() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar.startOfDay(for: Date())
    }
}
```

### 5. TaskSyncService (Modified)

並列ブックマーク取得を実装。

```swift
extension TaskSyncService {
    func refreshWithParallelBookmarks(for date: Date) async {
        // ... existing query logic ...
        
        // Parallel bookmark fetching with max 5 concurrent requests
        await withTaskGroup(of: (Int, URL?).self) { group in
            for (index, snapshot) in mapped.enumerated() {
                guard snapshot.bookmarkURL == nil else { continue }
                
                // Limit concurrency to 5
                if group.isEmpty || await group.waitForNext() != nil {
                    group.addTask {
                        do {
                            let url = try await self.client.firstBookmarkURL(
                                credentials: credentials,
                                pageID: snapshot.notionID
                            )
                            return (index, url)
                        } catch {
                            return (index, nil)
                        }
                    }
                }
            }
            
            // Collect results
            for await (index, url) in group {
                if let url {
                    mapped[index].bookmarkURL = url
                }
            }
        }
        
        // ... existing upsert logic ...
    }
}
```

## Data Models

### DateRange

日付セレクターで表示する日付範囲を管理。

```swift
struct DateRange {
    let centerDate: Date
    let daysBeforeAndAfter: Int = 30
    
    var dates: [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        
        let start = calendar.date(byAdding: .day, value: -daysBeforeAndAfter, to: centerDate)!
        let end = calendar.date(byAdding: .day, value: daysBeforeAndAfter, to: centerDate)!
        
        var dates: [Date] = []
        var current = start
        while current <= end {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return dates
    }
}
```

### TaskDisplayModel (Existing)

既存のモデルをそのまま使用。変更なし。

## Error Handling

### 1. Network Errors

```swift
enum RefreshError: LocalizedError {
    case networkUnavailable
    case notionAPIError(statusCode: Int, message: String)
    case timeout
    case missingCredentials
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "ネットワーク接続がありません。接続を確認してください。"
        case .notionAPIError(let code, let message):
            return "Notion API エラー (\(code)): \(message)"
        case .timeout:
            return "リクエストがタイムアウトしました。もう一度お試しください。"
        case .missingCredentials:
            return "Notion認証情報が設定されていません。設定画面で確認してください。"
        }
    }
}
```

### 2. Error Display

```swift
.alert("同期エラー", isPresented: $showingError) {
    Button("閉じる", role: .cancel) {
        showingError = false
    }
    Button("設定を開く") {
        // Navigate to settings
    }
} message: {
    Text(viewModel.lastError ?? "不明なエラーが発生しました")
}
```

## Testing Strategy

### 1. Unit Tests

- `DateRange`: 日付範囲の生成が正しいか
- `DateNavigationViewModel`: 日付選択時のキャッシュ→リフレッシュフローが正しいか
- `TaskSyncService`: 並列ブックマーク取得が正しく動作するか

### 2. Integration Tests

- 日付選択→タスク表示の一連の流れ
- リフレッシュボタン→並列取得→UI更新
- エラー発生時のロールバック

### 3. UI Tests

- 日付セレクターのスクロール→スナップ動作
- カレンダーポップアップの表示→日付選択
- リフレッシュ中のローディング表示

### 4. Performance Tests

- 100タスクのリフレッシュが3秒以内に完了するか
- ブックマーク取得の並列化により、順次取得と比較して50%以上高速化されるか
- キャッシュからの表示が300ms以内に完了するか

## Design Decisions

### 1. なぜ並列ブックマーク取得を5並列に制限するのか？

- **理由**: Notion APIのレート制限（3 requests/second）を考慮し、かつiOSのネットワークリソースを過度に消費しないため
- **代替案**: 10並列も検討したが、レート制限に引っかかるリスクが高い
- **結論**: 5並列が最適なバランス

### 2. なぜキャッシュファーストではなく最新データ優先なのか？

- **理由**: ユーザーが「最新の情報を見たい」という要望を重視
- **実装**: キャッシュを即座に表示しつつ、バックグラウンドで必ず最新データを取得
- **結論**: UXとデータ鮮度の両立

### 3. なぜ日付範囲を±30日に制限するのか？

- **理由**: メモリ使用量とスクロールパフォーマンスのバランス
- **代替案**: 無限スクロールも検討したが、実装複雑度が高い
- **結論**: ±30日で十分なユースケースをカバー。必要に応じてカレンダーで遠い日付にジャンプ可能

### 4. なぜTodayDashboardViewを置き換えるのか？

- **理由**: 日付選択機能を追加するため、既存のTodayビューを拡張するよりも新しいビューを作成する方が設計がクリーン
- **移行**: TodayDashboardViewのロジックをDateNavigationViewModelに統合
- **結論**: 段階的に移行し、最終的にTodayDashboardViewを非推奨化

## Open Questions

1. **日付セレクターのスナップ動作**: iOS 17の`.scrollTargetBehavior`を使用するか、カスタム実装するか？
   - **提案**: iOS 17+を最小サポートバージョンとし、ネイティブAPIを使用

2. **カレンダーポップアップのデザイン**: ネイティブの`DatePicker`を使用するか、カスタムカレンダーを実装するか？
   - **提案**: まずはネイティブ`DatePicker`で実装し、必要に応じてカスタマイズ

3. **並列ブックマーク取得のエラーハンドリング**: 一部のブックマーク取得が失敗した場合、どう処理するか？
   - **提案**: 失敗したタスクはブックマークなしで表示し、エラーログに記録

