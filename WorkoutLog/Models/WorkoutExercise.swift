import Foundation
import SwiftData

/// ワークアウト内の各種目を表すモデル
@Model
final class WorkoutExercise {
    var id: UUID = UUID()
    /// ワークアウト内での表示順序
    var order: Int = 0
    var notes: String = ""

    var workout: Workout?
    var exerciseTemplate: ExerciseTemplate?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workoutExercise)
    var sets: [ExerciseSet] = []

    /// セットを順序でソートして返す
    var sortedSets: [ExerciseSet] {
        sets.sorted { $0.order < $1.order }
    }

    /// この種目の総ボリューム（完了セットのみ。自重は除外）
    /// `Workout.totalVolume`と定義を揃えてある（未完了セットの見込み値を含めない）。
    var totalVolume: Double {
        sets.filter(\.isCompleted).reduce(0) { $0 + $1.volumeContribution }
    }

    /// 最大重量（PR判定用。完了セットのみ、自重は除外）
    var maxWeight: Double {
        sets
            .filter { $0.isCompleted && !$0.isBodyweight }
            .map(\.weight)
            .max() ?? 0
    }

    init(order: Int = 0) {
        self.order = order
    }
}
