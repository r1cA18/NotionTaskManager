目的: 最小の指示で実装を回せるよう、AIエージェントが要件→設計→実装→テスト→Notion同期まで伴走するための単一資料

0. スナップショット

プラットフォーム: iOSのみ（実装は SwiftUI）

時間基準: JST（Asia/Tokyo）。日付境界は 00:00 JST 固定

外部DS: Notion-like API（DB_TASKS）。Button列は読み込みのみ

主要スコープ: Inbox / 昨日まで / 今日・時間指定なし

FAB（右下の丸ボタン）: 要処理タスクがある時のみ表示→カードスワイプ画面へ

1. 用語とスコープ定義（厳密）

Inbox: Timestamp が null かつ Status ∈ {To Do, In Progress}。

昨日までのタスク: COALESCE(Deadline, EndTime, Timestamp) が today(JST) 未満 かつ Status != Complete。

今日の時間指定なし: dateEquals(Timestamp, today(JST)) かつ Timeslot IS NULL かつ Status != Complete。

右スワイプ（Complete）: Priority と Timeslot が必須。未設定ならミニモーダルで強制入力→保存→Status = Complete ＋ EndTime = now()。さらに Timestamp が null の場合は Timestamp = today(JST) を自動付与。

左スワイプ（NextAction化）: Type = NextAction, Status = To Do。Timestamp は変更しない。

開始タップ: Status = In Progress ＋ StartTime = now()。

注: 実DB運用に合わせ、本書の条件は環境変数で緩和/厳格化できるようにする。

2. 情報アーキテクチャ / 画面一覧

メイン（Today/選択日）: タスク一覧、日付スワイプ（無限）、Todayボタン、カレンダー遷移、進行中ピル、右下FAB

カードスワイプ: スコープ別にカードを順送り（Inbox→昨日まで→今日未割当の優先順は設定で調整可）

カレンダー（月）: 日付選択→メインへ

詳細編集モーダル: 基本プロパティ編集

設定: 通知時刻、スワイプ閾値、デザイン微調整

2.5 ページ遷移図（iOS）

FAB表示条件: (Inboxに未処理) OR (昨日までに該当) OR (今日・時間指定なしに該当)

flowchart LR
  A[起動] --> B[メイン: タスク一覧]
  B <-- swipe L/R 日付無限 --> B
  B <---> C[カレンダー(月)]
  B -->|FAB: 要処理あり時のみ| D[カードスワイプ]
  D -->|右=完了 / 左=NextAction| B
  B --> E[詳細編集モーダル]
  E --> B

3. UI 仕様（詳細）

3.1 メイン

上部: 日付ヘッダ（左右スワイプで無限スクロール）。Todayボタンで今日へ

リスト: セクション分割（Inbox/昨日まで/今日未割当）。各セクションの背景に淡い色オーバーレイ

Inbox: #9CA3AF（Gray 400）@6% α

昨日まで: #EF4444（Red 500）@6% α

今日未割当: #3B82F6（Blue 500）@6% α

進行中ピル: 下部固定。タップでポップアップ（中断/完了ショートカット）

FAB: 56pt 丸。要処理がない場合は非表示

3.2 カードスワイプ画面

水平スワイプ: 右=完了（必須チェッカー発火）、左=NextAction化

タグ編集: 上下ホイール型ピッカー（Notionのタグ順をミラー）。複数選択上限なし

アニメーション: 100–180ms。完了時のみ軽ハプティクス（Impact Light）

3.3 詳細編集モーダル

編集可能: Title, Memo, Status, Timeslot, Priority, Type, Deadline, DB_PROJECT, ArticleGenre, PermanentTags, userDefined:URL

読み取りのみ: WorkTime, START, COMPLETE

4. データベース仕様（DB_TASKS）

4.1 スキーマ（プロパティ一覧）

Name: title

Memo: text

Status: status → To Do | In Progress | Complete

Timestamp: date

Timeslot: select → Morning | Afternoon | Evening | Night

EndTime: date

StartTime: date

Priority: select → ★★★★ | ★★★☆ | ★★☆☆ | ★☆☆☆

DB_PROJECT: relation（URL配列）

Type: select → NextAction | Someday | Waiting | Trash

START: button（読み取り専用）

COMPLETE: button（読み取り専用）

ArticleGenre: multi_select → VibeCoding, LLM, AI, Technology, Coding, Tool, Gadget, Life, Fashion, Apple, Dev, News, Design, Network, Learn, C-Style, Electronics

DB_Schedule: relation（URL配列）→ 本アプリでは未使用（同期しない）

Deadline: date

PermanentTags: multi_select → Knowledge, Tool, Technology, Kosen, Security, Event, Electronics, Gadget, Automation, FileConversion, MacUtility

Space Name: text

URL: url（内部名: userDefined:URL）

WorkTime: formula（読み取りのみ / クエリ不可）

4.2 データ型とバリデーション（アプリ入力仕様）

文字列: title, text, url

select: 許容値のみ厳密一致（全角・半角差異不可）

multi_select: 配列。空配列で全解除

status: To Do | In Progress | Complete

date: 拡張キー

date:<Property>:start = ISO-8601（YYYY-MM-DD もしくは日時）

date:<Property>:end = 期間時のみ（start同梱必須）

date:<Property>:is_datetime = 0 | 1

relation: URL配列。DB_PROJECTのみ使用、DB_Scheduleは未使用

クリア

title, text, url, select, status: null

multi_select, relation: []

4.3 SQLite可視性（クエリ時の注意）

クエリ可能: title, text, url, select, multi_select, status, date, relation

クエリ不可: formula（WorkTime）

4.4 推奨APIペイロード例

1) 新規作成（必須: Name）

{
  "properties": {
    "Name": "サンプルタスク",
    "Status": "To Do",
    "Type": "NextAction",
    "Priority": "★★☆☆",
    "Memo": "補足メモ",
    "Timeslot": "Morning",
    "userDefined:URL": "https://example.com",
    "ArticleGenre": ["AI", "Tool"],
    "PermanentTags": ["Knowledge", "Automation"],
    "date:StartTime:start": "2025-10-10T09:00:00+09:00",
    "date:StartTime:is_datetime": 1,
    "date:EndTime:start": "2025-10-10T11:00:00+09:00",
    "date:EndTime:is_datetime": 1,
    "date:Deadline:start": "2025-10-15",
    "date:Deadline:is_datetime": 0,
    "DB_PROJECT": ["{{some-project-page-url}}"]
  }
}

2) 更新（期限を範囲へ変更）

{
  "properties": {
    "date:Deadline:start": "2025-10-15",
    "date:Deadline:end": "2025-10-20",
    "date:Deadline:is_datetime": 0
  }
}

3) クリア（優先度未設定、タグ全解除）

{
  "properties": {
    "Priority": null,
    "ArticleGenre": [],
    "PermanentTags": []
  }
}

4) リレーション差し替え

{
  "properties": {
    "DB_PROJECT": ["user://1c3e-...-a266e", "https://www.notion.so/..." ]
  }
}

5. ステートマシン / イベント処理

To Do ──(開始タップ)──▶ In Progress ──(右スワイプ完了)──▶ Complete
  ▲                 │                                      │
  └────(左スワイプでType=NextAction)───────┘               └── EndTime=now()

右スワイプ処理（疑似コード）

onSwipeRight(task){
  if(!task.Priority || !task.Timeslot){
    ui.command('openModal:completePrereq', {missing: ['Priority','Timeslot'].filter(k=>!task[k])});
    return;
  }
  const nowJst = time.now();
  const patch:any = {
    'Status': 'Complete',
    'date:EndTime:start': nowJst,
    'date:EndTime:is_datetime': 1
  };
  if(!task.Timestamp){
    patch['date:Timestamp:start'] = startOfDay(nowJst); // 右スワイプ時に当日付与
    patch['date:Timestamp:is_datetime'] = 0;
  }
  notion.update(task.id, patch);
}

左スワイプ処理

onSwipeLeft(task){
  notion.update(task.id, {
    'Type': 'NextAction',
    'Status': 'To Do'
  });
}

開始タップ

onStartTap(task){
  const nowJst = time.now();
  notion.update(task.id, {
    'Status': 'In Progress',
    'date:StartTime:start': nowJst,
    'date:StartTime:is_datetime': 1
  });
}

6. フィルタ擬似クエリ（JST）

-- Inbox
WHERE Status IN ('To Do','In Progress') AND Timestamp IS NULL

-- 昨日まで
WHERE Status != 'Complete'
  AND COALESCE(Deadline, EndTime, Timestamp) < startOfDay(TODAY_JST)

-- 今日・時間指定なし
WHERE Status != 'Complete'
  AND dateEquals(Timestamp, TODAY_JST)
  AND Timeslot IS NULL

TODAY_JST = floor((now() + 9h) / 1d)

7. 同期/オフライン

キャッシュ: 全タスクをローカルSQLiteにミラー（write-behind）

競合: updated_at 比較＋フィールド単位マージ。衝突時はクライアント勝ち or ユーザー選択

送信順序: 依存なし→関係更新（DB_Schedule は未使用）→日時→ステータス

Button/Formula列は読み取りのみ。遷移は Status/StartTime/EndTime を直接更新

8. 通知

7:00 に dateEquals(Timestamp, today) AND Timeslot IS NULL の件数をバッジ通知（設定で変更可）

9. API コントラクト

読み込み: GET /tasks?fields=...（列は本章の通り）

作成/更新/クリア/リレーション差し替え: §4.4 の例に準拠

スワイプ操作の標準化

// 右スワイプ（完了）
{
  "properties": {
    "Status": "Complete",
    "date:EndTime:start": "<now>",
    "date:EndTime:is_datetime": 1
  }
}

// 左スワイプ（NextAction化）
{
  "properties": {
    "Type": "NextAction",
    "Status": "To Do"
  }
}

10. エージェント設計（プロンプト）

10.1 System

役割: タスクUI実装の相棒。仕様遵守・差分提案・型安全・短サイクル検証

すべてJST。DB_TASKSの列挙値は厳密一致。Button/Formulaは書き込み禁止

10.2 ツール

notion.update(properties: object) — DB_TASKSへの更新

cache.query(sql: string) — SQLiteキャッシュ SELECT

ui.command(name: string, args?: any) — UI操作（スワイプ/モーダル/トースト）

time.now() — JST 現在時刻

10.3 ルール

右スワイプ: Priority/Timeslotが無ければモーダル→保存→Complete。Timestampがnullなら今日を自動付与

左スワイプ: Type=NextAction、Status=To Do

開始タップ: In Progress ＋ StartTime=now()

11. デザイン指針（Notionリスペクト / Minimal & Cozy）

トーン: 低彩度・余白広め・情報密度低め。視覚ノイズ最少

カラー: グレースケール主体＋アクセント1色（ブルー系）。スコープ色は淡いオーバーレイ

タイポ: SF Pro（本文15–17pt、見出し1.25x）

レイアウト: 8ptグリッド、カード角丸16pt、影は極薄、ヘアラインボーダー

モーション/触感: 100–180ms、完了時のみ軽ハプティクス

コンポーネント

カード: 背景#FFF、ボーダー#E5E7EB、内側余白16pt

FAB: 56pt、右下固定、影弱め、シンプルアイコン

タグピッカー: 時計ホイール、Notion順序ミラー

12. テスト計画

単体: フィルタ境界・JST 23:59跨ぎ

UI: スワイプ閾値、必須入力モーダル、タグピッカー操作感

同期待機: 機内→複数更新→復帰時のマージ順

E2E: 3スコープの色識別と操作一貫性、FAB表示条件

13. 設定項目（.env / 設定画面）

NOTION_API_KEY, DB_TASKS_ID, TZ=Asia/Tokyo, PLATFORM=iOS

右スワイプ必須: Priority, Timeslot（固定）

通知 7:00 のオン/オフ（時刻は設定で変更可）

14. ロードマップ

v0: 3スコープ＋カードスワイプ＋必須入力モーダル＋FAB

v1: 通知/Todayボタン/カレンダー

v2: 競合解決UI/履歴


