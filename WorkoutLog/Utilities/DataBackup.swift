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
    /// Mac側から復元用JSONを送り込む際のファイル名（自動書き出し先とは別名にし、上書き競合を避ける）
    static let restoreFileName = "workoutlog_backup_restore.json"

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

/// Mac側から送り込まれた復元用JSON（workoutlog_backup_restore.json）を取り込む。
/// IDが一致する既存レコードはスキップするため、データが健在な通常のアップグレード
/// インストールでは何もしない（＝安全に毎回呼び出せる）。アンインストール等でデータ
/// コンテナが失われていた場合のみ、実質的な復元として働く。
enum DataBackupImporter {
    static func restoreIfNeeded(modelContext: ModelContext) {
        let url = URL.documentsDirectory.appending(path: DataBackupExporter.restoreFileName)
        guard let data = try? Data(contentsOf: url) else { return }
        defer { try? FileManager.default.removeItem(at: url) }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(WorkoutBackup.self, from: data) else {
            print("復元用バックアップの読み込みに失敗しました")
            return
        }

        do {
            var templatesByID = Dictionary(
                uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<ExerciseTemplate>()).map { ($0.id, $0) }
            )
            for templateBackup in backup.exerciseTemplates where templatesByID[templateBackup.id] == nil {
                let template = ExerciseTemplate(
                    name: templateBackup.name,
                    category: templateBackup.category,
                    muscleGroup: templateBackup.muscleGroup,
                    isCustom: templateBackup.isCustom
                )
                template.id = templateBackup.id
                template.isArchived = templateBackup.isArchived
                modelContext.insert(template)
                templatesByID[templateBackup.id] = template
            }

            let existingWorkoutIDs = Set(try modelContext.fetch(FetchDescriptor<Workout>()).map(\.id))
            for workoutBackup in backup.workouts
                where !existingWorkoutIDs.contains(workoutBackup.id)
                    && !DeletedWorkoutTombstones.contains(workoutBackup.id) {
                let workout = Workout(date: workoutBackup.date, name: workoutBackup.name)
                workout.id = workoutBackup.id
                workout.duration = workoutBackup.duration
                workout.notes = workoutBackup.notes
                // 進行中フラグは復元しない。中断済みワークアウトが「進行中」として
                // 突然再開されるのを避けるため、常に完了扱いとして復元する。
                workout.isActive = false
                modelContext.insert(workout)

                for exerciseBackup in workoutBackup.exercises {
                    let exercise = WorkoutExercise(order: exerciseBackup.order)
                    exercise.id = exerciseBackup.id
                    exercise.notes = exerciseBackup.notes
                    exercise.workout = workout
                    exercise.exerciseTemplate = exerciseBackup.exerciseTemplateID.flatMap { templatesByID[$0] }
                    modelContext.insert(exercise)

                    for setBackup in exerciseBackup.sets {
                        let set = ExerciseSet(order: setBackup.order, weight: setBackup.weight, reps: setBackup.reps)
                        set.id = setBackup.id
                        set.isCompleted = setBackup.isCompleted
                        set.comment = setBackup.comment
                        set.workoutExercise = exercise
                        modelContext.insert(set)
                    }
                }
            }

            try modelContext.save()
        } catch {
            print("バックアップの復元に失敗しました: \(error)")
        }
    }
}
