import Foundation
import SwiftData

/// 各セット（重量・レップ数）を表すモデル
@Model
final class ExerciseSet {
    var id: UUID = UUID()
    /// このセットの順序番号
    var order: Int = 0
    /// 重量（kg単位で保存。表示時に単位変換する）
    var weight: Double = 0.0
    /// レップ数
    var reps: Int = 0
    /// このセットを完了チェックしたか
    var isCompleted: Bool = false
    /// セットのコメント
    var comment: String = ""

    var workoutExercise: WorkoutExercise?

    init(order: Int = 0, weight: Double = 0.0, reps: Int = 0) {
        self.order = order
        self.weight = weight
        self.reps = reps
    }

    /// 自重を表す重量値（kg換算なし）
    static let bodyweightValue: Double = -1

    var isBodyweight: Bool { weight == Self.bodyweightValue }

    /// ボリューム計算用（自重は0）
    var volumeContribution: Double {
        isBodyweight ? 0 : weight * Double(reps)
    }
}
