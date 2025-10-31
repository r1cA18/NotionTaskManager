# 📱 NotionTaskManager

> NotionのタスクをiPhoneで快適に管理するためのモダンなiOSアプリ

SwiftUIで構築された、美しく直感的なタスク管理アプリケーション。Notionデータベースとシームレスに同期し、日付ベースのナビゲーションとスワイプ操作で効率的にタスクを管理できます。

---

## ✨ 主な機能

### 📅 日付ナビゲーション
- **カレンダー統合**: 日付ヘッダーをタップしてカレンダーポップアップを表示
- **スライダー選択**: 横スクロールスライダーで日付を素早く選択
- **Todayクイックアクセス**: カレンダーボタンを長押しでTodayに即座に遷移
- **スムーズなスワイプ**: スライダーをスワイプすると自動的に最も近い日付にスナップ

### 📋 タスク管理
- **Todayダッシュボード**: 今日のタスクを時系列と優先度で整理
- **Todo/Completedタブ**: 未完了と完了済みタスクを切り替え表示
- **In Progress管理**: 進行中のタスクを画面下部に表示し、スワイプで完了・キャンセル

### 👆 直感的な操作
- **スワイプ操作**: タスクを左右にスワイプして簡単に処理
- **Inbox機能**: 新しいタスクをサクッと整理
- **期限切れ管理**: 期限が過ぎたタスクをまとめて確認

### 🔄 同期とパフォーマンス
- **高速同期**: 100タスクまで3秒以内で取得
- **並列処理**: ブックマークURL取得を最大5並列で実行
- **オフライン対応**: ローカルキャッシュでオフラインでも快適に利用
- **Pull-to-Refresh**: 下にスワイプして最新データを取得

### 🎨 モダンなUI/UX
- **Neumorphismデザイン**: 柔らかく立体感のあるモダンなデザイン
- **スムーズなアニメーション**: Springアニメーションで自然な動き
- **アクセシビリティ対応**: 音声読み上げとアクセシビリティラベルを完備

### 🔐 セキュリティ
- **Keychain統合**: 認証情報をiPhoneのKeychainに安全に保存
- **HTTPS通信**: すべての通信は暗号化

---

## 🚀 セットアップ

### 前提条件

- macOS 14.0以上
- Xcode 15.0以上
- iOS 17.0以上をターゲットとしたシミュレータまたは実機

### 1. プロジェクトを開く

```bash
open NotionTaskManager.xcodeproj
```

Xcodeで開いたら、`NotionTaskManager` スキームを選択してiPhoneシミュレータで実行してください。

### 2. Notionとの連携

アプリを使うには、Notionとの連携が必要です：

#### ステップ1: Notionインテグレーションを作成

1. [Notion My Integrations](https://www.notion.so/my-integrations) にアクセス
2. 「新しいインテグレーション」をクリック
3. 名前を入力（例: "Task Manager"）
4. 必要な権限を設定：
   - ✅ Read content
   - ✅ Update content
   - ✅ Insert content
5. 「送信」をクリックしてトークンを取得

#### ステップ2: データベースを共有

1. タスク管理用のNotionデータベースを作成
2. データベースページの右上の「...」メニューを開く
3. 「接続」→ 作成したインテグレーションを選択
4. データベースIDを取得（URLの末尾部分）

#### ステップ3: アプリで設定

1. アプリを起動して「設定」画面へ（右上の⚙️アイコン）
2. 以下を入力：
   - **インテグレーショントークン**: ステップ1で取得したトークン
   - **データベースID**: ステップ2で取得したID
   - **APIバージョン**: `2022-06-28`（デフォルト）

認証情報は安全にiPhoneのKeychainに保存されます。

---

## 📁 プロジェクト構成

```
NotionTaskManager/
├── App/                          # アプリの起動・設定
│   ├── NotionTaskManagerApp.swift
│   ├── RootView.swift
│   └── AppDependencies.swift
│
├── Features/                      # 機能別モジュール
│   ├── DateNavigation/           # 日付ナビゲーション機能 ⭐新機能
│   │   ├── DateNavigationView.swift
│   │   ├── DateNavigationViewModel.swift
│   │   └── Components/
│   │       ├── DateHeaderView.swift       # 日付ヘッダー（カレンダー開く）
│   │       ├── DateSelectorView.swift     # 横スクロールスライダー
│   │       └── CalendarPopupView.swift   # カレンダーポップアップ
│   │
│   ├── TodayDashboard/           # 今日のタスク画面
│   │   ├── TodayDashboardView.swift
│   │   ├── TodayDashboardViewModel.swift
│   │   └── Components/
│   │       ├── TodoCard.swift
│   │       ├── CompletedCard.swift
│   │       └── SwipeableInProgressRow.swift
│   │
│   ├── Inbox/                     # 受信トレイ画面
│   │   ├── InboxCarouselView.swift
│   │   └── InboxCarouselState.swift
│   │
│   ├── Overdue/                   # 期限切れ画面
│   │   ├── OverdueCarouselView.swift
│   │   └── OverdueCarouselViewModel.swift
│   │
│   ├── Settings/                  # 設定画面
│   │   └── SettingsView.swift
│   │
│   └── Shared/                    # 共通コンポーネント
│       ├── TaskDisplayModel.swift
│       ├── TaskPalette.swift
│       └── MandatoryFieldsSheet.swift
│
├── Services/                       # ビジネスロジック層
│   ├── TaskRepository.swift       # SwiftData統合
│   ├── TaskSyncService.swift      # Notion同期サービス
│   └── TaskScopeMatcher.swift     # タスクフィルタリング
│
├── Networking/                    # API通信層
│   ├── NotionClient.swift         # Notion APIクライアント
│   └── NotionTaskMapper.swift     # データマッピング
│
├── Models/                        # データモデル
│   ├── TaskEntity.swift           # SwiftDataモデル
│   ├── TaskSnapshot.swift
│   └── JSONValue.swift
│
├── Configuration/                 # 設定・認証
│   ├── NotionCredentialsStore.swift
│   ├── SecureTokenStore.swift
│   └── AppSettingsStore.swift
│
└── Support/                       # ユーティリティ
    ├── DateBoundaries.swift       # 日付計算
    └── DateRange.swift            # 日付範囲管理
```

---

## 🛠 技術スタック

- **フレームワーク**: SwiftUI, SwiftData
- **言語**: Swift 5.9+
- **アーキテクチャ**: MVVM + Repository Pattern
- **データ永続化**: SwiftData (Core Dataの後継)
- **ネットワーク**: URLSession + async/await
- **セキュリティ**: Keychain Services
- **日付処理**: Foundation Calendar (JST/Asia/Tokyo)

---

## 📊 開発状況

### ✅ 実装済み機能

- [x] 基本的な画面とナビゲーション
- [x] Notion APIとの同期機能
- [x] SwiftDataによるローカルキャッシュ
- [x] 日付ナビゲーション機能 ⭐
  - [x] カレンダーポップアップ
  - [x] 横スクロール日付スライダー
  - [x] Todayへのクイックアクセス
  - [x] スワイプ時の自動スナップ
- [x] Todayダッシュボード
  - [x] Todo/Completedタブ
  - [x] 時系列と優先度でのグループ化
  - [x] In Progress管理
- [x] InboxとOverdueのスワイプ処理
- [x] Pull-to-Refresh機能
- [x] 設定画面と認証管理
- [x] Neumorphismデザインシステム
- [x] アクセシビリティ対応

### 🚧 開発中

- [ ] ウィジェット機能
- [ ] 通知機能
- [ ] ダークモード対応の強化

### 📝 今後の予定

- [ ] タスクの詳細編集機能の拡張
- [ ] 検索機能
- [ ] フィルタリング機能の強化
- [ ] iPad対応

---

## 💻 開発者向け情報

### ビルドと実行

```bash
# Xcodeでプロジェクトを開く
open NotionTaskManager.xcodeproj

# コマンドラインからビルド
xcodebuild -scheme "NotionTaskManager" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build

# テストの実行（テストが存在する場合）
xcodebuild -scheme "NotionTaskManager" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test
```

### コーディング規約

- **Swift API Design Guidelines**に従う
  - 型名: PascalCase
  - 変数・関数: camelCase
  - 定数: SCREAMING_SNAKE_CASE
- **インデント**: 4スペース
- **コメント**: 日本語で記述（必要に応じて）
- 詳細は `AGENTS.md` を参照

### タイムゾーン

このアプリは**日本時間（JST/Asia/Tokyo）**を基準に動作します。すべてのスケジュール計算と日付処理はJSTで行われます。

### セキュリティガイドライン

⚠️ **重要**: 以下の点に注意してください

- ✅ 認証トークンやデータベースIDは絶対にコミットしない
- ✅ 個人情報はKeychainで安全に管理
- ✅ 通信はすべてHTTPS
- ✅ 機密情報は `.gitignore` に追加

### パフォーマンス目標

- **タスク取得**: 100タスクまで3秒以内
- **ブックマーク取得**: 最大5並列リクエスト
- **UI更新**: データ取得後500ms以内に反映
- **オフライン対応**: ローカルキャッシュから即座に表示

---

## 🤝 コントリビューション

プルリクエストを送る際は、以下の点にご注意ください：

1. **コミットメッセージ**: [Conventional Commits](https://www.conventionalcommits.org/) 形式を使用
   - `feat:` 新機能
   - `fix:` バグ修正
   - `refactor:` リファクタリング
   - `docs:` ドキュメント更新
   - `style:` コードスタイルの変更

2. **UI変更時**: スクリーンショットまたはスクリーン録画を添付

3. **関連仕様**: 関連する仕様の箇所を明記（`spec.md` 参照）

4. **テスト**: 可能な限りテストを追加

---

## 📄 ライセンス

未定

---

## 🙏 謝辞

このプロジェクトは、Notion APIとSwiftUIの最新機能を活用して構築されています。

---

**Made with ❤️ using SwiftUI**