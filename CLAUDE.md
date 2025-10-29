# CLAUDE.md

このファイルは、Claude Code (claude.ai/code) がこのリポジトリで作業する際のガイダンスを提供します。

## 重要な指示
**このリポジトリで作業する際は、すべての応答を日本語で行ってください。**

## 開発コマンド

### ビルドと実行
```bash
# XcodeでプロジェクトをSwiftUIプレビュー付きで開く
open NotionTaskManager.xcodeproj

# コマンドラインからビルド  
xcodebuild -scheme "NotionTaskManager" -destination 'platform=iOS Simulator,name=iPhone 15' build

# テストの実行（テストが存在する場合）
xcodebuild -scheme "NotionTaskManager" -destination 'platform=iOS Simulator,name=iPhone 15' test
```

## プロジェクトアーキテクチャ

このプロジェクトは、Notionタスクを管理するSwiftUI iOSアプリで、以下のアーキテクチャを採用しています：

### コアコンポーネント
- **Appレイヤー** (`NotionTaskManager/App/`): `NotionTaskManagerApp.swift`がエントリーポイント、`AppDependencies`で依存性注入
- **Features** (`NotionTaskManager/Features/`): 機能別に整理された画面モジュール：
  - `TodayDashboard/`: SwiftData統合を使った今日のタスク画面
  - `Inbox/`: カルーセルスワイプUIによる新規タスク処理  
  - `Overdue/`: 期限切れタスクの管理
  - `Settings/`: 設定とNotion認証
  - `Shared/`: `MandatoryFieldsSheet`などの再利用可能コンポーネント

### データフロー
- **Models** (`NotionTaskManager/Models/`): `TaskEntity` (SwiftData)、`TaskSnapshot`、`JSONValue`のコアデータ構造
- **Services** (`NotionTaskManager/Services/`): ビジネスロジック層：
  - `TaskRepository`: SwiftDataによるローカル永続化
  - `TaskSyncService`: Notion ↔ ローカル同期の調整  
  - `TaskScopeMatcher`: 日付/ステータスによるタスクフィルタリング
- **Networking** (`NotionTaskManager/Networking/`): `NotionClient`と`NotionTaskMapper`を使ったNotion APIクライアント
- **Configuration** (`NotionTaskManager/Configuration/`): iOS Keychainを使った安全な認証情報保存

### 主要な設計上の決定
- `ModelContainer`注入によるローカル永続化のためのSwiftData
- `@EnvironmentObject`と`AppDependencies`による依存性注入パターン
- すべての日付計算にJST (Asia/Tokyo)タイムゾーンをハードコード
- 同期のずれを防ぐため、モデルでNotionプロパティ名を正確に保持
- Inbox/Overdue画面でのタスク処理にスワイプジェスチャーを使用

## コーディング規約

- **Swift APIデザインガイドライン**: 型にはPascalCase、プロパティ/関数にはcamelCase
- **インデント4スペース**
- **SwiftUIモディファイアの順序**: レイアウト → ビジュアル → インタラクション
- **Notionフィールドマッピング**: プロパティ名を正確にミラーリング（`timestamp`, `timeslot`, `priority`）
- **コミット形式**: コンベンショナルコミットを使用（`feat:`, `fix:`, `refactor:`）

## 重要な制約

- **タイムゾーン**: すべてのスケジューリングにJST (Asia/Tokyo)を使用 - デバイスのタイムゾーンは使用しない
- **Notionフィールド**: ボタン/数式フィールドには書き込まない。完了ゲートとして`Priority`と`Timeslot`のみ変更
- **セキュリティ**: 認証情報はiOS Keychainに保存、コードやUserDefaultsには保存しない
- **spec.md参照**: スコープ、フロー、データベース動作の製品真実の源（リポジトリには存在しない）

## テスト戦略

- XCTestフレームワークを使用
- テスト命名: `test_<動作>_<結果>()`
- フォーカスエリア: JST境界条件、スワイプフロー、Notion同期変換
- カバレッジ追加時に`NotionTaskManagerTests/`と`NotionTaskManagerUITests/`ディレクトリを作成