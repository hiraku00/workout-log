# Workout Log

Workout Logは、日々の筋力トレーニングをiPhoneで記録するSwiftUIアプリです。種目、重量、回数、セットごとのNotesを保存し、カレンダーやグラフから履歴を確認できます。

## 主な機能

- 日付ごとのワークアウト記録
- 重量、回数、推定1RM、セットNotesの入力
- 休憩タイマー
- 月間カレンダーとトレーニング実施日の表示
- 総ボリュームと最大推定1RMのグラフ
- 過去日のワークアウトを今日へコピー
- 前セットの重量、回数、Notesのコピーと自動継承
- プリセット種目とカスタム種目
- kg / lbs表示切り替え
- IPAex明朝を使用した日本語UI

## 必要環境

- macOS
- Xcode 15以降
- iOS 17以降
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

初回起動時、`ExercisePresets.swift`に定義された15種目をSwiftDataへ投入します。プリセットの元データはJSON等の外部ファイルではなく、Swiftコードで管理しています。手動追加したカスタム種目もプリセットと同じSwiftDataへ端末内データとして保存されます。以後は保存済みデータを使用するため、起動のたびに重複追加されることはありません。

現在はCloudKitやアカウント同期、エクスポート機能を実装していません。アプリを削除すると端末内データも失われる可能性があります。設定画面の「全データを削除」では、ワークアウト、ワークアウト内の種目、セット記録を削除します。

## プロジェクト構成

```text
WorkoutLog/
  Models/          SwiftDataモデル
  ViewModels/      記録・コピー・集計ロジック
  Views/           SwiftUI画面
  Utilities/       デザイン、フォント、プリセット
  Resources/Fonts/ IPAex明朝とライセンス
project.yml        XcodeGen設定
```

`WorkoutLog.xcodeproj`は`project.yml`から生成されるためGit管理の対象外です。

## フォント

IPAex明朝 Ver.004.01を同梱しています。フォント本体、Readme、IPAフォントライセンスは`WorkoutLog/Resources/Fonts`に収録しています。

## License

アプリのソースコードは[MIT License](LICENSE)で公開します。IPAex明朝には別途IPAフォントライセンスが適用されます。
