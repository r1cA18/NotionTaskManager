# NotionTaskManager 機能一覧

## 概要

NotionTaskManagerは、Notion APIと連携してタスクを管理するiOS SwiftUIアプリケーションです。ローカルキャッシュとNotion同期を組み合わせ、オフライン対応と高速なUI応答を実現しています。

---

## 画面・機能モジュール

### 1. Today Dashboard（今日のタスク管理画面）

**概要**: 今日のタスクを一覧表示・管理するメイン画面

| 機能 | 説明 |
|------|------|
| TODOタブ表示 | 今日のTODOタスクをTimeSlot別（Morning/Forenoon/Afternoon/Evening）にグループ化して表示 |
| 完了タブ表示 | 今日完了したタスクを表示 |
| タブ切り替え | Pickerで「TODO」「完了」を切り替え |
| InProgressタスク表示 | 現在進行中のタスクをピル形式で表示 |
| タスク開始 | タップでタスクをIn Progress状態に変更 |
| タスク完了 | スワイプまたはタップで完了処理 |
| タスクキャンセル | 進行中タスクをキャンセルしてTODOに戻す |
| タスク編集 | シートでタスク詳細を編集 |
| Floating Action Button | Inbox/Overdueタスク数を表示、タップで各画面へ遷移 |
| Pull to Refresh | 下に引いてNotion同期を実行 |

### 2. Inbox（新規タスク処理画面）

**概要**: 未分類のタスクをカルーセルUIで処理

| 機能 | 説明 |
|------|------|
| カルーセル表示 | 未分類タスクをカード形式で1枚ずつ表示 |
| スワイプナビゲーション | 左右スワイプで次/前のタスクに移動 |
| タスク割り当て | Priority/Timeslotを設定してNextActionに変換 |
| スキップ | 現在のタスクをキュー末尾に移動 |
| 削除（Trash） | タスクをTrash状態に変更 |
| MandatoryFieldsSheet | Priority/Timeslot選択必須のモーダル |
| タスク詳細編集 | エディタシートでフィールド編集 |

**Inbox対象条件**:
- Status = To Do
- Type = 未設定
- NoteType = 未設定

### 3. Overdue（期限切れタスク画面）

**概要**: 期限切れタスクをカルーセルUIで処理

| 機能 | 説明 |
|------|------|
| カルーセル表示 | 期限切れタスクをカード形式で表示 |
| リスケジュール | Timestampを更新して今日または将来の日付に設定 |
| 完了処理 | タスクを完了状態に変更 |
| 削除 | タスクをTrash状態に変更 |

**Overdue対象条件**:
- Status = To Do または In Progress
- Timestamp < 今日
- Type ≠ Waiting, Trash

### 4. Date Navigation（日付ベースタスク表示）

**概要**: 任意の日付のタスクを表示

| 機能 | 説明 |
|------|------|
| 日付選択 | カレンダーポップアップで日付を選択 |
| 日付別タスク表示 | 選択した日付のタスクを全スコープで表示 |
| キャッシュ優先読み込み | ローカルキャッシュを即座表示、バックグラウンドで同期 |

### 5. Settings（設定画面）

**概要**: アプリ設定とNotion認証管理

| 機能 | 説明 |
|------|------|
| Notion認証設定 | APIトークンの入力・保存 |
| Database ID設定 | 対象NotionデータベースIDの設定 |
| 認証情報クリア | 保存済み認証情報の削除 |

---

## データモデル

### TaskEntity（SwiftData永続化モデル）

| フィールド | 型 | 説明 |
|-----------|-----|------|
| notionID | String | Notion Page ID（ユニーク） |
| name | String | タスク名 |
| status | TaskStatus | To Do / In Progress / Complete |
| timestamp | Date? | スケジュール日（JST） |
| timeslot | TaskTimeslot? | Morning / Forenoon / Afternoon / Evening |
| priority | TaskPriority? | ★の数で優先度表現 |
| type | TaskType? | NextAction / Someday / Waiting / Trash |
| startTime | Date? | 開始時刻 |
| endTime | Date? | 完了時刻 |
| deadline | Date? | 締切日 |
| memo | String? | メモ |
| url | URL? | 関連URL |
| bookmarkURL | URL? | Notion内ブックマーク |
| projectIDs | [String] | 関連プロジェクトID |
| articleGenres | [String] | 記事ジャンル（MultiSelect） |
| permanentTags | [String] | 固定タグ（MultiSelect） |
| createdAt | Date | 作成日時 |
| updatedAt | Date | 更新日時 |

### 列挙型

| 型 | 値 |
|-----|-----|
| TaskStatus | toDo, inProgress, complete |
| TaskTimeslot | morning, forenoon, afternoon, evening |
| TaskPriority | ★, ★★, ★★★, ★★★★ |
| TaskType | nextAction, someday, waiting, trash |
| TaskScope | inbox, todayTodo, todayCompleted, inProgress, overdue |

---

## サービス層機能

### TaskRepository（データ永続化）

| 機能 | 説明 |
|------|------|
| fetchTasks | スコープ・日付でフィルタリングしてタスク取得 |
| upsert | Notionデータをローカルに保存/更新 |
| startTask | タスクをIn Progress状態に変更 |
| completeTask | タスクをComplete状態に変更 |
| cancelTask | 進行中タスクをTo Doに戻す |
| pruneTasks | 古いキャッシュを削除 |

### TaskSyncService（Notion同期）

| 機能 | 説明 |
|------|------|
| refresh | フルスコープ同期（Inbox + Overdue + 日付指定） |
| refreshDateOnly | 日付のみ同期 |
| startTask | 状態変更 + Notion更新 |
| completeTask | 完了処理 + Notion更新 |
| cancelTask | キャンセル + Notion更新 |
| trashTask | Trash状態に変更 + Notion更新 |
| convertToNextAction | NextActionに変換 + Notion更新 |
| updateTask | 汎用フィールド更新 + Notion更新 |

### SyncOperationQueue（非同期操作管理）

| 機能 | 説明 |
|------|------|
| 非同期キュー処理 | 複数のタスク更新を順次処理 |
| リトライ | 失敗時に指数バックオフでリトライ（最大2回） |
| 競合防止 | 同一タスクIDの操作を上書き管理 |
| ロールバック | 同期失敗時のローカル復元 |

---

## Notion API連携

### NotionClient

| API操作 | エンドポイント | 説明 |
|---------|---------------|------|
| queryDatabase | POST /databases/{id}/query | フィルタ付きタスク取得（ページング対応） |
| updatePage | PATCH /pages/{id} | タスクプロパティ更新 |
| fetchBlockChildren | GET /blocks/{id}/children | ブロック取得（ブックマークURL抽出） |
| firstBookmarkURL | - | ページ内最初のブックマークURL取得 |

### NotionTaskMapper

| 機能 | 説明 |
|------|------|
| snapshot | Notion APIレスポンスをTaskSnapshotに変換 |
| 日付パース | ISO8601 / yyyy-MM-dd形式をJSTで解析 |
| プロパティ抽出 | title, status, select, date, relation等の型別抽出 |

---

## UI/UXデザイン

### Liquid Glass デザインシステム

| コンポーネント | 説明 |
|---------------|------|
| GlassMaterial | ultraThin / thin / regular / thick / chrome |
| GlassBackground | マテリアル背景 + ボーダー + シャドウ |
| GlassButton | グラデーション浮動ボタン |
| GlassSegmentedPicker | アニメーション付きセグメントピッカー |

### カラースキーム（TaskPalette）

| Timeslot | アクセントカラー |
|----------|-----------------|
| Morning | Orange |
| Forenoon | Yellow |
| Afternoon | Blue |
| Evening | Purple |

### ジェスチャー

| ジェスチャー | 場所 | 動作 |
|-------------|------|------|
| 左スワイプ | Inbox/Overdue | 次のタスクへ |
| 右スワイプ | Inbox/Overdue | 前のタスクへ |
| スワイプアクション | InProgressRow | 完了/キャンセル |
| Pull to Refresh | TodayDashboard | Notion同期 |

---

## 制約・設計方針

### タイムゾーン
- **JST (Asia/Tokyo)固定**: デバイス設定に依存しない
- 全日付計算・Notionフィルタ生成でJST使用

### セキュリティ
- **Keychain**: 認証トークンを暗号化保存
- **UserDefaults**: Database ID等の非機密情報のみ

### 書き込み制限
- Priority / Timeslot / Status のみ変更可能
- Button / Formula フィールドには書き込まない

### キャッシュ戦略
- ローカルキャッシュを即座返却
- バックグラウンドでNotion同期
- 古いデータは自動削除（pruning）

---

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                    SwiftUI Views                            │
│  TodayDashboard | Inbox | Overdue | DateNavigation | Settings│
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
┌─────────────────┐ ┌──────────────┐ ┌──────────────┐
│   ViewModels    │ │TaskSyncService│ │TaskRepository │
└────────┬────────┘ └──────┬───────┘ └──────┬───────┘
         │                  │                │
         │         ┌────────▼────────┐       │
         │         │TaskScopeMatcher │       │
         │         └────────┬────────┘       │
         │                  │                │
         │         ┌────────▼────────┐       │
         │         │  NotionClient   │       │
         │         │NotionTaskMapper │       │
         │         └────────┬────────┘       │
         │                  │                │
         │      ┌───────────▼────────────┐   │
         │      │      Notion API        │   │
         │      └────────────────────────┘   │
         │                                   │
         └───────────────┬───────────────────┘
                         │
               ┌─────────▼─────────┐
               │    SwiftData DB   │
               └───────────────────┘
```

### パターン
- **MVVM**: View ↔ ViewModel ↔ Repository/Service
- **依存性注入**: AppDependenciesによる一元管理
- **リアクティブ**: Combine @Published + @EnvironmentObject
- **非同期処理**: async/await + TaskGroup

---

## ファイル構成

```
NotionTaskManager/
├── App/                          # アプリエントリーポイント
│   ├── NotionTaskManagerApp.swift
│   ├── AppDependencies.swift
│   └── RootView.swift
│
├── Features/                     # 機能モジュール
│   ├── TodayDashboard/
│   ├── Inbox/
│   ├── Overdue/
│   ├── DateNavigation/
│   ├── Settings/
│   └── Shared/
│
├── Models/                       # データモデル
│   ├── TaskEntity.swift
│   ├── TaskSnapshot.swift
│   └── JSONValue.swift
│
├── Services/                     # ビジネスロジック
│   ├── TaskRepository.swift
│   ├── TaskSyncService.swift
│   ├── TaskScopeMatcher.swift
│   ├── SyncOperationQueue.swift
│   └── TaskEditChanges.swift
│
├── Networking/                   # API通信
│   ├── NotionClient.swift
│   └── NotionTaskMapper.swift
│
├── Configuration/                # 設定管理
│   ├── AppSettingsStore.swift
│   ├── NotionCredentialsStore.swift
│   └── SecureTokenStore.swift
│
└── Support/                      # ユーティリティ
    ├── DateBoundaries.swift
    ├── DateRange.swift
    └── MonthDateRange.swift
```
