import SwiftUI
import SwiftData

/// 日付詳細画面：選択した日のワークアウト詳細を表示。
/// 左右スワイプで前後の日付へシームレスに遷移する。
struct DayDetailView: View {
    @Query(sort: \Workout.date, order: .forward) private var allWorkouts: [Workout]
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// カレンダーで選択した日付（最初に表示する基準日）
    let initialDate: Date
    /// カレンダーで表示していた月（「戻る」時に月を保持するため）
    let calendarMonth: Date
    @Binding var selectedTab: Int

    @State private var currentDate: Date
    @State private var showingActiveWorkout = false
    private let calendar = Calendar.current

    init(initialDate: Date, calendarMonth: Date, selectedTab: Binding<Int>) {
        self.initialDate = initialDate
        self.calendarMonth = calendarMonth
        self._selectedTab = selectedTab
        self._currentDate = State(initialValue: initialDate)
    }

    /// 完了済みワークアウトのみ
    private var completedWorkouts: [Workout] {
        allWorkouts.filter { !$0.isActive }
    }

    /// 選択日のワークアウト (nil = 記録なし)
    private var workoutForCurrentDate: Workout? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let key = formatter.string(from: currentDate)
        return completedWorkouts.first { formatter.string(from: $0.date) == key }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー：日付表示 + スワイプ操作ヒント
            headerBar

            // コンテンツ：TabViewでスワイプ対応
            TabView(selection: $currentDate) {
                // 前後90日分のページを事前生成
                ForEach(dateRange(), id: \.self) { date in
                    DayPageView(date: date, allWorkouts: completedWorkouts, selectedTab: $selectedTab)
                        .tag(date)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? .linear(duration: 0.15) : .spring(response: 0.4, dampingFraction: 1), value: currentDate)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(dateHeaderString(for: currentDate))
        .background(AppScreenBackground())
    }

    // MARK: - ヘッダーバー（統計カード）
    private var headerBar: some View {
        let workout = workoutForCurrentDate
        let exercises = workout?.workoutExercises.count ?? 0
        let sets = workout?.totalSets ?? 0
        let reps = workout?.workoutExercises.flatMap { $0.sets }.reduce(0) { $0 + $1.reps } ?? 0
        let volume = workout?.totalVolume ?? 0.0

        return AppMetricGroup(items: [
            AppMetricItem(value: "\(exercises)", label: "種目"),
            AppMetricItem(value: "\(sets)", label: "セット"),
            AppMetricItem(value: "\(reps)", label: "回数"),
            AppMetricItem(value: volume > 0 ? String(format: "%.1f", volume) : "0.0", label: "ボリューム")
        ])
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppScreenBackground())
    }

    // MARK: - ヘルパー
    private func dateRange() -> [Date] {
        // 今日から前後90日分（計181日）のDateを生成する
        let today = Date()
        // 開始は過去最古のワークアウト日付から365日前
        let start = calendar.date(byAdding: .day, value: -365, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        var dates: [Date] = []
        var current = start
        while current <= end {
            // 時刻を00:00:00に正規化してタグとして使用
            if let normalized = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: current)) {
                dates.append(normalized)
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? end
        }
        return dates
    }

    private func dateHeaderString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// MARK: - 各日付のページビュー
/// 1日分のコンテンツ：ワークアウトがある日は詳細、ない日は空の状態を表示。
struct DayPageView: View {
    let date: Date
    let allWorkouts: [Workout]
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTab: Int

    @State private var showingActiveWorkout = false
    private let calendar = Calendar.current

    private var workout: Workout? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let key = formatter.string(from: date)
        return allWorkouts.first { formatter.string(from: $0.date) == key }
    }

    var body: some View {
        Group {
            if let workout = workout {
                // ワークアウトがある日：種目・セット一覧を表示
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(workout.sortedExercises) { workoutExercise in
                            ExerciseSummaryCard(workoutExercise: workoutExercise)
                        }

                        // 編集ボタン
                        Button {
                            selectedTab = 0
                            showingActiveWorkout = true
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            } else {
                // トレーニング記録なし：空の状態
                emptyStateView
            }
        }
        .fullScreenCover(isPresented: $showingActiveWorkout) {
            ActiveWorkoutView(targetDate: date)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            AppEmptyState(
                icon: "figure.strengthtraining.traditional",
                title: "この日の記録はありません",
                message: "種目を追加するとトレーニングを開始できます"
            )

            Button {
                selectedTab = 0
                showingActiveWorkout = true
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
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppScreenBackground())
    }
}


// MARK: - 統計ミニカード
struct DayStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(.caption2, design: .default))
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            Text(value)
                .font(AppFont.subheadline)
                .fontWeight(.bold)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
