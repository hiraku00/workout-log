import Foundation
import SwiftData

/// SwiftDataの全記録をJSONへ書き出すためのCodable表現。
/// モデル定義そのものではなく、エクスポート専用のスナップショット。
struct WorkoutBackup: Codable {
    var exportedAt: Date
    var exerciseTemplates: [ExerciseTemplateBackup]
    var workouts: [WorkoutBackup_Workout]

    struct ExerciseTemplateBackup: Codable {
        var id: UUID
        var name: String
        var category: String
        var muscleGroup: String
        var isCustom: Bool
        var isArchived: Bool
    }

    struct WorkoutBackup_Workout: Codable {
        var id: UUID
        var date: Date
        var name: String
        var duration: TimeInterval
        var notes: String
        var isActive: Bool
        var exercises: [WorkoutBackup_Exercise]
    }

    struct WorkoutBackup_Exercise: Codable {
        var id: UUID
        var order: Int
        var notes: String
        var exerciseTemplateID: UUID?
        var sets: [WorkoutBackup_Set]
    }

    struct WorkoutBackup_Set: Codable {
        var id: UUID
        var order: Int
        var weight: Double
        var reps: Int
        var isCompleted: Bool
        var comment: String
    }
}

/// アプリのDocuments配下へ全記録をJSONとして自動書き出しする。
/// ユーザー操作を必要とせず、バックグラウンド遷移のたびに最新化される。
enum DataBackupExporter {
    static let backupFileName = "workoutlog_backup.json"

    static func export(modelContext: ModelContext) {
        do {
            let templates = try modelContext.fetch(FetchDescriptor<ExerciseTemplate>())
            let workouts = try modelContext.fetch(FetchDescriptor<Workout>())

            let backup = WorkoutBackup(
                exportedAt: .now,
                exerciseTemplates: templates.map { template in
                    .init(
                        id: template.id,
                        name: template.name,
                        category: template.category,
                        muscleGroup: template.muscleGroup,
                        isCustom: template.isCustom,
                        isArchived: template.isArchived
                    )
                },
                workouts: workouts.map { workout in
                    .init(
                        id: workout.id,
                        date: workout.date,
                        name: workout.name,
                        duration: workout.duration,
                        notes: workout.notes,
                        isActive: workout.isActive,
                        exercises: workout.sortedExercises.map { exercise in
                            .init(
                                id: exercise.id,
                                order: exercise.order,
                                notes: exercise.notes,
                                exerciseTemplateID: exercise.exerciseTemplate?.id,
                                sets: exercise.sortedSets.map { set in
                                    .init(
                                        id: set.id,
                                        order: set.order,
                                        weight: set.weight,
                                        reps: set.reps,
                                        isCompleted: set.isCompleted,
                                        comment: set.comment
                                    )
                                }
                            )
                        }
                    )
                }
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(backup)

            let url = URL.documentsDirectory.appending(path: backupFileName)
            try data.write(to: url, options: .atomic)
        } catch {
            print("バックアップ書き出しに失敗しました: \(error)")
        }
    }
}
