# Implementation Plan

- [ ] 1. 並列ブックマーク取得の実装
  - TaskSyncServiceに並列ブックマーク取得機能を追加
  - TaskGroupを使用して最大5並列でブックマークURLを取得
  - エラーハンドリング：一部失敗してもタスク全体の取得は継続
  - _Requirements: 1.2, 1.3_

- [ ] 2. 日付範囲モデルの実装
  - DateRangeモデルを作成（±30日の日付配列を生成）
  - JST（Asia/Tokyo）タイムゾーンで日付計算
  - 今日の日付を中心とした日付配列を返すメソッド
  - _Requirements: 2.5_

- [ ] 3. DateSelectorViewの実装
  - 水平スクロール可能な日付セレクターUIを作成
  - 各日付をDateCellとして表示（選択状態のハイライト）
  - 中央スナップ動作の実装（scrollTargetBehavior使用）
  - 日付タップ時のコールバック処理
  - _Requirements: 2.2, 2.3, 2.4_

- [ ] 4. DateHeaderViewの実装
  - 大きな文字で選択中の日付を表示
  - タップ可能なボタンとして実装
  - 日付フォーマット：「October 29, 2025」形式
  - _Requirements: 2.1, 2.2_

- [ ] 5. CalendarPopupViewの実装
  - ネイティブDatePickerを使用したカレンダーモーダル
  - 現在選択中の日付をハイライト
  - 日付選択時のコールバック処理
  - キャンセルボタンの実装
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [ ] 6. DateNavigationViewModelの実装
- [ ] 6.1 基本プロパティとイニシャライザ
  - selectedDate, tasks, isLoading, lastErrorプロパティ
  - repository, syncServiceの依存性注入
  - 初期値として今日の日付（JST）を設定
  - _Requirements: 2.1, 4.1_

- [ ] 6.2 selectDateメソッドの実装
  - キャッシュから即座にタスクを取得して表示（300ms以内）
  - バックグラウンドでsyncService.refreshを実行
  - リフレッシュ完了後、UIを更新（500ms以内）
  - _Requirements: 4.1, 4.2, 4.3, 6.2, 6.3_

- [ ] 6.3 refreshTasksメソッドの実装
  - isLoadingフラグの管理
  - 重複リフレッシュの防止
  - syncService.refreshを呼び出し
  - エラーハンドリング
  - _Requirements: 5.1, 5.3, 5.4_

- [ ] 7. DateNavigationViewの実装
- [ ] 7.1 基本レイアウトの構築
  - VStackでDateHeaderView, DateSelectorView, TaskListViewを配置
  - showingCalendar状態管理
  - sheet modifierでCalendarPopupViewを表示
  - _Requirements: 2.1, 2.2, 3.1_

- [ ] 7.2 日付選択時の処理
  - DateSelectorViewのonDateChangedコールバック
  - CalendarPopupViewのonDateSelectedコールバック
  - viewModel.selectDateの呼び出し
  - _Requirements: 2.4, 3.3_

- [ ] 7.3 リフレッシュボタンの統合
  - ツールバーにリフレッシュボタンを配置
  - ローディング中はProgressViewを表示
  - viewModel.refreshTasksの呼び出し
  - _Requirements: 5.1, 5.4_

- [ ] 8. TaskListViewの実装
  - Todo/Completedタブの切り替え
  - タスクをTimeslot順にグループ化して表示
  - 完了タスクはEndTime降順でソート
  - ローディングインジケーターの表示
  - _Requirements: 4.4, 4.5_

- [ ] 9. エラーハンドリングの改善
  - RefreshErrorエラー型の定義
  - ネットワークエラー、APIエラー、タイムアウト、認証エラーの分類
  - エラーアラートの表示（dismissボタン付き）
  - 設定画面への遷移ボタン（認証エラー時）
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ] 10. キャッシュ戦略の実装
  - アプリ起動時に即座にNotionから取得
  - 日付選択時はキャッシュ表示→バックグラウンド更新
  - リフレッシュ完了後500ms以内にUI更新
  - キャッシュがない場合はローディング表示
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ] 11. 既存TodayDashboardViewからの移行
  - DateNavigationViewをメインビューとして設定
  - App.swiftでDateNavigationViewを使用
  - TodayDashboardViewを非推奨化（コメント追加）
  - 既存の機能（Inbox/Overdue FAB、InProgressピル）をDateNavigationViewに統合
  - _Requirements: 2.1, 4.1_

- [ ] 12. パフォーマンステストの実装
  - 100タスクのリフレッシュが3秒以内に完了することを検証
  - 並列ブックマーク取得が順次取得より50%以上高速化されることを検証
  - キャッシュからの表示が300ms以内に完了することを検証
  - _Requirements: 1.1, 1.2, 6.2_

