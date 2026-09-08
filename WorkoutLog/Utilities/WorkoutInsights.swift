import Foundation

struct PersonalBestUpdate: Identifiable, Equatable {
    enum Metric: Equatable {
        case estimatedOneRM
        case bodyweightReps
    }

    let exerciseID: UUID
    let exerciseName: String
    let metric: Metric
    let previousValue: Double
    let currentValue: Double

    var id: UUID { exerciseID }
}

struct HomeWorkoutSummary {
    let todayWorkout: Workout?
    let latestCompletedWorkout: Workout?
    let previousWorkout: Workout?
    let thisWeekWorkoutCount: Int
    let personalBestUpdates: [PersonalBestUpdate]
    let workoutDates: Set<String>
}

enum WorkoutInsights {
    static func homeSummary(
        workouts: [Workout],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> HomeWorkoutSummary {
        let today = calendar.startOfDay(for: now)
        let meaningfulWorkouts = workouts
            .filter {
                !$0.workoutExercises.isEmpty
                    && calendar.startOfDay(for: $0.date) <= today
            }
            .sorted { $0.date > $1.date }
        let completedWorkouts = meaningfulWorkouts.filter { !$0.isActive }
        let todayWorkout = meaningfulWorkouts.first { calendar.isDate($0.date, inSameDayAs: today) }
        let latestCompletedWorkout = completedWorkouts.first
        let previousWorkout = completedWorkouts.first {
            calendar.startOfDay(for: $0.date) < today
        }

        var weekCalendar = calendar
        weekCalendar.firstWeekday = 2
        let weekComponents = weekCalendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: today
        )
        let startOfWeek = weekCalendar.date(from: weekComponents) ?? today
        let thisWeekWorkoutCount = completedWorkouts.filter { $0.date >= startOfWeek }.count

        let recentBestUpdates = latestCompletedWorkout.map {
            Self.personalBestUpdates(for: $0, comparedTo: completedWorkouts, calendar: calendar)
        } ?? []

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyyMMdd"
        let workoutDates = Set(meaningfulWorkouts.map { formatter.string(from: $0.date) })

        return HomeWorkoutSummary(
            todayWorkout: todayWorkout,
            latestCompletedWorkout: latestCompletedWorkout,
            previousWorkout: previousWorkout,
            thisWeekWorkoutCount: thisWeekWorkoutCount,
            personalBestUpdates: recentBestUpdates,
            workoutDates: workoutDates
        )
    }

    static func personalBestUpdates(
        for workout: Workout,
        comparedTo workouts: [Workout],
        calendar: Calendar = .current
    ) -> [PersonalBestUpdate] {
        let targetDay = calendar.startOfDay(for: workout.date)
        let previousExercises = workouts
            .filter {
                !$0.isActive
                    && $0.id != workout.id
                    && calendar.startOfDay(for: $0.date) < targetDay
            }
            .flatMap(\.workoutExercises)

        return workout.workoutExercises.compactMap { exercise in
            guard let template = exercise.exerciseTemplate else { return nil }
            let history = previousExercises.filter { $0.exerciseTemplate?.representsSameExercise(as: template) == true }

            if let current = bestEstimatedOneRM(in: exercise) {
                guard let previous = history.compactMap(bestEstimatedOneRM).max(),
                      current > previous + 0.01 else { return nil }
                return PersonalBestUpdate(
                    exerciseID: template.id,
                    exerciseName: template.name,
                    metric: .estimatedOneRM,
                    previousValue: previous,
                    currentValue: current
                )
            }

            guard let currentReps = bestBodyweightReps(in: exercise),
                  let previousReps = history.compactMap(bestBodyweightReps).max(),
                  currentReps > previousReps else { return nil }
            return PersonalBestUpdate(
                exerciseID: template.id,
                exerciseName: template.name,
                metric: .bodyweightReps,
                previousValue: Double(previousReps),
                currentValue: Double(currentReps)
            )
        }
        .sorted { $0.exerciseName.localizedStandardCompare($1.exerciseName) == .orderedAscending }
    }

    private static func bestEstimatedOneRM(in exercise: WorkoutExercise) -> Double? {
        exercise.sets
            .filter { $0.isCompleted && !$0.isBodyweight && $0.weight > 0 && $0.reps > 0 }
            .map { WorkoutViewModel.estimateOneRM(weight: $0.weight, reps: $0.reps) }
            .max()
    }

    private static func bestBodyweightReps(in exercise: WorkoutExercise) -> Int? {
        exercise.sets
            .filter { $0.isCompleted && $0.isBodyweight && $0.reps > 0 }
            .map(\.reps)
            .max()
    }
}
