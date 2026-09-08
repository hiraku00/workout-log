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
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg

    @State private var showingExercisePicker = false
    @State private var showingDeleteConfirmation = false
    @State private var showingExerciseDeleteConfirmation = false
    @State private var showingCopyConfirmation = false
    @State private var showingCopyDatePicker = false
    @State private var exerciseToDelete: WorkoutExercise?
    @State private var workout: Workout?
    @State private var reorderHapticTrigger = false

    var body: some View {
        VStack(spacing: 16) {
            if let workout {
                headerSummarySection(for: workout)

                // 過去日を見ている時は、下までスクロールしなくてもすぐコピーできるよう
                // 記録一覧より前に置く。
                if !Calendar.current.isDateInToday(targetDate), !workout.sortedExercises.isEmpty {
                    copyToTodayButton(workout)
                }

                if workout.sortedExercises.isEmpty {
                    emptyExercisePlaceholder
                } else {
                    ForEach(Array(workout.sortedExercises.enumerated()), id: \.element.id) { index, exercise in
                        exerciseListCard(exercise, at: index, in: workout)
                    }
                }

                addExerciseButton

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
        .confirmationDialog(
            "この種目を削除しますか？",
            isPresented: $showingExerciseDeleteConfirmation,
            titleVisibility: .visible,
            presenting: exerciseToDelete
        ) { exercise in
            Button("種目を削除", role: .destructive) {
                if let workout {
                    withAnimation {
                        viewModel.removeExercise(exercise, from: workout, context: modelContext)
                    }
                }
                exerciseToDelete = nil
            }
            Button("キャンセル", role: .cancel) {
                exerciseToDelete = nil
            }
        } message: { exercise in
            Text("\(exercise.exerciseTemplate?.name ?? "この種目")とすべてのセット記録を削除します。")
        }
        .sheet(isPresented: $showingCopyDatePicker) {
            if let workout {
                CopyToDateSheet { date in
                    performCopy(workout, to: date)
                }
            }
        }
        .onAppear {
            ensureWorkout()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: reorderHapticTrigger)
    }

    /// 指定日にコピーしてホームタブへ移動する
    private func performCopy(_ workout: Workout, to date: Date) {
        viewModel.copyWorkout(workout, to: date, context: modelContext)
        viewModel.openDayOnHome(Calendar.current.startOfDay(for: date))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
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
                ExerciseRowView(
                    workoutExercise: exercise,
                    onDeleteSet: { set in
                        withAnimation {
                            viewModel.removeSet(set, from: exercise, context: modelContext)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    },
                    embedded: true
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            HStack(spacing: 2) {
                Button {
                    withAnimation(.snappy) {
                        viewModel.moveExercise(exercise, by: -1, in: workout)
                    }
                    reorderHapticTrigger.toggle()
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
                    reorderHapticTrigger.toggle()
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: 34, height: 34)
                }
                .disabled(index == workout.sortedExercises.count - 1)
                .accessibilityLabel("\(exercise.exerciseTemplate?.name ?? "種目")を下へ移動")

                Button(role: .destructive) {
                    exerciseToDelete = exercise
                    showingExerciseDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 34, height: 34)
                }
                .accessibilityLabel("\(exercise.exerciseTemplate?.name ?? "種目")を削除")
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
                reorderHapticTrigger.toggle()
            }
            .disabled(index == 0)
            Button("下へ移動", systemImage: "chevron.down") {
                viewModel.moveExercise(exercise, by: 1, in: workout)
                reorderHapticTrigger.toggle()
            }
            .disabled(index == workout.sortedExercises.count - 1)
            Button("削除", role: .destructive) {
                exerciseToDelete = exercise
                showingExerciseDeleteConfirmation = true
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
            Label("コピーして開始", systemImage: "arrow.counterclockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(AppPrimaryButtonStyle())
        .confirmationDialog(
            "この日のメニューをどの日の記録として開始しますか？",
            isPresented: $showingCopyConfirmation,
            titleVisibility: .visible
        ) {
            Button("今日にコピーして開始") {
                performCopy(workout, to: Date())
            }
            Button("過去の日付を選んでコピー") {
                showingCopyDatePicker = true
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("種目・重量・回数を引き継ぎます。")
        }
    }

    private func formattedVolume(for workout: Workout) -> String {
        workout.totalVolume.formattedVolume(unit: weightUnit)
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
    ///
    /// 各ページ（前後1年分、最大約395件）を「選択中の前後だけの窓」に絞る最適化を
    /// 一度試したが、`currentDate`の変化と同時に`ForEach`の配列を組み替えると、
    /// スワイプ中のページ遷移とインデックスがずれて日付を1日飛ばしてしまう不具合が
    /// シミュレータで再現したため、安全な全件生成に戻している。対応するなら
    /// `UIPageViewController`を直接使うなど、選択とデータ変更を同時に起こさない
    /// 設計が必要。
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
