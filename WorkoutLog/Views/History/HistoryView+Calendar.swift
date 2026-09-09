import SwiftUI

// MARK: - 月間カレンダータブ
extension HistoryView {
    // MARK: - 3. 月間カレンダーカード (TabViewでスワイプアニメーション対応)
    var calendarCardView: some View {
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
    func monthRange() -> [Date] {
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
    func calendarGrid(for month: Date) -> some View {
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

    // MARK: - ヘルパー関数
    func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: normalizedMonth(selectedMonth)) {
            selectedMonth = normalizedMonth(newMonth)
        }
    }

    func normalizedMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    func monthYearHeaderString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    func yyyyMMddString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    func daysInMonth(for date: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return []
        }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: startOfMonth) }
    }

    func firstWeekdayOffset(for date: Date) -> Int {
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return 0
        }
        // Calendar.component(.weekday) は日曜=1。月曜始まりへ変換する。
        return (calendar.component(.weekday, from: startOfMonth) + 5) % 7
    }
}
