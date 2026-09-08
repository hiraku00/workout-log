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

    private var summary: HomeWorkoutSummary {
        WorkoutInsights.homeSummary(
            workouts: allWorkouts,
            calendar: calendar,
            oneRMFormula: OneRMFormula(rawValue: oneRMFormula) ?? .epley
        )
    }

    private var workoutDates: Set<String> {
        summary.workoutDates
    }

    private var previousWorkoutValue: String {
        guard let previousWorkout = summary.previousWorkout else { return "なし" }
        let previousDay = calendar.startOfDay(for: previousWorkout.date)
        let today = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: previousDay, to: today).day ?? 0
        return days == 1 ? "昨日" : "\(days)日前"
    }

    var body: some View {
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
                    dashboardSection
                    activitySummary
                    bestUpdatesSection
                    todaySection
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

    private var dashboardSection: some View {
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

    private var activitySummary: some View {
        HStack(spacing: 0) {
            HomeMetric(value: "\(summary.thisWeekWorkoutCount)回", label: "今週")
            Divider().frame(height: 34)
            HomeMetric(value: previousWorkoutValue, label: "前回")

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
    private var bestUpdatesSection: some View {
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

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日")
                .font(AppFont.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if let todayWorkout = summary.todayWorkout {
                recordedTodayCard(todayWorkout)
            } else {
                emptyTodayCard
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

    private var emptyTodayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("今日はまだ記録がありません")
                    .font(AppFont.headline)
                    .fontWeight(.semibold)

                if let previousWorkout = summary.previousWorkout {
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

// MARK: - 負荷表示カード
struct LoadCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppFont.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(AppFont.headline).fontWeight(.semibold)
                .monospacedDigit()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppDesign.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous)
                .stroke(AppDesign.hairline, lineWidth: 0.5)
        )
    }
}

// MARK: - 月間カレンダーグリッド（ホーム用ミニ表示）
struct CalendarGridView: View {
    let workoutDates: Set<String>

    private let calendar = Calendar.current
    private let weekdays = ["月", "火", "水", "木", "金", "土", "日"]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(AppFont.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            let days = daysInCurrentMonth()
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<firstWeekdayOffset(), id: \.self) { _ in
                    Text("").frame(width: 24, height: 24)
                }

                ForEach(days, id: \.self) { date in
                    let isToday = calendar.isDateInToday(date)
                    let hasWorkout = hasWorkout(on: date)
                    let dayString = String(calendar.component(.day, from: date))

                    Text(dayString)
                        .font(AppFont.caption)
                        .fontWeight(isToday ? .bold : .medium)
                        .foregroundStyle(isToday ? Color(.systemBackground) : (hasWorkout ? .primary : .primary))
                        .frame(width: 24, height: 24)
                        .background(
                            isToday ? AppDesign.accent : (hasWorkout ? AppDesign.subtleFill : Color.clear)
                        )
                        .clipShape(Circle())
                }
            }
        }
    }

    private func daysInCurrentMonth() -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: Date()),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) else {
            return []
        }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: startOfMonth) }
    }

    private func firstWeekdayOffset() -> Int {
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) else {
            return 0
        }
        return (calendar.component(.weekday, from: startOfMonth) + 5) % 7
    }

    private func hasWorkout(on date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return workoutDates.contains(formatter.string(from: date))
    }
}

// MARK: - 1RM計算機
struct RMCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @AppStorage("oneRMFormula") private var oneRMFormula = OneRMFormula.epley.rawValue
    @State private var weight: Double = 60
    @State private var reps: Int = 10

    private var weightOptions: [Double] {
        Array(stride(from: 0.0, through: 250.0, by: 1.0))
    }

    private var oneRM: Double {
        WorkoutViewModel.estimateOneRM(weight: weight, reps: reps, formula: OneRMFormula(rawValue: oneRMFormula) ?? .epley)
    }

    private var displayOneRM: Double {
        weightUnit.fromKg(oneRM)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("推定1RM")
                        .font(AppFont.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(displayOneRM.weightString(unit: weightUnit.rawValue))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .appCard(cornerRadius: AppDesign.cornerLarge, padding: 18)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("重量")
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                        Picker("重量", selection: $weight) {
                            ForEach(weightOptions, id: \.self) { val in
                                let display = weightUnit.fromKg(val)
                                Text(display.weightString(unit: weightUnit.rawValue)).tag(val)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("レップ数")
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                        Picker("レップ数", selection: $reps) {
                            ForEach(1...50, id: \.self) { val in
                                Text("\(val) 回").tag(val)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("1RM計算機")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
