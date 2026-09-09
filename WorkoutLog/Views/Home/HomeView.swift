import SwiftUI
import SwiftData

/// ホーム画面：月間の記録と今日の状態を静かに把握する
struct HomeView: View {
    @Environment(WorkoutViewModel.self) private var viewModel
    @Query(sort: \Workout.date, order: .reverse) private var allWorkouts: [Workout]
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @AppStorage("oneRMFormula") private var oneRMFormula = OneRMFormula.epley.rawValue
    @Binding var selectedTab: Int
    @State private var navigationPath = NavigationPath()

    private let calendar = Calendar.current

    /// ホーム画面が必要とする集計値を一度に計算する。
    ///
    /// 以前はこれを計算プロパティにしていたため、`body`内で`summary`を参照するたびに
    /// （`activitySummary`・`bestUpdatesSection`・`todaySection`など複数箇所）
    /// `allWorkouts`の再ソート・再集計が毎回走っていた。`body`の先頭で1回だけ計算し、
    /// 各セクションへ値として渡すことで、1回の描画につき1回の計算に抑える。
    private var summary: HomeWorkoutSummary {
        WorkoutInsights.homeSummary(
            workouts: allWorkouts,
            calendar: calendar,
            oneRMFormula: OneRMFormula(rawValue: oneRMFormula) ?? .epley
        )
    }

    private func previousWorkoutValue(for previousWorkout: Workout?) -> String {
        guard let previousWorkout else { return "なし" }
        let previousDay = calendar.startOfDay(for: previousWorkout.date)
        let today = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: previousDay, to: today).day ?? 0
        return days == 1 ? "昨日" : "\(days)日前"
    }

    var body: some View {
        let summary = self.summary
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Date.now.displayString)
                            .font(AppFont.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppDesign.accent)
                        Text("今日のトレーニング")
                            .font(AppFont.largeTitle)
                            .tracking(-0.7)
                            .accessibilityAddTraits(.isHeader)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    dashboardSection(workoutDates: summary.workoutDates)
                    activitySummary(summary: summary)
                    bestUpdatesSection(summary: summary)
                    todaySection(summary: summary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(AppScreenBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Date.self) { date in
                DayWorkoutView(targetDate: date)
            }
        }
        .onChange(of: viewModel.homeNavigationDate) { _, newDate in
            guard let newDate else { return }
            // 今日を含めて、どの日付も同じようにスワイプ可能な日別画面へ遷移する
            navigationPath.append(newDate)
            viewModel.homeNavigationDate = nil
        }
    }

    private func dashboardSection(workoutDates: Set<String>) -> some View {
        Button {
            selectedTab = 1
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(monthYearHeaderString)
                        .font(AppFont.title3).fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(AppFont.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                CalendarGridView(workoutDates: workoutDates)
            }
            .padding(16)
            .homeSurface()
        }
        .buttonStyle(AppPressableStyle())
        .accessibilityLabel("\(monthYearHeaderString)のトレーニングカレンダーを履歴で開く")
    }

    private func activitySummary(summary: HomeWorkoutSummary) -> some View {
        HStack(spacing: 0) {
            HomeMetric(value: "\(summary.thisWeekWorkoutCount)回", label: "今週")
            Divider().frame(height: 34)
            HomeMetric(value: previousWorkoutValue(for: summary.previousWorkout), label: "前回")

            Divider().frame(height: 34)
            HomeMetric(
                value: summary.personalBestUpdates.isEmpty
                    ? "更新なし"
                    : "\(summary.personalBestUpdates.count)種目",
                label: "ベスト更新"
            )
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func bestUpdatesSection(summary: HomeWorkoutSummary) -> some View {
        if !summary.personalBestUpdates.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("ベスト更新")
                    .font(AppFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text("自己ベスト：完了セットの最大推定1RM（1回分の推定重量・自重種目は最大回数）")
                    .font(AppFont.caption2)
                    .foregroundStyle(.tertiary)

                VStack(spacing: 0) {
                    ForEach(Array(summary.personalBestUpdates.enumerated()), id: \.element.id) { index, update in
                        if index > 0 {
                            Divider().padding(.leading, 42)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(.systemBackground))
                                .frame(width: 30, height: 30)
                                .background(AppDesign.accent)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text(update.exerciseName)
                                    .font(AppFont.subheadline)
                                    .fontWeight(.semibold)
                                Text(bestUpdateDescription(update))
                                    .font(AppFont.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }

                            Spacer()
                        }
                        .padding(.vertical, 11)
                    }
                }
                .padding(.horizontal, 14)
                .homeSurface()
            }
        }
    }

    private func todaySection(summary: HomeWorkoutSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日")
                .font(AppFont.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if let todayWorkout = summary.todayWorkout {
                recordedTodayCard(todayWorkout)
            } else {
                emptyTodayCard(previousWorkout: summary.previousWorkout)
            }
        }
    }

    private func recordedTodayCard(_ workout: Workout) -> some View {
        Button {
            openToday()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: workout.isActive ? "circle.dotted" : "checkmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(workout.isActive ? Color.primary : Color(.systemBackground))
                    .frame(width: 40, height: 40)
                    .background(workout.isActive ? AppDesign.subtleFill : AppDesign.accent)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.isActive ? "トレーニングを入力中" : "今日のトレーニング")
                        .font(AppFont.headline)
                        .fontWeight(.semibold)
                    Text("\(workout.workoutExercises.count)種目・\(workout.totalSets)セット")
                        .font(AppFont.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(workout.isActive ? "続ける" : "記録済み")
                    .font(AppFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .padding(16)
            .homeSurface()
            .contentShape(Rectangle())
        }
        .buttonStyle(AppPressableStyle())
        .accessibilityLabel("今日のトレーニング、\(workout.workoutExercises.count)種目、\(workout.totalSets)セット")
    }

    private func emptyTodayCard(previousWorkout: Workout?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("今日はまだ記録がありません")
                    .font(AppFont.headline)
                    .fontWeight(.semibold)

                if let previousWorkout {
                    Text("前回は\(previousWorkout.date.monthDayString)・\(previousWorkout.workoutExercises.count)種目")
                        .font(AppFont.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("最初の記録が、次回の基準になります")
                        .font(AppFont.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Button { openToday() } label: {
                Label("本日のトレーニングを開始", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppPrimaryButtonStyle())
        }
        .padding(18)
        .homeSurface()
    }

    private func openToday() {
        navigationPath.append(calendar.startOfDay(for: Date()))
    }

    private func bestUpdateDescription(_ update: PersonalBestUpdate) -> String {
        switch update.metric {
        case .estimatedOneRM:
            let previous = weightUnit.fromKg(update.previousValue)
            let current = weightUnit.fromKg(update.currentValue)
            return String(format: "推定1RM %.1f → %.1f %@", previous, current, weightUnit.rawValue)
        case .bodyweightReps:
            return "最大回数 \(Int(update.previousValue)) → \(Int(update.currentValue)) 回"
        }
    }

    private var monthYearHeaderString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: Date())
    }
}

private struct HomeMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(AppFont.headline)
                .fontWeight(.semibold)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(AppFont.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct HomeSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppDesign.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.cornerLarge, style: .continuous)
                    .strokeBorder(AppDesign.materialEdge, lineWidth: 0.7)
            }
    }
}

private extension View {
    func homeSurface() -> some View {
        modifier(HomeSurfaceModifier())
    }
}
