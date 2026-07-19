import SwiftData
import XCTest
@testable import WorkoutLog

@MainActor
final class WorkoutViewModelTests: XCTestCase {
    func testAddingSetKeepsWeightButResetsRepsToDefault() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Workout.self,
            WorkoutExercise.self,
            ExerciseSet.self,
            ExerciseTemplate.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let exercise = WorkoutExercise(order: 0)
        let previousSet = ExerciseSet(order: 0, weight: 72.5, reps: 6)
        previousSet.workoutExercise = exercise
        exercise.sets.append(previousSet)
        context.insert(exercise)

        WorkoutViewModel().addSet(to: exercise, context: context)

        let newSet = try XCTUnwrap(exercise.sortedSets.last)
        XCTAssertEqual(exercise.sets.count, 2)
        XCTAssertEqual(newSet.weight, 72.5)
        XCTAssertEqual(newSet.reps, 10)
    }

    func testPresetWithSameNameMatchesAfterReseeding() {
        let oldTemplate = ExerciseTemplate(name: "チェストプレス", category: "胸", muscleGroup: "大胸筋")
        let newTemplate = ExerciseTemplate(name: "チェストプレス", category: "胸", muscleGroup: "大胸筋")

        XCTAssertTrue(oldTemplate.representsSameExercise(as: newTemplate))
    }

    func testCustomExercisesWithSameNameRemainSeparate() {
        let first = ExerciseTemplate(name: "マイ種目", category: "胸", muscleGroup: "胸", isCustom: true)
        let second = ExerciseTemplate(name: "マイ種目", category: "胸", muscleGroup: "胸", isCustom: true)

        XCTAssertFalse(first.representsSameExercise(as: second))
    }
}
