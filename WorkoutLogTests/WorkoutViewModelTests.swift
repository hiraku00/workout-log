import SwiftData
import XCTest
@testable import WorkoutLog

@MainActor
final class WorkoutViewModelTests: XCTestCase {
    func testWeightDisplaySeparatesValueAndUnit() {
        XCTAssertEqual(23.5.weightString(unit: "kg"), "23.5 kg")
        XCTAssertEqual(100.0.weightString(unit: "kg"), "100 kg")
        XCTAssertEqual(10.0.setWeightDisplay(unit: "lbs"), "22.0 lbs")
        XCTAssertEqual(23.5.weightString(), "23.5")
        XCTAssertEqual(0.0.weightString(unit: "kg"), "0")
        XCTAssertEqual(ExerciseSet.bodyweightValue.setWeightDisplay(unit: "kg"), "自重")
    }

    func testExerciseReferenceUsesGoogleImageSearchInBrave() throws {
        let url = try XCTUnwrap(ExerciseReference.imageSearchURL(for: "チェストプレス"))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "www.google.com")
        XCTAssertEqual(components.path, "/search")
        XCTAssertFalse(url.isFileURL)
        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "tbm" })?.value,
            "isch"
        )
        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "q" })?.value,
            "チェストプレス 正しいフォーム"
        )

        let browserURL = try XCTUnwrap(ExerciseReference.braveOpenURL(for: url))
        let browserComponents = try XCTUnwrap(
            URLComponents(url: browserURL, resolvingAgainstBaseURL: false)
        )
        XCTAssertEqual(browserComponents.scheme, "brave")
        XCTAssertEqual(browserComponents.host, "open-url")
        XCTAssertEqual(
            browserComponents.queryItems?.first(where: { $0.name == "url" })?.value,
            url.absoluteString
        )
    }

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

    func testExerciseOrderCanMoveUpAndDown() {
        let workout = Workout()
        let first = WorkoutExercise(order: 0)
        let second = WorkoutExercise(order: 1)
        let third = WorkoutExercise(order: 2)
        first.workout = workout
        second.workout = workout
        third.workout = workout
        workout.workoutExercises = [first, second, third]

        let viewModel = WorkoutViewModel()
        viewModel.moveExercise(third, by: -1, in: workout)

        XCTAssertEqual(workout.sortedExercises.map(\.id), [first.id, third.id, second.id])

        viewModel.moveExercise(first, by: 1, in: workout)

        XCTAssertEqual(workout.sortedExercises.map(\.id), [third.id, first.id, second.id])
    }

    func testWorkoutTotalsOnlyIncludeCompletedSets() {
        let workout = Workout()
        let exercise = WorkoutExercise()
        exercise.workout = workout
        workout.workoutExercises = [exercise]

        let completed = ExerciseSet(order: 0, weight: 80, reps: 8)
        completed.isCompleted = true
        let planned = ExerciseSet(order: 1, weight: 100, reps: 10)
        completed.workoutExercise = exercise
        planned.workoutExercise = exercise
        exercise.sets = [completed, planned]

        XCTAssertEqual(workout.totalSets, 1)
        XCTAssertEqual(workout.totalReps, 8)
        XCTAssertEqual(workout.totalVolume, 640)
        XCTAssertEqual(workout.completedExerciseCount, 1)
    }

    func testEstimatedOneRMUsesSelectedFormula() {
        let defaults = UserDefaults.standard
        let previousValue = defaults.object(forKey: "oneRMFormula")
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: "oneRMFormula")
            } else {
                defaults.removeObject(forKey: "oneRMFormula")
            }
        }

        defaults.set(OneRMFormula.epley.rawValue, forKey: "oneRMFormula")
        XCTAssertEqual(WorkoutViewModel.estimateOneRM(weight: 14, reps: 10), 18.67, accuracy: 0.01)

        defaults.set(OneRMFormula.oConner.rawValue, forKey: "oneRMFormula")
        XCTAssertEqual(WorkoutViewModel.estimateOneRM(weight: 14, reps: 10), 17.5, accuracy: 0.01)
    }
}
