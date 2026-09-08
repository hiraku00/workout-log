# Workout Log

Workout Logは、日々の筋力トレーニングをiPhoneで記録するSwiftUIアプリです。種目、重量、回数、セットごとのNotesを保存し、カレンダーやグラフから履歴を確認できます。

## 主な機能

- 日付ごとのワークアウト記録
- 重量、回数、推定1RM、セットNotesの入力
- 休憩タイマー（AlarmKit。利用できない場合はローカル通知へフォールバック）
- 月間カレンダーとトレーニング実施日の表示
- 総ボリュームと最大推定1RMのグラフ
- 過去日のワークアウトを今日、または任意の過去日へコピー
- 前セットの重量、回数、Notesのコピーと自動継承
- プリセット種目とカスタム種目
- kg / lbs表示切り替え
- 種目のフォーム参考画像をGoogle画像検索で確認（Braveが利用可能な場合はBraveで開く）
- iOS標準のSan Franciscoとセマンティックカラーに適応する日本語UI

## 必要環境

- macOS
- Xcode 26以降
- iOS 26以降
- XcodeGen

## セットアップ

```bash
brew install xcodegen
git clone <repository-url>
cd gym-app
xcodegen generate
open WorkoutLog.xcodeproj
```

Xcodeで`WorkoutLog`スキームと実行先のiPhoneを選択して実行します。

コマンドラインでビルドする場合:

```bash
xcodebuild \
  -project WorkoutLog.xcodeproj \
  -scheme WorkoutLog \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### 実機への定期自動リビルド（任意）

無料のApple ID（Personal Team）で実機ビルドする場合、provisioning profileの有効期限が7日間のため、期限切れでアプリが起動できなくなることがあります。[scripts/rebuild_and_install.sh](scripts/rebuild_and_install.sh)は、実機が接続されている（USBまたは同一ネットワーク上のWi-Fi）ときに再ビルド・再インストールしてこれを防ぐスクリプトです。

`launchd`のLaunchAgentから**30分おき**に呼び出されます。固定の時刻に1回だけ実行する方式だと、その瞬間に端末がロックされている/未接続だと丸ごと失敗するため、代わりに短い間隔で繰り返しチェックし、スクリプト内部で前回成功から5日経過しているかを判定して実際のビルドを間引きます（`REBUILD_INTERVAL_DAYS`で調整可能）。5日未満の間はすべての実行が即座に終了するため負荷はほぼゼロで、5日経過後は端末が実際に繋がる（＝ロック解除された）タイミングを捉えるまで30分おきにリトライし続けます。`DEVICE_ID`は環境依存のため、利用する場合は`xcrun devicectl list devices`で確認した自分の端末のIdentifierに書き換えてください。LaunchAgentのplist自体はリポジトリ管理外（`~/Library/LaunchAgents/`配下）です。

このスクリプトは**アプリのアンインストールを一切行いません**。`devicectl device install app`によるアップグレードインストールのみを行うため、端末内のSwiftDataは保持されます（アンインストールするとアプリのデータ領域ごと削除されるため、絶対に自動化フローへ組み込まないでください）。

provisioning profileは**残り有効期限が`PROFILE_REFRESH_THRESHOLD_DAYS`（既定2日）以下の場合のみ**ローカルキャッシュを削除して新規発行させます。まだ十分な期限が残っていれば同じprofileを再利用するため、同じキャッシュが使われる限りOS側の「デベロッパを信頼」も再度必要になりません（新しいprofileが発行された時だけ、端末で信頼をやり直す必要があります）。また、Xcodeのアカウントセッションが一時的に不調でも、キャッシュがまだ有効な間はビルドがそれに依存せず成功します。

### アプリデータの自動バックアップ

アプリは`scenePhase`が`.background`になるたび（ホーム画面に戻るたび）、全記録を`Documents/workoutlog_backup.json`へ自動でJSON書き出しします（[DataBackup.swift](WorkoutLog/Utilities/DataBackup.swift)）。ユーザー操作は不要です。

Mac側では[scripts/daily_backup.sh](scripts/daily_backup.sh)が、このJSONファイルだけを`devicectl device copy from`（`appDataContainer`ドメイン指定）で`~/Library/Application Support/WorkoutLogBackups/`へ取得し、直近30世代を保持します。これはFinder/iTunesが行うような端末全体のバックアップとは異なり、**このアプリのデータのみ**を対象にした軽量なコピーです。

`daily_backup.sh`は`com.hiraku.workoutlog.dailybackup.plist`（LaunchAgent）から**30分おき**に単独で実行され、5日おきの再ビルドとは独立してMac側の控えを最新化します。ただし**その日すでに1回成功していれば即座にスキップ**するため、実際に端末へアクセスするのは1日1回だけです（1日のうちどこかのタイミングで端末が繋がっていれば拾える、というのが狙いで、繋がりっぱなしでもファイルが無駄に増殖しません）。データ消失時に失われうる範囲は最大1日程度に収まります。`scripts/rebuild_and_install.sh`もビルド前に同じ処理を呼び出すため、重複して実装はしていません。

### アプリデータの自動復元

インストール直後、スクリプトはMac側の最新バックアップを`devicectl device copy to`で端末の`Documents/workoutlog_backup_restore.json`へ送り込みます。アプリは次回起動時にこのファイルを検出し、IDが一致しない（＝まだ存在しない）記録だけをSwiftDataへ取り込みます（[DataBackupImporter](WorkoutLog/Utilities/DataBackup.swift)）。

データコンテナが健在な通常のアップグレードでは全レコードが既に存在するため実質何もしません。provisioning profileの完全な失効や再インストールでデータコンテナが失われた場合のみ、直近のバックアップから自動的に復元されます。取り込み後、復元用ファイルは削除されます。

アプリ内でワークアウトを削除すると、そのIDを端末内に「削除済み」として記録します（[DeletedWorkoutTombstones](WorkoutLog/Utilities/DeletedWorkoutTombstones.swift)）。Mac側のバックアップは最大30世代保持されているため、削除後に古い世代が復元用ファイルとして送り込まれる可能性がありますが、このIDが記録されている限り復元処理はその記録をスキップします。アンインストール等でデータコンテナごと失われた場合はこの記録も一緒に消えるため、正規の復元シナリオは従来通り機能します。削除操作の直後にはアプリ側の自動書き出し（`Documents/workoutlog_backup.json`）もその場で最新化し、Mac側の次回バックアップ取得が削除後の状態に早く追いつくようにしています。

### 自動化状態の確認画面（アプリ内）

アプリの「同期」タブ（[SyncStatusView](WorkoutLog/Views/Sync/SyncStatusView.swift)）で、証明書の有効期限・最終バックアップ日時・最終リビルド日時・次回リビルド予定日を確認できます。証明書の有効期限はこの端末のprofileから直接読み取り（Mac不要）、バックアップ・リビルドの成否はMac側スクリプトが`devicectl device copy to`で送り込む`Documents/workoutlog_status.json`（[DeviceSyncStatus](WorkoutLog/Utilities/DeviceSyncStatus.swift)）から読み取ります。

## データ保存

ユーザーの入力データはSwiftDataにより端末内のアプリ専用領域へ保存されます。Gitリポジトリや外部サーバーには保存されません（自動バックアップされたJSONのみ、上記の通りローカルMacの`~/Library/Application Support/WorkoutLogBackups/`に保存されます）。

| データ | 保存先 | 内容 |
|---|---|---|
| Workout | SwiftData | 日付、名前、時間、Notes、進行状態 |
| WorkoutExercise | SwiftData | ワークアウト内の種目と並び順 |
| ExerciseSet | SwiftData | 重量、回数、Notes、並び順 |
| ExerciseTemplate | SwiftData | プリセット種目とカスタム種目 |
| 重量単位 | AppStorage | kg / lbs |
| 休憩時間 | AppStorage | タイマーの既定秒数 |
| 表示モード | AppStorage | システム / ライト / ダーク |
| 推定1RM方式 | AppStorage | Epley式 / O’Conner式 |

初回起動時、`ExercisePresets.swift`に定義された16種目をSwiftDataへ投入します（[ExerciseTemplateSeeder](WorkoutLog/Utilities/ExerciseTemplateSeeder.swift)）。プリセットの元データはJSON等の外部ファイルではなく、Swiftコードで管理しています。手動追加したカスタム種目もプリセットと同じSwiftDataへ端末内データとして保存されます。以後は保存済みデータを使用するため、起動のたびに重複追加されることはありません。同名のカスタム種目を先に追加していた場合は、削除して作り直すのではなくそのレコードを内蔵種目へ昇格させるため（IDは変わらない）、それまでの記録・ベスト更新（PR）は引き継がれます。

現在はCloudKitやアカウント同期、エクスポート機能を実装していません。アプリを削除すると端末内データも失われる可能性があります。設定画面の「全データを削除」では、ワークアウト、ワークアウト内の種目、セット記録を削除します。

## プロジェクト構成

```text
WorkoutLog/
  Models/          SwiftDataモデル
  ViewModels/      記録・コピー・集計ロジック
  Views/           SwiftUI画面
  Utilities/       デザイン、共通処理、プリセット
  Resources/       休憩終了アラーム音
project.yml        XcodeGen設定
```

`WorkoutLog.xcodeproj`は`project.yml`から生成されるためGit管理の対象外です。

## UI方針

文字、カラー、背景はiOSのDynamic Type・Dark Mode・セマンティックカラーに従います。アプリ独自の固定フォントや固定ライトテーマは使用せず、端末の表示設定に適応します。

休憩タイマーは、AlarmKitが利用できる場合にOS管理のアラームで終了を伝えます。利用不可または登録に失敗した場合はローカル通知へフォールバックします。OSアラームは再生中の音楽・動画を中断する場合があり、他社アプリの再生を本アプリから自動再開することはできません。

## License

アプリのソースコードは[MIT License](LICENSE)で公開します。
