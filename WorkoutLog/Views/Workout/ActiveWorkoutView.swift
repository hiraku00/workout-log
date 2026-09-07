import SwiftUI
import SwiftData
import AVFoundation
import AlarmKit
import UserNotifications

/// 種目詳細画面 - セット入力・休憩タイマー
struct ExerciseDetailView: View {
    let workoutExercise: WorkoutExercise
    let allWorkouts: [Workout]

    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("weightUnit") private var weightUnit = "kg"
    @AppStorage("restTimerDuration") private var timerDuration = 60

    @State private var timerRunning = false
    @State private var timerSeconds = 60
    @State private var timer: Timer?
    @State private var timerEndDate: Date?
    @State private var showingTimerDurationPicker = false
    @State private var showingTimerCompletionAlert = false
    @State private var timerCompletionAlarm = TimerCompletionAlarm()
    @State private var usingSystemAlarm = false

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
        .alert("休憩終了", isPresented: $showingTimerCompletionAlert) {
            Button("次のセットへ", role: .cancel) {}
        } message: {
            Text("次のセットを始めましょう。")
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                synchronizeTimerAfterForeground()
            case .background:
                timer?.invalidate()
                timer = nil
            default:
                break
            }
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
                                : WorkoutViewModel.estimateOneRM(weight: set.weight, reps: set.reps)
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

    private var previousWorkoutInfo: (date: Date, sets: [(weight: Double, reps: Int)])? {
        guard let record = previousWorkoutRecord else { return nil }
        let sets = record.exercise.sortedSets
            .filter(\.isCompleted)
            .map { (weight: $0.weight, reps: $0.reps) }
        return (date: record.workout.date, sets: sets)
    }

    private func previousWorkoutSet(at index: Int) -> ExerciseSet? {
        let previousSets = previousWorkoutRecord?.exercise.sortedSets.filter(\.isCompleted) ?? []
        return index < previousSets.count ? previousSets[index] : previousSets.last
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
        stopTicker()
        cancelTimerNotification()
        timerRunning = true
        timerSeconds = timerDuration
        let endDate = Date().addingTimeInterval(TimeInterval(timerDuration))
        timerEndDate = endDate
        scheduleTimerAlert(at: endDate)
        startTicker()
    }

    private func startTicker() {
        let nextTimer = Timer(timeInterval: 0.5, repeats: true) { _ in
            updateTimerFromEndDate(presentCompletionAlert: true)
        }
        timer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    private func stopTimer() {
        timerRunning = false
        timerEndDate = nil
        stopTicker()
        cancelTimerNotification()
        timerSeconds = timerDuration
    }

    private func stopTicker() {
        timer?.invalidate()
        timer = nil
    }

    private func synchronizeTimerAfterForeground() {
        guard timerRunning else { return }
        updateTimerFromEndDate(presentCompletionAlert: false)
        if timerRunning { startTicker() }
    }

    private func updateTimerFromEndDate(presentCompletionAlert: Bool) {
        guard let timerEndDate else { return }
        let remaining = timerEndDate.timeIntervalSinceNow
        guard remaining > 0 else {
            timerSeconds = 0
            timerRunning = false
            self.timerEndDate = nil
            stopTicker()
            if presentCompletionAlert && !usingSystemAlarm {
                playTimerCompletionAlert()
                showingTimerCompletionAlert = true
            }
            usingSystemAlarm = false
            return
        }
        timerSeconds = Int(ceil(remaining))
    }

    private func scheduleTimerAlert(at endDate: Date) {
        usingSystemAlarm = false
        Task { @MainActor in
            await scheduleAlarmKitTimer(at: endDate)
        }
    }

    @available(iOS 26.0, *)
    @MainActor
    private func scheduleAlarmKitTimer(at endDate: Date) async {
        do {
            let manager = AlarmManager.shared
            let authorization: AlarmManager.AuthorizationState
            if manager.authorizationState == .notDetermined {
                authorization = try await manager.requestAuthorization()
            } else {
                authorization = manager.authorizationState
            }

            guard authorization == .authorized,
                  timerRunning,
                  timerEndDate == endDate else {
                scheduleTimerNotification(at: endDate)
                return
            }

            let alert: AlarmPresentation.Alert
            if #available(iOS 26.1, *) {
                alert = AlarmPresentation.Alert(title: "休憩終了")
            } else {
                let stopButton = AlarmButton(
                    text: "停止",
                    textColor: .white,
                    systemImageName: "stop.circle.fill"
                )
                alert = AlarmPresentation.Alert(title: "休憩終了", stopButton: stopButton)
            }

            let attributes = AlarmAttributes<RestTimerAlarmMetadata>(
                presentation: AlarmPresentation(alert: alert),
                tintColor: AppDesign.accent
            )
            let configuration = AlarmManager.AlarmConfiguration<RestTimerAlarmMetadata>.alarm(
                schedule: .fixed(endDate),
                attributes: attributes,
                sound: .default
            )

            try? manager.cancel(id: timerAlarmID)
            _ = try await manager.schedule(id: timerAlarmID, configuration: configuration)
            usingSystemAlarm = true
        } catch {
            scheduleTimerNotification(at: endDate)
            print("AlarmKitでの休憩アラーム登録に失敗しました: \(error)")
        }
    }

    private func scheduleTimerNotification(at endDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { addTimerNotification(to: center, at: endDate) }
                }
            case .authorized, .provisional, .ephemeral:
                addTimerNotification(to: center, at: endDate)
            default:
                break
            }
        }
    }

    private func addTimerNotification(to center: UNUserNotificationCenter, at endDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "休憩終了"
        content.body = "次のセットを始めましょう。"
        content.interruptionLevel = .timeSensitive
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, endDate.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: timerNotificationIdentifier, content: content, trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: [timerNotificationIdentifier])
        center.add(request)
    }

    private func cancelTimerNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [timerNotificationIdentifier])
        try? AlarmManager.shared.cancel(id: timerAlarmID)
        usingSystemAlarm = false
    }

    private var timerNotificationIdentifier: String {
        "rest-timer-\(workoutExercise.id.uuidString)"
    }

    private var timerAlarmID: UUID {
        workoutExercise.id
    }

    /// 前面表示中は通知バナーに依存せず、同梱アラーム音を直接鳴らす。
    private func playTimerCompletionAlert() {
        timerCompletionAlarm.play()
    }

}

@available(iOS 26.0, *)
private struct RestTimerAlarmMetadata: AlarmMetadata {}

/// 消音スイッチの状態に左右されず、前面表示中の休憩終了を伝える短いアラーム。
private final class TimerCompletionAlarm: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    func play() {
        guard let url = Bundle.main.url(forResource: "rest_timer_alarm", withExtension: "wav") else {
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = 1
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            print("休憩終了アラームの再生に失敗しました: \(error)")
        }
    }

    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        player = nil
        restoreOtherAudio()
    }

    func audioPlayerDecodeErrorDidOccur(_: AVAudioPlayer, error _: Error?) {
        player = nil
        restoreOtherAudio()
    }

    private func restoreOtherAudio() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
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
    @State private var showingExerciseDeleteConfirmation = false
    @State private var showingCopyConfirmation = false
    @State private var showingCopyDatePicker = false
    @State private var exerciseToDelete: WorkoutExercise?
    @State private var workout: Workout?

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
            }
            .disabled(index == 0)
            Button("下へ移動", systemImage: "chevron.down") {
                viewModel.moveExercise(exercise, by: 1, in: workout)
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
