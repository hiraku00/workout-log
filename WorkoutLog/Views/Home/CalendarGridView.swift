import SwiftUI

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
