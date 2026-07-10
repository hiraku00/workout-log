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

    /// 全セットを合算した総ボリューム（重量kg × レップ数。自重は除外）
    var totalVolume: Double {
        workoutExercises.reduce(0) { total, exercise in
            total + exercise.sets.reduce(0) { setTotal, set in
                setTotal + set.volumeContribution
            }
        }
    }

    /// 全種目合計のセット数
    var totalSets: Int {
        workoutExercises.reduce(0) { $0 + $1.sets.count }
    }

    init(date: Date = .now, name: String = "") {
        self.date = date
        self.name = name
    }
}
