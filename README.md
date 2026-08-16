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

`launchd`のLaunchAgentから毎朝呼び出し、スクリプト内部で前回成功から5日経過しているかを判定して実際のビルドを間引く想定です（`REBUILD_INTERVAL_DAYS`で調整可能）。`DEVICE_ID`は環境依存のため、利用する場合は`xcrun devicectl list devices`で確認した自分の端末のIdentifierに書き換えてください。LaunchAgentのplist自体はリポジトリ管理外（`~/Library/LaunchAgents/`配下）です。

## データ保存

ユーザーの入力データはSwiftDataにより端末内のアプリ専用領域へ保存されます。Gitリポジトリや外部サーバーには保存されません。

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

初回起動時、`ExercisePresets.swift`に定義された15種目をSwiftDataへ投入します。プリセットの元データはJSON等の外部ファイルではなく、Swiftコードで管理しています。手動追加したカスタム種目もプリセットと同じSwiftDataへ端末内データとして保存されます。以後は保存済みデータを使用するため、起動のたびに重複追加されることはありません。

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
