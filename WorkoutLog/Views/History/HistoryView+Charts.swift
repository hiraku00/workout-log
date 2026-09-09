import SwiftUI
import Charts

// MARK: - グラフタブ
extension HistoryView {
    // MARK: - 4. グラフ表示セクション (Total Weight & Max RM)
    var chartsSectionView: some View {
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

    func maxEstimatedOneRM(for workout: Workout) -> Double {
        workout.completedSets
            .filter { !$0.isBodyweight && $0.weight > 0 && $0.reps > 0 }
            .map { $0.weight * (1.0 + Double($0.reps) / 30.0) }
            .max() ?? 0
    }

    var emptyChartPlaceholder: some View {
        Text("記録データがありません")
            .font(AppFont.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 150)
    }

    func shortDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}
