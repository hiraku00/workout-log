import XCTest
@testable import WorkoutLog

final class ExercisePresetsTests: XCTestCase {
    func testDefaultExercisesMatchConfiguredCatalog() {
        XCTAssertEqual(
            Set(ExercisePresets.all.map(\.name)),
            Set([
                "ダンベルカール",
                "フレンチプレス",
                "ダンベルスカルクラッシャー",
                "ワンハンドサイドレイズ",
                "ダンベルショルダープレス",
                "腹筋ローラー",
                "チンニング",
                "ブルガリアンスクワット",
                "レッグカール",
                "レッグエクステンション",
                "ヒップアブダクション",
                "ヒップアダクション",
                "チェストプレス",
                "フロントラットプルダウン",
                "シーテッドロウ",
                "インクラインダンベルプレス",
            ])
        )
        XCTAssertEqual(ExercisePresets.all.count, 16)
    }
}
