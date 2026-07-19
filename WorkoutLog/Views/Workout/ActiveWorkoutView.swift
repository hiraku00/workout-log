import SwiftUI
import SwiftData
import AudioToolbox

/// 種目詳細画面 - セット入力・休憩タイマー
struct ExerciseDetailView: View {
    let workoutExercise: WorkoutExercise
    let allWorkouts: [Workout]

    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("weightUnit") private var weightUnit = "kg"
    @AppStorage("restTimerDuration") private var timerDuration = 60

    @State private var timerRunning = false
    @State private var timerSeconds = 60
    @State private var timer: Timer?
    @State private var showingTimerDurationPicker = false

    private let timerDurationOptions = Array(stride(from: 10, through: 300, by: 5))

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let template = workoutExercise.exerciseTemplate {
                    previousWorkoutSection(template: template, info: previousWorkoutInfo)
                }

                SetRowColumnHeader()
                    .padding(.horizontal, 16)

                ForEach(workoutExercise.sortedSets) { set in
                    let setIndex = workoutExercise.sortedSets.firstIndex(where: { $0.id == set.id }) ?? 0
                    let previousSetInWorkout = setIndex > 0 ? workoutExercise.sortedSets[setIndex - 1] : nil
                    let previousWorkoutSet = previousWorkoutSet(at: setIndex)
                    let noteSource = [previousSetInWorkout, previousWorkoutSet]
                        .compactMap { $0 }
                        .first { !$0.comment.isEmpty }

                    SetRowView(
                        exerciseSet: set,
                        setNumber: setIndex + 1,
                        previousWorkoutSet: previousWorkoutSet,
                        onDelete: {
                            withAnimation {
                                viewModel.removeSet(set, from: workoutExercise, context: modelContext)
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        },
                        onCopyWeight: previousSetInWorkout.map { prev in
                            { set.weight = prev.weight; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                        },
                        onCopyReps: previousSetInWorkout.map { prev in
                            { set.reps = prev.reps; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
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
        .safeAreaInset(edge: .top, spacing: 0) {
            RestTimerBar(
                timerDuration: timerDuration,
                timerSeconds: timerSeconds,
                timerRunning: timerRunning,
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
                            timerSeconds = timerDuration
                            showingTimerDurationPicker = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.height(260)])
        }
        .onDisappear {
            stopTimer()
        }
    }

    private var addSetButton: some View {
        Button {
            withAnimation(reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.3, dampingFraction: 1)) {
                viewModel.addSet(to: workoutExercise, context: modelContext)
            }
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
                        HStack(spacing: WorkoutRecordColumn.spacing) {
                            Text("\(index + 1)")
                                .font(AppFont.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: WorkoutRecordColumn.set, alignment: .leading)
                            Text(set.weight.setWeightDisplay(unit: weightUnit))
                                .font(AppFont.caption)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .frame(width: WorkoutRecordColumn.weight, alignment: .trailing)
                            Text("\(set.reps)回")
                                .font(AppFont.caption)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .frame(width: WorkoutRecordColumn.reps, alignment: .trailing)

                            let estimatedOneRM = set.weight == ExerciseSet.bodyweightValue
                                ? 0
                                : WorkoutViewModel.estimateOneRM(weight: set.weight, reps: set.reps)
                            Text(estimatedOneRM > 0 ? estimatedOneRM.setWeightDisplay(unit: weightUnit) : "—")
                                .font(AppFont.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: WorkoutRecordColumn.oneRM, alignment: .trailing)
                            Spacer().frame(width: WorkoutRecordColumn.status)
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

    private var previousWorkoutInfo: (date: Date, sets: [(weight: Double, reps: Int)])? {
        guard let record = previousWorkoutRecord else { return nil }
        let sets = record.exercise.sortedSets
            .filter(\.isCompleted)
            .map { (weight: $0.weight, reps: $0.reps) }
        return (date: record.workout.date, sets: sets)
    }

    private func previousWorkoutSet(at index: Int) -> ExerciseSet? {
        let prevSets = previousWorkoutRecord?.exercise.sortedSets.filter(\.isCompleted) ?? []
        return index < prevSets.count ? prevSets[index] : prevSets.last
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
        timer?.invalidate()
        timer = nil
        timerRunning = true
        timerSeconds = timerDuration

        let nextTimer = Timer(timeInterval: 1.0, repeats: true) { _ in
            if timerSeconds > 1 {
                timerSeconds -= 1
            } else {
                timerSeconds = 0
                timerRunning = false
                timer?.invalidate()
                timer = nil
                notifyTimerFinished()
            }
        }
        timer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    private func stopTimer() {
        timerRunning = false
        timer?.invalidate()
        timer = nil
        timerSeconds = timerDuration
    }

    private func notifyTimerFinished() {
        // 1回だけでは気づきにくいため、効果音と通知バイブを間隔を空けて3回鳴らす。
        AudioServicesPlayAlertSound(1005)
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        for delay in [0.65, 1.3] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                AudioServicesPlayAlertSound(1005)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

/// 休憩タイマーバー（添付アプリ風）
struct RestTimerBar: View {
    let timerDuration: Int
    let timerSeconds: Int
    let timerRunning: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onEditDuration: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label("休憩", systemImage: "timer")
                .font(AppFont.subheadline).fontWeight(.semibold)

            Spacer()

            Button(action: onEditDuration) {
                Text(TimeInterval(timerRunning ? timerSeconds : timerDuration).timerString)
                    .font(AppFont.title3)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(timerRunning ? AppDesign.accent : Color.primary)
                    .frame(minWidth: 64)
            }
            .buttonStyle(.plain)
            .disabled(timerRunning)

            Button {
                if timerRunning {
                    onStop()
                } else {
                    onStart()
                }
            } label: {
                Image(systemName: timerRunning ? "stop.fill" : "play.fill")
            }
            .buttonStyle(AppIconButtonStyle())
            .accessibilityLabel(timerRunning ? "タイマーを停止" : "タイマーを開始")
        }
        .appCard(cornerRadius: AppDesign.cornerLarge, padding: 12)
        .sensoryFeedback(.impact(weight: .light), trigger: timerRunning)
    }
}

/// 1日分のワークアウト内容（種目一覧）
struct DayWorkoutContent: View {
    let targetDate: Date

    @Environment(WorkoutViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var allWorkouts: [Workout]
    @AppStorage("weightUnit") private var weightUnit = "kg"

    @State private var showingExercisePicker = false
    @State private var showingDeleteConfirmation = false
    @State private var showingCopyConfirmation = false
    @State private var workout: Workout?

    var body: some View {
        VStack(spacing: 16) {
            if let workout {
                headerSummarySection(for: workout)

                if workout.sortedExercises.isEmpty {
                    emptyExercisePlaceholder
                } else {
                    ForEach(Array(workout.sortedExercises.enumerated()), id: \.element.id) { index, exercise in
                        exerciseListCard(exercise, at: index, in: workout)
                    }
                }

                addExerciseButton

                if !Calendar.current.isDateInToday(targetDate), !workout.sortedExercises.isEmpty {
                    copyToTodayButton(workout)
                }

                Button("この日の記録をすべて削除", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .font(AppFont.caption)
            } else {
                emptyDayPlaceholder
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView(existingTemplateIDs: Set(workout?.workoutExercises.compactMap { $0.exerciseTemplate?.id } ?? [])) { templates in
                // 種目を実際に選んだ時点で初めてワークアウトを作成する（キャンセル時に空の記録が残らないようにするため）
                let target = workout ?? viewModel.getOrCreateWorkout(for: targetDate, context: modelContext)
                workout = target
                for template in templates {
                    viewModel.addExercise(template, to: target, context: modelContext)
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
        .confirmationDialog(
            "この日の記録をすべて削除しますか？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                if let workout {
                    viewModel.cancelWorkout(workout, context: modelContext)
                    self.workout = nil
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .onAppear {
            ensureWorkout()
        }
    }

    private func ensureWorkout() {
        if workout == nil {
            workout = viewModel.workout(for: targetDate, in: modelContext)
        }
    }

    private func exerciseListCard(_ exercise: WorkoutExercise, at index: Int, in workout: Workout) -> some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                ExerciseDetailView(workoutExercise: exercise, allWorkouts: allWorkouts)
            } label: {
                ExerciseRowView(workoutExercise: exercise, embedded: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            HStack(spacing: 2) {
                Button {
                    withAnimation(.snappy) {
                        viewModel.moveExercise(exercise, by: -1, in: workout)
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(width: 34, height: 34)
                }
                .disabled(index == 0)
                .accessibilityLabel("\(exercise.exerciseTemplate?.name ?? "種目")を上へ移動")

                Button {
                    withAnimation(.snappy) {
                        viewModel.moveExercise(exercise, by: 1, in: workout)
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: 34, height: 34)
                }
                .disabled(index == workout.sortedExercises.count - 1)
                .accessibilityLabel("\(exercise.exerciseTemplate?.name ?? "種目")を下へ移動")
            }
            .font(AppFont.subheadline)
            .fontWeight(.semibold)
            .padding(.top, 16)
            .padding(.trailing, 10)
        }
        .background(AppDesign.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerLarge, style: .continuous)
                .stroke(AppDesign.hairline, lineWidth: 0.5)
        )
        .contextMenu {
            Button("上へ移動", systemImage: "chevron.up") {
                viewModel.moveExercise(exercise, by: -1, in: workout)
            }
            .disabled(index == 0)
            Button("下へ移動", systemImage: "chevron.down") {
                viewModel.moveExercise(exercise, by: 1, in: workout)
            }
            .disabled(index == workout.sortedExercises.count - 1)
            Button("削除", role: .destructive) {
                withAnimation {
                    viewModel.removeExercise(exercise, from: workout, context: modelContext)
                }
            }
        }
    }

    private func headerSummarySection(for workout: Workout) -> some View {
        return AppMetricGroup(items: [
            AppMetricItem(value: "\(workout.completedExerciseCount)", label: "種目"),
            AppMetricItem(value: "\(workout.totalSets)", label: "セット"),
            AppMetricItem(value: "\(workout.totalReps)", label: "回数"),
            AppMetricItem(value: formattedVolume(for: workout), label: "ボリューム")
        ])
    }

    private var emptyExercisePlaceholder: some View {
        AppEmptyState(
            icon: "dumbbell",
            title: "種目がありません",
            message: "最初の種目を追加して記録を始めましょう"
        )
    }

    private var emptyDayPlaceholder: some View {
        VStack(spacing: 12) {
            AppEmptyState(
                icon: "calendar.badge.plus",
                title: "この日の記録はありません",
                message: "種目を追加するとトレーニングを開始できます"
            )
            addExerciseButton
        }
        .padding(.vertical, 16)
    }

    private var addExerciseButton: some View {
        Button {
            showingExercisePicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("種目を追加")
            }
            .font(AppFont.headline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(AppSecondaryButtonStyle())
    }

    private func copyToTodayButton(_ workout: Workout) -> some View {
        Button { showingCopyConfirmation = true } label: {
            Label("今日にコピーして開始", systemImage: "arrow.counterclockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(AppPrimaryButtonStyle())
        .confirmationDialog(
            "この日のメニューを今日の記録として開始しますか？",
            isPresented: $showingCopyConfirmation,
            titleVisibility: .visible
        ) {
            Button("今日にコピーして開始") {
                viewModel.copyWorkout(workout, context: modelContext)
                viewModel.openDayOnHome(Calendar.current.startOfDay(for: Date()))
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("種目・重量・回数を引き継ぎます。")
        }
    }

    private func formattedVolume(for workout: Workout) -> String {
        let vol = weightUnit == "lbs" ? workout.totalVolume * 2.20462 : workout.totalVolume
        return vol >= 1000
            ? String(format: "%.1fk", vol / 1000)
            : String(format: "%.0f", vol)
    }
}

/// 1日分のワークアウト画面（履歴カレンダーからの遷移先）
/// 左右スワイプで前後の日付へシームレスに遷移できる。
struct DayWorkoutView: View {
    let targetDate: Date

    @State private var currentDate: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(targetDate: Date) {
        self.targetDate = targetDate
        self._currentDate = State(initialValue: Calendar.current.startOfDay(for: targetDate))
    }

    var body: some View {
        TabView(selection: $currentDate) {
            ForEach(dateRange(), id: \.self) { date in
                ScrollView {
                    DayWorkoutContent(targetDate: date)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                }
                .tag(date)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(reduceMotion ? .linear(duration: 0.15) : .spring(response: 0.4, dampingFraction: 1), value: currentDate)
        .background(AppScreenBackground())
        .navigationTitle(currentDate.formatted(.dateTime.year().month().day()))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 前後365日分の日付を生成（スワイプで遷移できる範囲）
    private func dateRange() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -365, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 30, to: today) ?? today

        var dates: [Date] = []
        var current = start
        while current <= end {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? end
        }
        return dates
    }
}

// 後方互換の型名
typealias ActiveWorkoutView = DayWorkoutView

// MARK: - ヘッダー統計ボックス
struct HeaderStatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(AppFont.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

            Text(value)
                .font(AppFont.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppDesign.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous)
                .stroke(AppDesign.hairline, lineWidth: 0.5)
        )
    }
}
