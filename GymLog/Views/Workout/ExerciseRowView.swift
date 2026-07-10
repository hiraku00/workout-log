import SwiftUI
import SwiftData

/// ワークアウト一覧の種目行（タップで詳細入力画面へ）
struct ExerciseRowView: View {
    let workoutExercise: WorkoutExercise
    var onDelete: (() -> Void)? = nil

    @AppStorage("weightUnit") private var weightUnit = "kg"

    private var setSummary: String {
        let sets = workoutExercise.sortedSets
        guard !sets.isEmpty else { return "セット未入力" }
        let count = sets.count
        if let last = sets.last {
            return "\(count) sets · \(last.weight.setWeightDisplay(unit: weightUnit)) × \(last.reps)"
        }
        return "\(count) sets"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppDesign.subtleFill)
                    .frame(width: 38, height: 38)
                Image(systemName: "dumbbell")
                    .font(AppFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(workoutExercise.exerciseTemplate?.name ?? "種目")
                    .font(AppFont.headline).fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(setSummary)
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if onDelete != nil {
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Image(systemName: "trash")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Image(systemName: "chevron.right")
                .font(AppFont.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppDesign.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerLarge, style: .continuous)
                .stroke(AppDesign.hairline, lineWidth: 0.5)
        )
    }
}
