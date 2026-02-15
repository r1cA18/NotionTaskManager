# NotionTaskManager

Notionのタスクデータベースと連携するiOS向けタスク管理アプリ。SwiftUIで構築し、ローカルキャッシュとNotion同期を組み合わせることで、オフラインでも快適に使える。

---

## 主な機能

### 日付ナビゲーション

- カレンダーポップアップによる日付選択
- 横スクロールスライダーで素早く日付を切り替え
- カレンダーボタン長押しで今日に即座に戻る
- スワイプ時に最も近い日付へ自動スナップ

### タスク管理

- 今日のタスクを時間帯と優先度でグループ表示
- Todo / 完了タブの切り替え
- 進行中タスクを画面下部に表示、スワイプで完了・キャンセル

### スワイプ操作

- Inbox: 新着タスクをカルーセルUIでトリアージ
- Overdue: 期限切れタスクをまとめて処理
- タスクカードを左右スワイプで操作

### 同期

- Notion APIとの双方向同期
- ローカルキャッシュでオフライン対応
- Pull-to-Refreshで手動同期
- ネットワーク復旧時に自動リトライ

### デザイン

- Liquid Glassデザインシステム
- Springアニメーションによる自然なインタラクション

### セキュリティ

- 認証情報はiOS Keychainに保存
- HTTPS通信のみ

---

## セットアップ

### 前提条件

- macOS 14.0以上
- Xcode 15.0以上
- iOS 17.0以上

### プロジェクトを開く

```bash
open NotionTaskManager.xcodeproj
```

`NotionTaskManager` スキームを選択してiPhoneシミュレータで実行する。

### Notion連携の設定

#### 1. Notionインテグレーションを作成

1. [Notion My Integrations](https://www.notion.so/my-integrations) にアクセス
2. 「新しいインテグレーション」を作成
3. 権限を設定: Read content / Update content / Insert content
4. トークンを取得

#### 2. データベースを共有

1. タスク管理用のNotionデータベースを用意
2. データベースページの「接続」から作成したインテグレーションを選択
3. URLからデータベースIDを取得

#### 3. アプリで設定

設定画面から以下を入力:

- インテグレーショントークン
- データベースID
- APIバージョン: `2022-06-28`（デフォルト）

認証情報はKeychainに保存される。

---

## プロジェクト構成

```
NotionTaskManager/
├── App/                          # エントリーポイント、依存性注入
│   ├── NotionTaskManagerApp.swift
│   ├── RootView.swift
│   └── AppDependencies.swift
│
├── Features/                     # 機能モジュール
│   ├── DateNavigation/           # 日付ナビゲーション
│   ├── TodayDashboard/           # 今日のタスク
│   ├── Inbox/                    # 新着タスク処理
│   ├── Overdue/                  # 期限切れタスク
│   ├── Settings/                 # 設定
│   └── Shared/                   # 共通コンポーネント
│
├── Services/                     # ビジネスロジック
│   ├── TaskRepository.swift      # SwiftDataによるローカル永続化
│   ├── TaskSyncService.swift     # Notion同期
│   ├── TaskScopeMatcher.swift    # タスクフィルタリング
│   ├── SyncOperationQueue.swift  # 非同期操作キュー
│   └── NetworkMonitor.swift      # ネットワーク監視
│
├── Networking/                   # API通信
│   ├── NotionClient.swift
│   └── NotionTaskMapper.swift
│
├── Models/                       # データモデル
│   ├── TaskEntity.swift          # SwiftDataモデル
│   ├── TaskSnapshot.swift
│   └── JSONValue.swift
│
├── Configuration/                # 設定・認証
│   ├── NotionCredentialsStore.swift
│   ├── SecureTokenStore.swift
│   └── AppSettingsStore.swift
│
└── Support/                      # ユーティリティ
    ├── DateBoundaries.swift
    ├── DateRange.swift
    └── MonthDateRange.swift
```

---

## 技術スタック

- SwiftUI / SwiftData
- Swift 5.9+
- MVVM + Repository Pattern
- URLSession + async/await
- Keychain Services
- JST (Asia/Tokyo) 固定の日付処理

---

## 開発

### ビルド

```bash
open NotionTaskManager.xcodeproj

xcodebuild -scheme "NotionTaskManager" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

### コーディング規約

- Swift API Design Guidelines 準拠（型名: PascalCase、変数・関数: camelCase）
- インデント: 4スペース
- コミットメッセージ: Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`)

### タイムゾーン

全てのスケジュール計算と日付処理はJST (Asia/Tokyo) で行う。デバイスのタイムゾーン設定には依存しない。

### セキュリティ上の注意

- 認証トークンやデータベースIDをコミットしない
- 機密情報は `.gitignore` に追加する

---

## ライセンス

未定
