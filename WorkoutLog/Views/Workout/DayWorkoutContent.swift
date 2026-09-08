import SwiftUI
import SwiftData

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
