import Foundation
import SwiftData

/// ワークアウト全体を表すモデル（1回のトレーニングセッション）
@Model
final class Workout {
    var id: UUID = UUID()
    var date: Date = Date()
    /// ワークアウト名（例：「胸の日」）
    var name: String = ""
    /// 経過時間（秒単位）
    var duration: TimeInterval = 0
    var notes: String = ""
    /// 現在進行中かどうか
    var isActive: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var workoutExercises: [WorkoutExercise] = []

    /// 種目を順序でソートして返す
    var sortedExercises: [WorkoutExercise] {
        workoutExercises.sorted { $0.order < $1.order }
    }

    /// 実際に完了チェックされたセット。
    var completedSets: [ExerciseSet] {
        workoutExercises.flatMap(\.sets).filter(\.isCompleted)
    }

    /// 1セット以上完了した種目数。
    var completedExerciseCount: Int {
        workoutExercises.filter { $0.sets.contains(where: \.isCompleted) }.count
    }

    /// 完了セットを合算した総ボリューム（重量kg × レップ数。自重は除外）
    var totalVolume: Double {
        completedSets.reduce(0) { $0 + $1.volumeContribution }
    }

    /// 実施完了したセット数
    var totalSets: Int {
        completedSets.count
    }

    /// 実施完了した合計回数。
    var totalReps: Int {
        completedSets.reduce(0) { $0 + $1.reps }
    }

    init(date: Date = .now, name: String = "") {
        self.date = date
        self.name = name
    }
}
