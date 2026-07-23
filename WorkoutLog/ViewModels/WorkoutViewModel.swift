import Foundation
import SwiftUI
import SwiftData

/// 推定1RMの計算式。比較対象のアプリと同じ基準で記録を見られるよう選択可能にする。
enum OneRMFormula: String, CaseIterable, Identifiable {
    case epley
    case oConner

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .epley: "Epley式"
        case .oConner: "O’Conner式"
        }
    }

    var detail: String {
        switch self {
        case .epley: "重量 × (1 + 回数 ÷ 30)"
        case .oConner: "重量 × (1 + 回数 × 0.025)"
        }
    }
}

/// アクティブなワークアウトの状態を管理するViewModel
@Observable
final class WorkoutViewModel {
    /// 現在進行中のワークアウト
    var activeWorkout: Workout?

    /// 現在ホームタブで開く日付（履歴カレンダーからの遷移用）
    var homeNavigationDate: Date?

    /// 種目追加時に自動作成するセット数
    private var defaultSetCount: Int {
        let stored = UserDefaults.standard.integer(forKey: "defaultSetCount")
        return stored == 0 ? 3 : stored
    }

    // MARK: - ワークアウト開始・終了

    /// 新規ワークアウトを開始する（同日に既存のワークアウトがある場合は再利用）
    /// - Parameter date: ワークアウトの対象日。省略時は今日。
    func startWorkout(context: ModelContext, name: String = "", date: Date = Date()) {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: targetDay) ?? targetDay

        // 同日の既存ワークアウトを検索
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { workout in
                workout.date >= targetDay && workout.date < nextDay
            }
        )

        if let existingWorkout = try? context.fetch(descriptor).first {
            // 既存のワークアウトを再利用
            existingWorkout.isActive = true
            activeWorkout = existingWorkout
        } else {
            // 新規ワークアウトを作成（対象日で作成）
            let workout = Workout(date: targetDay, name: name)
            workout.isActive = true
            context.insert(workout)
            activeWorkout = workout
        }
    }

    /// 進行中のワークアウトを復元する（アプリ再起動時）
    func resumeWorkout(_ workout: Workout) {
        activeWorkout = workout
    }

    /// 完了済みワークアウトを再編集可能な状態にする
    func reopenWorkout(_ workout: Workout) {
        workout.isActive = true
        activeWorkout = workout
    }

    /// ワークアウトを正常終了する
    func endWorkout() {
        guard let workout = activeWorkout else { return }
        workout.isActive = false
        activeWorkout = nil
    }

    /// 指定日のワークアウトを取得（なければ nil）
    func workout(for date: Date, in context: ModelContext) -> Workout? {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: targetDay) ?? targetDay
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { workout in
                workout.date >= targetDay && workout.date < nextDay
            }
        )
        return try? context.fetch(descriptor).first
    }

    /// 指定日のワークアウトを取得、なければ新規作成
    @discardableResult
    func getOrCreateWorkout(for date: Date, context: ModelContext) -> Workout {
        if let existing = workout(for: date, in: context) {
            return existing
        }
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let workout = Workout(date: targetDay)
        context.insert(workout)
        return workout
    }

    /// 履歴カレンダーからホームタブへ日付を渡して開く
    func openDayOnHome(_ date: Date) {
        homeNavigationDate = Calendar.current.startOfDay(for: date)
    }

    /// ワークアウトをキャンセルして削除する
    func cancelWorkout(_ workout: Workout, context: ModelContext) {
        context.delete(workout)
        if activeWorkout?.id == workout.id {
            activeWorkout = nil
        }
    }

    /// ワークアウトをキャンセルして削除する（進行中ワークアウト用）
    func cancelWorkout(context: ModelContext) {
        guard let workout = activeWorkout else { return }
        cancelWorkout(workout, context: context)
    }

    // MARK: - 種目・セット操作

    /// 種目をワークアウトに追加する（3セット分の枠を自動作成）
    func addExercise(_ template: ExerciseTemplate, to workout: Workout, context: ModelContext) {
        guard !workout.workoutExercises.contains(where: { $0.exerciseTemplate?.id == template.id }) else { return }
        let order = workout.workoutExercises.count
        let workoutExercise = WorkoutExercise(order: order)
        workoutExercise.exerciseTemplate = template
        workoutExercise.workout = workout
        context.insert(workoutExercise)

        for index in 0..<defaultSetCount {
            let set = ExerciseSet(order: index, weight: 0, reps: 10)
            set.workoutExercise = workoutExercise
            context.insert(set)
        }
    }

    /// セットを追加する（重量だけを引き継ぎ、回数は既定値へ戻す）
    func addSet(to workoutExercise: WorkoutExercise, context: ModelContext) {
        let lastSet = workoutExercise.sortedSets.last
        let order = workoutExercise.sets.count
        let newSet = ExerciseSet(
            order: order,
            weight: lastSet?.weight ?? 0,
            reps: 10
        )
        newSet.comment = lastSet?.comment ?? ""
        newSet.workoutExercise = workoutExercise
        context.insert(newSet)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// セットの値を前のセットからコピーする
    func copyFromPreviousSet(_ set: ExerciseSet, to workoutExercise: WorkoutExercise, context: ModelContext) {
        guard let setIndex = workoutExercise.sortedSets.firstIndex(where: { $0.id == set.id }),
              setIndex > 0 else { return }

        let previousSet = workoutExercise.sortedSets[setIndex - 1]
        set.weight = previousSet.weight
        set.reps = previousSet.reps
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// セットを削除する
    func removeSet(_ set: ExerciseSet, from workoutExercise: WorkoutExercise, context: ModelContext) {
        context.delete(set)
        for (index, s) in workoutExercise.sortedSets.enumerated() {
            s.order = index
        }
    }

    /// 種目をワークアウトから削除する
    func removeExercise(_ exercise: WorkoutExercise, from workout: Workout, context: ModelContext) {
        context.delete(exercise)
        for (index, e) in workout.sortedExercises.enumerated() {
            e.order = index
        }
    }

    /// マシンの空き状況に合わせて種目の実施順を1つ上下へ移動する。
    func moveExercise(_ exercise: WorkoutExercise, by offset: Int, in workout: Workout) {
        var exercises = workout.sortedExercises
        guard let sourceIndex = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        let destinationIndex = sourceIndex + offset
        guard exercises.indices.contains(destinationIndex) else { return }

        exercises.swapAt(sourceIndex, destinationIndex)
        for (index, item) in exercises.enumerated() {
            item.order = index
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - コピー機能

    /// 過去のワークアウトを今日にコピーする（同日の記録があれば種目を追加）
    func copyWorkout(_ source: Workout, context: ModelContext) {
        let target = getOrCreateWorkout(for: Date(), context: context)

        for sourceExercise in source.sortedExercises {
            let newExercise = WorkoutExercise(order: target.workoutExercises.count)
            newExercise.exerciseTemplate = sourceExercise.exerciseTemplate
            newExercise.workout = target
            context.insert(newExercise)

            for sourceSet in sourceExercise.sortedSets {
                let newSet = ExerciseSet(
                    order: sourceSet.order,
                    weight: sourceSet.weight,
                    reps: sourceSet.reps
                )
                newSet.comment = sourceSet.comment
                newSet.workoutExercise = newExercise
                context.insert(newSet)
            }
        }

        activeWorkout = target
    }

    // MARK: - ヘルパー

    /// 設定中の方式で推定1RMを計算する。
    static func estimateOneRM(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        let formula = OneRMFormula(
            rawValue: UserDefaults.standard.string(forKey: "oneRMFormula") ?? ""
        ) ?? .epley

        switch formula {
        case .epley:
            return weight * (1.0 + Double(reps) / 30.0)
        case .oConner:
            return weight * (1.0 + Double(reps) * 0.025)
        }
    }

    /// 指定した種目の全履歴からPR（Personal Record = 最高重量）を取得する
    func personalRecord(for template: ExerciseTemplate, workouts: [Workout]) -> Double {
        var maxWeight = 0.0
        for workout in workouts where !workout.isActive {
            for exercise in workout.workoutExercises where exercise.exerciseTemplate?.id == template.id {
                for set in exercise.sets where set.isCompleted && !set.isBodyweight {
                    maxWeight = max(maxWeight, set.weight)
                }
            }
        }
        return maxWeight
    }
}
