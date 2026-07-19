import XCTest
@testable import WorkoutLog

final class WorkoutInsightsTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
    }

    func testMoreRepsAtSameWeightUpdatesEstimatedOneRM() {
        let template = ExerciseTemplate(name: "ベンチプレス", category: "胸", muscleGroup: "大胸筋")
        let previous = makeWorkout(day: 10, template: template, sets: [(20, 5)])
        let current = makeWorkout(day: 11, template: template, sets: [(20, 10)])

        let updates = WorkoutInsights.personalBestUpdates(
            for: current,
            comparedTo: [current, previous],
            calendar: calendar
        )

        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates.first?.metric, .estimatedOneRM)
        XCTAssertEqual(updates.first?.previousValue ?? 0, 23.33, accuracy: 0.01)
        XCTAssertEqual(updates.first?.currentValue ?? 0, 26.67, accuracy: 0.01)
    }

    func testEqualEstimatedOneRMDoesNotCreateUpdate() {
        let template = ExerciseTemplate(name: "スクワット", category: "脚", muscleGroup: "脚")
        let previous = makeWorkout(day: 10, template: template, sets: [(40, 8)])
        let current = makeWorkout(day: 11, template: template, sets: [(40, 8)])

        let updates = WorkoutInsights.personalBestUpdates(
            for: current,
            comparedTo: [current, previous],
            calendar: calendar
        )

        XCTAssertTrue(updates.isEmpty)
    }

    func testFirstRecordCreatesBaselineInsteadOfUpdate() {
        let template = ExerciseTemplate(name: "デッドリフト", category: "背中", muscleGroup: "背中")
        let current = makeWorkout(day: 11, template: template, sets: [(60, 5)])

        let updates = WorkoutInsights.personalBestUpdates(
            for: current,
            comparedTo: [current],
            calendar: calendar
        )

        XCTAssertTrue(updates.isEmpty)
    }

    func testBodyweightExerciseUsesRepetitions() {
        let template = ExerciseTemplate(name: "懸垂", category: "背中", muscleGroup: "広背筋")
        let previous = makeWorkout(
            day: 10,
            template: template,
            sets: [(ExerciseSet.bodyweightValue, 6)]
        )
        let current = makeWorkout(
            day: 11,
            template: template,
            sets: [(ExerciseSet.bodyweightValue, 8)]
        )

        let updates = WorkoutInsights.personalBestUpdates(
            for: current,
            comparedTo: [current, previous],
            calendar: calendar
        )

        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates.first?.metric, .bodyweightReps)
        XCTAssertEqual(updates.first?.previousValue, 6)
        XCTAssertEqual(updates.first?.currentValue, 8)
    }

    func testHomeSummaryUsesWorkoutBeforeTodayAsPrevious() {
        let template = ExerciseTemplate(name: "クランチ", category: "体幹", muscleGroup: "腹直筋")
        let previous = makeWorkout(day: 10, template: template, sets: [(10, 10)])
        let today = makeWorkout(day: 11, template: template, sets: [(10, 12)])

        let summary = WorkoutInsights.homeSummary(
            workouts: [today, previous],
            now: date(day: 11),
            calendar: calendar
        )

        XCTAssertEqual(summary.todayWorkout?.id, today.id)
        XCTAssertEqual(summary.previousWorkout?.id, previous.id)
        XCTAssertEqual(summary.thisWeekWorkoutCount, 2)
        XCTAssertEqual(summary.personalBestUpdates.count, 1)
    }

    func testDifferentExerciseIDsAreNotCompared() {
        let previousTemplate = ExerciseTemplate(name: "カスタム", category: "胸", muscleGroup: "胸", isCustom: true)
        let currentTemplate = ExerciseTemplate(name: "カスタム", category: "胸", muscleGroup: "胸", isCustom: true)
        let previous = makeWorkout(day: 10, template: previousTemplate, sets: [(20, 5)])
        let current = makeWorkout(day: 11, template: currentTemplate, sets: [(30, 5)])

        let updates = WorkoutInsights.personalBestUpdates(
            for: current,
            comparedTo: [current, previous],
            calendar: calendar
        )

        XCTAssertTrue(updates.isEmpty)
    }

    private func makeWorkout(
        day: Int,
        template: ExerciseTemplate,
        sets: [(Double, Int)],
        isActive: Bool = false
    ) -> Workout {
        let workout = Workout(date: date(day: day))
        workout.isActive = isActive

        let exercise = WorkoutExercise(order: 0)
        exercise.exerciseTemplate = template
        exercise.workout = workout
        workout.workoutExercises.append(exercise)

        for (index, values) in sets.enumerated() {
            let set = ExerciseSet(order: index, weight: values.0, reps: values.1)
            set.isCompleted = true
            set.workoutExercise = exercise
            exercise.sets.append(set)
        }

        return workout
    }

    private func date(day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day))!
    }
}
