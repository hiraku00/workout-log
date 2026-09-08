import SwiftUI
import SwiftData

/// 種目詳細画面 - セット入力・休憩タイマー
struct ExerciseDetailView: View {
    let workoutExercise: WorkoutExercise
    let allWorkouts: [Workout]

    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @AppStorage("oneRMFormula") private var oneRMFormula = OneRMFormula.epley.rawValue
    @AppStorage("restTimerDuration") private var timerDuration = 60

    @State private var showingTimerDurationPicker = false
    @State private var addSetHapticTrigger = false

    private let timerDurationOptions = Array(stride(from: 10, through: 300, by: 5))

    /// この種目に対して休憩タイマーが進行中か（他の種目のタイマーとは区別する）
    private var isTimerActiveForThisExercise: Bool {
        viewModel.restTimer.isRunning && viewModel.restTimer.activeExerciseID == workoutExercise.id
    }

    var body: some View {
        // 全履歴から一致する種目を探す処理（previousWorkoutRecord）は、以前はセット行ごとに
        // 呼び直されており、セット数×履歴件数のオーダーで無駄が大きかった。ここで1回だけ
        // 計算し、以降はこの値を使い回す。
        let sets = workoutExercise.sortedSets
        let previousRecord = previousWorkoutRecord
        let previousSets = previousRecord?.exercise.sortedSets.filter(\.isCompleted) ?? []

        ScrollView {
            VStack(spacing: 16) {
                if let template = workoutExercise.exerciseTemplate {
                    previousWorkoutSection(template: template, info: previousWorkoutInfo(record: previousRecord))
                }

                SetRowColumnHeader()
                    .padding(.horizontal, 16)

                ForEach(Array(sets.enumerated()), id: \.element.id) { setIndex, set in
                    let previousSetInWorkout = setIndex > 0 ? sets[setIndex - 1] : nil
                    let previousWorkoutSet = previousWorkoutSet(at: setIndex, in: previousSets)
                    let noteSource = [previousSetInWorkout, previousWorkoutSet]
                        .compactMap { $0 }
                        .first { !$0.comment.isEmpty }

                    SetRowView(
                        exerciseSet: set,
                        setNumber: setIndex + 1,
                        onDelete: {
                            withAnimation {
                                viewModel.removeSet(set, from: workoutExercise, context: modelContext)
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        },
                        onCopyWeight: previousSetInWorkout.map { previousSet in
                            { set.weight = previousSet.weight; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                        },
                        onCopyReps: previousSetInWorkout.map { previousSet in
                            { set.reps = previousSet.reps; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                        },
                        onCopyNote: noteSource.map { source in
                            { set.comment = source.comment; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                        },
                        onCompleted: startTimer
                    )
                    .padding(.horizontal, 16)
                }

                addSetButton
            }
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(AppScreenBackground())
        .sensoryFeedback(.impact(weight: .light), trigger: addSetHapticTrigger)
        .safeAreaInset(edge: .top, spacing: 0) {
            RestTimerBar(
                timerDuration: timerDuration,
                timerSeconds: viewModel.restTimer.secondsRemaining,
                timerRunning: isTimerActiveForThisExercise,
                onStart: startTimer,
                onStop: stopTimer,
                onEditDuration: { showingTimerDurationPicker = true }
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppScreenBackground())
        }
        .navigationTitle(workoutExercise.exerciseTemplate?.name ?? "種目詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let name = workoutExercise.exerciseTemplate?.name {
                    Button {
                        ExerciseReference.openImageSearch(for: name)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("フォームを確認")
                        }
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("\(name)の参考画像を検索")
                }
            }
        }
        .sheet(isPresented: $showingTimerDurationPicker) {
            NavigationStack {
                Picker("休憩時間", selection: $timerDuration) {
                    ForEach(timerDurationOptions, id: \.self) { seconds in
                        Text("\(seconds)秒").tag(seconds)
                    }
                }
                .pickerStyle(.wheel)
                .navigationTitle("休憩タイマー")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完了") {
                            showingTimerDurationPicker = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.height(260)])
        }
        .alert("休憩終了", isPresented: Binding(
            get: { viewModel.restTimer.justCompletedExerciseID == workoutExercise.id },
            set: { isPresented in
                if !isPresented { viewModel.restTimer.justCompletedExerciseID = nil }
            }
        )) {
            Button("次のセットへ", role: .cancel) {}
        } message: {
            Text("次のセットを始めましょう。")
        }
    }

    private var addSetButton: some View {
        Button {
            withAnimation(reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.3, dampingFraction: 1)) {
                viewModel.addSet(to: workoutExercise, context: modelContext)
            }
            addSetHapticTrigger.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text("セットを追加")
            }
            .font(AppFont.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 12)
    }

    private func previousWorkoutSection(
        template: ExerciseTemplate,
        info: (date: Date, sets: [(weight: Double, reps: Int)])?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("前回の記録")
                    .font(AppFont.subheadline)
                    .fontWeight(.semibold)

                if let info {
                    Text(info.date.displayString)
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                NavigationLink {
                    ExerciseHistoryDetailView(template: template, workouts: historyWorkouts)
                } label: {
                    Label("履歴", systemImage: "clock.arrow.circlepath")
                        .font(AppFont.caption)
                        .fontWeight(.semibold)
                }
            }

            if let info {
                VStack(spacing: 0) {
                    ForEach(Array(info.sets.enumerated()), id: \.offset) { index, set in
                        Divider()
                        HStack(spacing: 0) {
                            Text("\(index + 1)")
                                .font(AppFont.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: WorkoutRecordColumn.set, alignment: .leading)
                            Spacer(minLength: SetRowLayout.minimumGap)
                            Text(set.weight.setWeightDisplay(unit: weightUnit))
                                .font(AppFont.caption)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .frame(width: WorkoutRecordColumn.weight, alignment: .trailing)
                            Spacer(minLength: SetRowLayout.minimumGap)
                            Text("\(set.reps)回")
                                .font(AppFont.caption)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .frame(width: WorkoutRecordColumn.reps, alignment: .trailing)
                            Spacer(minLength: SetRowLayout.minimumGap)

                            let estimatedOneRM = set.weight == ExerciseSet.bodyweightValue
                                ? 0
                                : WorkoutViewModel.estimateOneRM(
                                    weight: set.weight,
                                    reps: set.reps,
                                    formula: OneRMFormula(rawValue: oneRMFormula) ?? .epley
                                )
                            Text(estimatedOneRM > 0 ? estimatedOneRM.setWeightDisplay(unit: weightUnit) : "—")
                                .font(AppFont.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: WorkoutRecordColumn.oneRM, alignment: .trailing)
                            Spacer(minLength: SetRowLayout.minimumGap)
                            Color.clear.frame(width: WorkoutRecordColumn.complete)
                            Spacer(minLength: SetRowLayout.minimumGap)
                            Color.clear.frame(width: WorkoutRecordColumn.delete)
                        }
                        .frame(minHeight: 32)
                    }
                }
                .padding(.horizontal, 4)
                .background(AppDesign.subtleFill)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous))
            } else {
                Text("この種目の過去記録はありません")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }
        }
        .appCard(cornerRadius: AppDesign.cornerMedium, padding: 12)
        .padding(.horizontal, 12)
    }

    private func previousWorkoutInfo(record: (workout: Workout, exercise: WorkoutExercise)?) -> (date: Date, sets: [(weight: Double, reps: Int)])? {
        guard let record else { return nil }
        let sets = record.exercise.sortedSets
            .filter(\.isCompleted)
            .map { (weight: $0.weight, reps: $0.reps) }
        return (date: record.workout.date, sets: sets)
    }

    private func previousWorkoutSet(at index: Int, in previousSets: [ExerciseSet]) -> ExerciseSet? {
        index < previousSets.count ? previousSets[index] : previousSets.last
    }

    private var previousWorkoutRecord: (workout: Workout, exercise: WorkoutExercise)? {
        guard let template = workoutExercise.exerciseTemplate else { return nil }
        let currentWorkoutId = workoutExercise.workout?.id
        let currentDate = workoutExercise.workout?.date ?? .now

        for workout in allWorkouts
            .filter({ !$0.isActive && $0.id != currentWorkoutId && $0.date < currentDate })
            .sorted(by: { $0.date > $1.date }) {
            if let exercise = matchingExercise(in: workout, template: template),
               exercise.sortedSets.contains(where: \.isCompleted) {
                return (workout, exercise)
            }
        }
        return nil
    }

    private var historyWorkouts: [Workout] {
        let currentWorkoutId = workoutExercise.workout?.id
        return allWorkouts.filter { !$0.isActive && $0.id != currentWorkoutId }
    }

    private func matchingExercise(in workout: Workout, template: ExerciseTemplate) -> WorkoutExercise? {
        workout.workoutExercises.first { exercise in
            guard let candidate = exercise.exerciseTemplate else { return false }
            return candidate.representsSameExercise(as: template)
        }
    }

    private func startTimer() {
        viewModel.restTimer.start(for: workoutExercise.id, duration: timerDuration)
    }

    private func stopTimer() {
        viewModel.restTimer.stop()
    }
}
