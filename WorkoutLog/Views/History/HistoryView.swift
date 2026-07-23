import SwiftUI
import SwiftData
import Charts

/// 履歴画面：月間カレンダーと負荷部位フィルターダッシュボード (モノトーンAppleスタイル)
struct HistoryView: View {
    @Query(sort: \Workout.date, order: .forward) private var allWorkouts: [Workout]

    @Environment(WorkoutViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var mainTabSelection: Int

    @State private var selectedCategory: String = "すべて"
    @State private var selectedTab: String = "カレンダー"
    // 月初に正規化した値だけを選択状態にする。時刻を含む Date() を使うと
    // TabView の月初タグと一致せず、過去月が開くことがある。
    @State private var selectedMonth: Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: Date())
    ) ?? Date()

    private let categories = ["すべて", "胸", "背中", "脚", "肩", "腕", "体幹"]
    private let calendar = Calendar.current

    /// 完了済みワークアウトのみ (日付順)
    private var completedWorkouts: [Workout] {
        allWorkouts.filter { !$0.isActive }
    }

    /// 選択されたカテゴリに該当するワークアウトのみフィルタ
    private var filteredWorkouts: [Workout] {
        if selectedCategory == "すべて" {
            return completedWorkouts
        }
        return completedWorkouts.filter { workout in
            workout.workoutExercises.contains { exercise in
                exercise.exerciseTemplate?.category == selectedCategory
            }
        }
    }

    /// フィルタされた日付のセット (yyyyMMdd形式)
    private var workoutDateMap: [String: Workout] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        var map: [String: Workout] = [:]
        for workout in filteredWorkouts {
            let key = formatter.string(from: workout.date)
            map[key] = workout
        }
        return map
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. 上部部位フィルター
                categoryFilterBar

                // 2. カレンダー・グラフ切り替えタブ
                segmentControl

                ScrollView {
                    VStack(spacing: 24) {
                        if selectedTab == "カレンダー" {
                            // 3. 月間カレンダー
                            calendarCardView
                        } else {
                            // 4. グラフ表示 (Total weight & Max RM)
                            chartsSectionView
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(AppScreenBackground())
            .navigationTitle("履歴")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                selectedMonth = normalizedMonth(selectedMonth)
            }
        }
    }

    // MARK: - 1. 部位フィルター (赤を廃止し、黒・グレーに変更)
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { cat in
                    Button {
                        withAnimation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.28, dampingFraction: 1)) {
                            selectedCategory = cat
                        }
                    } label: {
                        Text(cat)
                            .font(AppFont.caption).fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedCategory == cat ? AppDesign.accent : AppDesign.elevatedSurface)
                            .foregroundStyle(selectedCategory == cat ? Color(.systemBackground) : Color.primary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppDesign.hairline, lineWidth: 0.5))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(AppDesign.appBackground)
        .sensoryFeedback(.selection, trigger: selectedCategory)
    }

    // MARK: - 2. セグメントコントロール
    private var segmentControl: some View {
        HStack(spacing: 0) {
            segmentButton(title: "カレンダー")
            segmentButton(title: "グラフ")
        }
        .padding(4)
        .background(AppDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous)
                .stroke(AppDesign.hairline, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func segmentButton(title: String) -> some View {
        Button {
            withAnimation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.28, dampingFraction: 1)) {
                selectedTab = title
            }
        } label: {
            Text(title)
                .font(AppFont.subheadline).fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedTab == title ? AppDesign.subtleFill : Color.clear)
                .foregroundStyle(selectedTab == title ? Color.primary : Color.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: selectedTab == title ? .black.opacity(0.04) : .clear, radius: 2, x: 0, y: 1)
        }
    }

    // MARK: - 3. 月間カレンダーカード (TabViewでスワイプアニメーション対応)
    private var calendarCardView: some View {
        VStack(spacing: 16) {
            // 月ヘッダー
            HStack {
                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("前の月")

                Text(monthYearHeaderString(for: selectedMonth))
                    .font(AppFont.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)

                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("次の月")
            }

            // 曜日ラベル
            HStack(spacing: 0) {
                let weekdays = ["月", "火", "水", "木", "金", "土", "日"]
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(AppFont.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // TabViewでスワイプ対応
            TabView(selection: $selectedMonth) {
                ForEach(monthRange(), id: \.self) { month in
                    calendarGrid(for: month)
                        .tag(month)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .frame(height: 280)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? .linear(duration: 0.15) : .spring(response: 0.4, dampingFraction: 1), value: selectedMonth)
        }
        .appCard(cornerRadius: AppDesign.cornerLarge, padding: 16)
    }

    // 月範囲を生成（前後12ヶ月分）
    private func monthRange() -> [Date] {
        let today = normalizedMonth(Date())
        var months: [Date] = []
        for i in -12...12 {
            if let month = calendar.date(byAdding: .month, value: i, to: today) {
                let components = calendar.dateComponents([.year, .month], from: month)
                if let normalized = calendar.date(from: components) {
                    months.append(normalized)
                }
            }
        }
        return months
    }

    // カレンダーグリッド（単一の月用）
    private func calendarGrid(for month: Date) -> some View {
        let days = daysInMonth(for: month)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<firstWeekdayOffset(for: month), id: \.self) { _ in
                Text("").frame(height: 36)
            }

            ForEach(days, id: \.self) { date in
                let isToday = calendar.isDateInToday(date)
                let key = yyyyMMddString(for: date)
                let hasWorkout = workoutDateMap[key] != nil
                let isCurrentMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
                let dayString = String(calendar.component(.day, from: date))

                Button {
                    if let normalized = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: date)) {
                        viewModel.openDayOnHome(normalized)
                        mainTabSelection = 0
                    }
                } label: {
                    Text(dayString)
                        .font(AppFont.subheadline)
                        .fontWeight(isToday || hasWorkout ? .bold : .medium)
                        .foregroundStyle(
                            isToday
                                ? Color(.systemBackground)
                                : (hasWorkout ? .white : (isCurrentMonth ? .primary : .secondary.opacity(0.3)))
                        )
                        .frame(width: 32, height: 32)
                        .background(
                            Group {
                                if isToday {
                                    AppDesign.accent
                                } else if hasWorkout {
                                    Color.secondary
                                } else {
                                    Color.clear
                                }
                            }
                        )
                        .clipShape(Circle())
                        .overlay(
                            // 今日かつ記録なし：枠線のみ
                            isToday && !hasWorkout
                                ? Circle().stroke(AppDesign.accent, lineWidth: 1.5)
                                : nil
                        )
                        .accessibilityLabel("\(monthYearHeaderString(for: month)) \(dayString)日")
                        .accessibilityValue(isToday ? "今日" : (hasWorkout ? "記録あり" : "記録なし"))
                }
            }
        }
    }

    // MARK: - 4. グラフ表示セクション (Total Weight & Max RM)
    private var chartsSectionView: some View {
        VStack(spacing: 28) {
            // Total Weight Graph
            VStack(alignment: .leading, spacing: 12) {
                Text("総ボリューム")
                    .font(AppFont.headline)
                    .fontWeight(.semibold)

                if filteredWorkouts.isEmpty {
                    emptyChartPlaceholder
                } else {
                    Chart {
                        ForEach(filteredWorkouts) { workout in
                            LineMark(
                                x: .value("日付", shortDateString(for: workout.date)),
                                y: .value("重量", workout.totalVolume)
                            )
                            .foregroundStyle(AppDesign.accent)

                            PointMark(
                                x: .value("日付", shortDateString(for: workout.date)),
                                y: .value("重量", workout.totalVolume)
                            )
                            .foregroundStyle(AppDesign.accent)
                            .symbolSize(40)
                            .annotation(position: .top) {
                                Text(String(format: "%.0f", workout.totalVolume))
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel()
                        }
                    }
                }
            }
            .appCard(cornerRadius: AppDesign.cornerLarge, padding: 16)

            // Max RM Graph
            VStack(alignment: .leading, spacing: 12) {
                Text("最大推定1RM")
                    .font(AppFont.headline)
                    .fontWeight(.semibold)

                if filteredWorkouts.isEmpty {
                    emptyChartPlaceholder
                } else {
                    Chart {
                        ForEach(filteredWorkouts) { workout in
                            let maxRM = maxEstimatedOneRM(for: workout)

                            LineMark(
                                x: .value("日付", shortDateString(for: workout.date)),
                                y: .value("RM", maxRM)
                            )
                            .foregroundStyle(AppDesign.accent)

                            PointMark(
                                x: .value("日付", shortDateString(for: workout.date)),
                                y: .value("RM", maxRM)
                            )
                            .foregroundStyle(AppDesign.accent)
                            .symbolSize(40)
                            .annotation(position: .top) {
                                Text(String(format: "%.0f", maxRM))
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel()
                        }
                    }
                }
            }
            .appCard(cornerRadius: AppDesign.cornerLarge, padding: 16)
        }
    }

    private func maxEstimatedOneRM(for workout: Workout) -> Double {
        workout.completedSets
            .filter { !$0.isBodyweight && $0.weight > 0 && $0.reps > 0 }
            .map { $0.weight * (1.0 + Double($0.reps) / 30.0) }
            .max() ?? 0
    }

    private var emptyChartPlaceholder: some View {
        Text("記録データがありません")
            .font(AppFont.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 150)
    }

    // MARK: - ヘルパー関数
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: normalizedMonth(selectedMonth)) {
            selectedMonth = normalizedMonth(newMonth)
        }
    }

    private func normalizedMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func monthYearHeaderString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    private func yyyyMMddString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private func shortDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }

    private func daysInMonth(for date: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return []
        }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: startOfMonth) }
    }

    private func firstWeekdayOffset(for date: Date) -> Int {
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return 0
        }
        // Calendar.component(.weekday) は日曜=1。月曜始まりへ変換する。
        return (calendar.component(.weekday, from: startOfMonth) + 5) % 7
    }
}

// MARK: - Calendar拡張
extension Calendar {
    func isDateInThisWeek(_ date: Date) -> Bool {
        isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
}
