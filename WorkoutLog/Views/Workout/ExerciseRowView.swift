import SwiftUI
import SwiftData

/// ワークアウト一覧の種目行（タップで詳細入力画面へ）
struct ExerciseRowView: View {
    let workoutExercise: WorkoutExercise
    var onDelete: (() -> Void)? = nil
    var embedded = false

    @AppStorage("weightUnit") private var weightUnit = "kg"

    private var completedSummary: String {
        let sets = workoutExercise.sortedSets
        guard !sets.isEmpty else { return "セット未入力" }
        return "\(sets.filter(\.isCompleted).count)/\(sets.count)セット完了"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                        .lineLimit(1)

                    Text(completedSummary)
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

            if !workoutExercise.sortedSets.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(workoutExercise.sortedSets.enumerated()), id: \.element.id) { index, set in
                        if index > 0 { Divider() }
                        HStack(spacing: 8) {
                            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(AppFont.caption)
                                .foregroundStyle(set.isCompleted ? AppDesign.positive : Color.secondary)
                            Text("\(index + 1)")
                                .font(AppFont.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 16, alignment: .leading)
                            Text(set.weight.setWeightDisplay(unit: weightUnit))
                                .font(AppFont.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                            Text("× \(set.reps)回")
                                .font(AppFont.subheadline)
                                .monospacedDigit()
                            Spacer()

                            let oneRM = set.isBodyweight ? 0 : WorkoutViewModel.estimateOneRM(weight: set.weight, reps: set.reps)
                            if oneRM > 0 {
                                Text("1RM \(oneRM.weightString())")
                                    .font(AppFont.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .padding(.vertical, 7)
                    }
                }
                .padding(.horizontal, 10)
                .background(AppDesign.subtleFill)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(embedded ? Color.clear : AppDesign.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: embedded ? 0 : AppDesign.cornerLarge, style: .continuous))
        .overlay {
            if !embedded {
                RoundedRectangle(cornerRadius: AppDesign.cornerLarge, style: .continuous)
                    .stroke(AppDesign.hairline, lineWidth: 0.5)
            }
        }
    }
}
