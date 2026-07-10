import SwiftUI
import SwiftData

/// ホーム画面：統計ダッシュボード
struct HomeView: View {
    @Environment(WorkoutViewModel.self) private var viewModel
    @Query(sort: \Workout.date, order: .reverse) private var allWorkouts: [Workout]
    @Binding var selectedTab: Int
    @State private var navigationPath = NavigationPath()

    private var completedWorkouts: [Workout] {
        allWorkouts.filter { !$0.isActive }
    }

    private var workoutDates: Set<String> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return Set(completedWorkouts.map { formatter.string(from: $0.date) })
    }

    private var load7Days: Double {
        let limit = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return completedWorkouts.filter { $0.date >= limit }.reduce(0.0) { $0 + $1.totalVolume } / 1000.0
    }

    private var load28Days: Double {
        let limit = Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
        return completedWorkouts.filter { $0.date >= limit }.reduce(0.0) { $0 + $1.totalVolume } / 1000.0
    }

    private var totalLoad: Double {
        completedWorkouts.reduce(0.0) { $0 + $1.totalVolume } / 1000.0
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 18) {
                    Text("Workout Log")
                        .font(AppFont.largeTitle)
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                    todayTrainingButton
                    dashboardSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(AppDesign.appBackground)
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

    private var todayTrainingButton: some View {
        Button {
            navigationPath.append(Calendar.current.startOfDay(for: Date()))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.plus")
                    .font(AppFont.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .background(AppDesign.subtleFill)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("今日のトレーニング")
                        .font(AppFont.headline)
                        .fontWeight(.semibold)
                    Text("今日の記録を入力・確認")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(AppFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .appCard(cornerRadius: AppDesign.cornerLarge, padding: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var dashboardSection: some View {
        VStack(spacing: 16) {
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
                .appCard(cornerRadius: AppDesign.cornerLarge, padding: 14)
            }
            .buttonStyle(.plain)

            AppMetricGroup(items: [
                AppMetricItem(value: String(format: "%.2f t", load7Days), label: "7日間"),
                AppMetricItem(value: String(format: "%.2f t", load28Days), label: "28日間"),
                AppMetricItem(value: String(format: "%.2f t", totalLoad), label: "累計")
            ])
        }
    }

    private var monthYearHeaderString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: Date())
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
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
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
        return calendar.component(.weekday, from: startOfMonth) - 1
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
    @AppStorage("weightUnit") private var weightUnit = "kg"
    @State private var weight: Double = 60
    @State private var reps: Int = 10

    private var weightOptions: [Double] {
        Array(stride(from: 0.0, through: 250.0, by: 1.0))
    }

    private var oneRM: Double {
        WorkoutViewModel.estimateOneRM(weight: weight, reps: reps)
    }

    private var displayOneRM: Double {
        weightUnit == "lbs" ? oneRM * 2.20462 : oneRM
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("推定1RM")
                        .font(AppFont.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(displayOneRM.weightString(unit: weightUnit))")
                        .font(.custom(AppFont.fontName, size: 48, relativeTo: .largeTitle))
                        .fontWeight(.semibold)
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
                                let display = weightUnit == "lbs" ? val * 2.20462 : val
                                Text(display.weightString(unit: weightUnit)).tag(val)
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
