import SwiftUI

/// ワークアウト一覧の各行コンポーネント（HomeView・HistoryViewで共用）
struct WorkoutRowView: View {
    let workout: Workout
    @AppStorage("weightUnit") private var weightUnit = "kg"

    var body: some View {
        HStack(spacing: 16) {
            // 日付インジケーター
            VStack(spacing: 2) {
                Text(monthString)
                    .font(AppFont.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(dayString)
                    .font(AppFont.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
            .frame(width: 44)

            // 区切り線
            Rectangle()
                .fill(AppDesign.accent)
                .frame(width: 2, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 1))

            // ワークアウト情報
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name.isEmpty ? "ワークアウト" : workout.name)
                    .font(AppFont.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    // 種目数
                    if !workout.workoutExercises.isEmpty {
                        Label("\(workout.workoutExercises.count)種目", systemImage: "list.bullet")
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    // セット数
                    if workout.totalSets > 0 {
                        Label("\(workout.totalSets)セット", systemImage: "square.stack.fill")
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // 総ボリューム
            if workout.totalVolume > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedVolume)
                        .font(AppFont.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(weightUnit)
                        .font(AppFont.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(AppFont.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(AppDesign.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerLarge, style: .continuous)
                .stroke(AppDesign.hairline, lineWidth: 0.5)
        )
    }

    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: workout.date)
    }

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: workout.date)
    }

    private var formattedVolume: String {
        let volume: Double
        if weightUnit == "lbs" {
            volume = workout.totalVolume * 2.20462
        } else {
            volume = workout.totalVolume
        }
        return volume >= 1000
            ? String(format: "%.1fk", volume / 1000)
            : String(format: "%.0f", volume)
    }
}
