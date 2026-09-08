import SwiftUI
import SwiftData

/// ワークアウト詳細画面（コピー機能・履歴確認）
struct WorkoutDetailView: View {
    let workout: Workout
    @Environment(WorkoutViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingActiveWorkout = false
    @State private var showingEditConfirmation = false
    @State private var showingCopyConfirmation = false
    @State private var showingCopyDatePicker = false
    @State private var copyDestinationDate = Date()
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // ヘッダー統計カード
                statsCard

                // アクションボタン
                if !workout.isActive {
                    VStack(spacing: 12) {
                        editButton
                        copyButton
                    }
                }

                // 種目別記録リスト
                ForEach(workout.sortedExercises) { exercise in
                    ExerciseSummaryCard(workoutExercise: exercise)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(AppScreenBackground())
        .navigationTitle(workout.date.formatted(.dateTime.year().month().day()))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "このメニューをどの日のローテーションとして開始しますか？",
            isPresented: $showingCopyConfirmation,
            titleVisibility: .visible
        ) {
            Button("今日にコピーして開始") {
                performCopy(to: Date())
            }
            Button("過去の日付を選んでコピー") {
                showingCopyDatePicker = true
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("種目・重量・回数を引き継ぎます。")
        }
        .sheet(isPresented: $showingCopyDatePicker) {
            CopyToDateSheet { date in
                performCopy(to: date)
            }
        }
        // アクティブワークアウト画面
        .fullScreenCover(isPresented: $showingActiveWorkout) {
            ActiveWorkoutView(targetDate: copyDestinationDate)
        }
    }

    /// 指定日にコピーしてアクティブワークアウト画面を開く
    private func performCopy(to date: Date) {
        copyDestinationDate = date
        viewModel.copyWorkout(workout, to: date, context: modelContext)
        showingActiveWorkout = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - サブビュー

    /// 記録を編集ボタン
    private var editButton: some View {
        Button {
            showingEditConfirmation = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                Text("記録を編集")
                    .fontWeight(.bold)
            }
            .font(AppFont.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(AppPrimaryButtonStyle())
        .confirmationDialog(
            "この記録を編集しますか？",
            isPresented: $showingEditConfirmation,
            titleVisibility: .visible
        ) {
            Button("編集を開始") {
                viewModel.reopenWorkout(workout)
                showingActiveWorkout = true
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private var copyButton: some View {
        Button { showingCopyConfirmation = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise")
                Text("コピーして開始")
                    .fontWeight(.bold)
            }
            .font(AppFont.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(AppSecondaryButtonStyle())
    }

    /// 統計サマリーカード
    private var statsCard: some View {
        VStack(spacing: 12) {
            // 日付情報
            HStack {
                Label(workout.date.displayString, systemImage: "calendar")
                    .font(AppFont.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Divider()

            // 統計の表示（種目数とボリュームに厳選）
            HStack(spacing: 0) {
                StatItem(
                    value: "\(workout.workoutExercises.count)",
                    label: "種目数",
                    icon: "list.bullet",
                    color: .indigo
                )
                Divider().frame(height: 36)
                StatItem(
                    value: "\(workout.totalSets)",
                    label: "総セット",
                    icon: "square.stack.fill",
                    color: .blue
                )
                Divider().frame(height: 36)
                StatItem(
                    value: formattedVolume,
                    label: "総ボリューム",
                    icon: "scalemass.fill",
                    color: .purple
                )
            }
        }
        .appCard(cornerRadius: AppDesign.cornerLarge, padding: 16)
    }

    private var formattedVolume: String {
        workout.totalVolume.formattedVolume(unit: weightUnit) + weightUnit.rawValue
    }
}

// MARK: - 統計アイテム
struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFont.title3)
                .fontWeight(.bold)
                .monospacedDigit()
            Text(label)
                .font(AppFont.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 種目サマリーカード
struct ExerciseSummaryCard: View {
    let workoutExercise: WorkoutExercise
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 種目名ヘッダー
            HStack(spacing: 10) {
                if let template = workoutExercise.exerciseTemplate {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(template.name)
                            .font(AppFont.headline)
                            .fontWeight(.bold)
                        Text(template.muscleGroup)
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            // セット一覧（詳細表示）
            VStack(spacing: 4) {
                ForEach(Array(workoutExercise.sortedSets.enumerated()), id: \.element.id) { index, set in
                    HStack {
                        Text("\(index + 1) セット目")
                            .font(AppFont.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(set.weight.setWeightDisplay(unit: weightUnit)) × \(set.reps)回")
                            .font(AppFont.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .appCard(cornerRadius: AppDesign.cornerLarge, padding: 16)
    }
}
