import SwiftData
import XCTest
@testable import WorkoutLog

@MainActor
final class DataBackupTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Workout.self,
            WorkoutExercise.self,
            ExerciseSet.self,
            ExerciseTemplate.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func writeRestoreFile(_ backup: WorkoutBackup) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)
        let url = URL.documentsDirectory.appending(path: DataBackupExporter.restoreFileName)
        try data.write(to: url)
        return url
    }

    func testExportThenImportRoundTripsAllRecords() throws {
        let sourceContext = try makeContext()
        let template = ExerciseTemplate(name: "ベンチプレス", category: "胸", muscleGroup: "大胸筋", isCustom: false)
        sourceContext.insert(template)

        let workout = Workout(date: .now, name: "胸の日")
        sourceContext.insert(workout)

        let exercise = WorkoutExercise(order: 0)
        exercise.workout = workout
        exercise.exerciseTemplate = template
        sourceContext.insert(exercise)

        let set = ExerciseSet(order: 0, weight: 60, reps: 8)
        set.isCompleted = true
        set.workoutExercise = exercise
        sourceContext.insert(set)

        try sourceContext.save()
        DataBackupExporter.export(modelContext: sourceContext)

        // 自動書き出し先(workoutlog_backup.json)を復元用ファイル名にコピーして取り込む
        let exportedURL = URL.documentsDirectory.appending(path: DataBackupExporter.backupFileName)
        let restoreURL = URL.documentsDirectory.appending(path: DataBackupExporter.restoreFileName)
        try? FileManager.default.removeItem(at: restoreURL)
        try FileManager.default.moveItem(at: exportedURL, to: restoreURL)

        let destinationContext = try makeContext()
        DataBackupImporter.restoreIfNeeded(modelContext: destinationContext)

        let restoredWorkouts = try destinationContext.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(restoredWorkouts.count, 1)
        XCTAssertEqual(restoredWorkouts.first?.name, "胸の日")
        XCTAssertEqual(restoredWorkouts.first?.workoutExercises.first?.sets.first?.weight, 60)
        XCTAssertEqual(restoredWorkouts.first?.workoutExercises.first?.exerciseTemplate?.name, "ベンチプレス")

        let restoredTemplates = try destinationContext.fetch(FetchDescriptor<ExerciseTemplate>())
        XCTAssertEqual(restoredTemplates.count, 1)

        // 復元ファイルは取り込み後に削除される
        XCTAssertFalse(FileManager.default.fileExists(atPath: restoreURL.path))
    }

    func testRestoreSkipsWorkoutsThatAlreadyExist() throws {
        let context = try makeContext()
        let existingID = UUID()
        let existingWorkout = Workout(date: .now, name: "既存の記録")
        existingWorkout.id = existingID
        context.insert(existingWorkout)
        try context.save()

        let backup = WorkoutBackup(
            exportedAt: .now,
            exerciseTemplates: [],
            workouts: [
                .init(
                    id: existingID,
                    date: .now,
                    name: "バックアップ側の別名（無視されるはず）",
                    duration: 0,
                    notes: "",
                    isActive: false,
                    exercises: []
                ),
            ]
        )
        _ = try writeRestoreFile(backup)

        DataBackupImporter.restoreIfNeeded(modelContext: context)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts.first?.name, "既存の記録")
    }

    func testRestoreDoesNothingWhenNoRestoreFilePresent() throws {
        let context = try makeContext()
        DataBackupImporter.restoreIfNeeded(modelContext: context)
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        XCTAssertTrue(workouts.isEmpty)
    }
}
