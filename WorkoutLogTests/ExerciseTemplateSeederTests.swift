import SwiftData
import XCTest
@testable import WorkoutLog

@MainActor
final class ExerciseTemplateSeederTests: XCTestCase {
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

    func testNewPresetIsInsertedWhenNoMatchExists() throws {
        let context = try makeContext()
        let presets = [ExercisePreset(name: "ダンベルスカルクラッシャー", category: "腕", muscleGroup: "上腕三頭筋")]

        ExerciseTemplateSeeder.sync(existingTemplates: [], presets: presets, modelContext: context)
        try context.save()

        let templates = try context.fetch(FetchDescriptor<ExerciseTemplate>())
        XCTAssertEqual(templates.count, 1)
        XCTAssertEqual(templates.first?.name, "ダンベルスカルクラッシャー")
        XCTAssertFalse(templates.first?.isCustom ?? true)
    }

    /// すでに同名のカスタム種目として記録・記録更新していた場合、新しいプリセットとして
    /// 別レコードを作るのではなく、既存のテンプレートをそのまま内蔵種目へ昇格させる。
    /// IDを変えないことで、紐づくワークアウト記録・ベスト更新（PR）がそのまま引き継がれる。
    func testExistingCustomExerciseWithMatchingNameIsPromotedInPlace() throws {
        let context = try makeContext()
        let customTemplate = ExerciseTemplate(name: "ダンベルスカルクラッシャー", category: "自作", muscleGroup: "自作", isCustom: true)
        context.insert(customTemplate)

        let workout = Workout(date: .now, name: "腕の日")
        context.insert(workout)
        let exercise = WorkoutExercise(order: 0)
        exercise.workout = workout
        exercise.exerciseTemplate = customTemplate
        context.insert(exercise)
        let set = ExerciseSet(order: 0, weight: 20, reps: 10)
        set.isCompleted = true
        set.workoutExercise = exercise
        context.insert(set)
        try context.save()

        let presets = [ExercisePreset(name: "ダンベルスカルクラッシャー", category: "腕", muscleGroup: "上腕三頭筋")]
        let existingTemplates = try context.fetch(FetchDescriptor<ExerciseTemplate>())
        ExerciseTemplateSeeder.sync(existingTemplates: existingTemplates, presets: presets, modelContext: context)
        try context.save()

        let templates = try context.fetch(FetchDescriptor<ExerciseTemplate>())
        XCTAssertEqual(templates.count, 1, "別レコードとして重複作成されていないこと")

        let promoted = try XCTUnwrap(templates.first)
        XCTAssertEqual(promoted.id, customTemplate.id, "IDが変わらず過去記録との紐付けが保たれること")
        XCTAssertFalse(promoted.isCustom)
        XCTAssertEqual(promoted.category, "腕")
        XCTAssertEqual(promoted.muscleGroup, "上腕三頭筋")

        // 過去のワークアウト記録は昇格後のテンプレートに引き続き紐づいている（＝ベスト更新の計算に使える）
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let viewModel = WorkoutViewModel()
        XCTAssertEqual(viewModel.personalRecord(for: promoted, workouts: workouts), 20)
    }

    func testDroppedPresetsAreArchivedNotDeleted() throws {
        let context = try makeContext()
        let stale = ExerciseTemplate(name: "廃止種目", category: "胸", muscleGroup: "大胸筋", isCustom: false)
        context.insert(stale)
        try context.save()

        let existingTemplates = try context.fetch(FetchDescriptor<ExerciseTemplate>())
        ExerciseTemplateSeeder.sync(existingTemplates: existingTemplates, presets: [], modelContext: context)
        try context.save()

        let templates = try context.fetch(FetchDescriptor<ExerciseTemplate>())
        XCTAssertEqual(templates.count, 1)
        XCTAssertTrue(templates.first?.isArchived ?? false)
    }
}
