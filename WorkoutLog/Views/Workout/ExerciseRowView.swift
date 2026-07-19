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
                VStack(alignment: .leading, spacing: 4) {
                    Text(workoutExercise.exerciseTemplate?.name ?? "種目")
                        .font(AppFont.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

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

                if embedded {
                    // 一覧カード右上の並べ替えボタン分を確保する。
                    Color.clear.frame(width: 74, height: 1)
                } else {
                    Image(systemName: "chevron.right")
                        .font(AppFont.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }
            }

            if !workoutExercise.sortedSets.isEmpty {
                VStack(spacing: 0) {
                    recordColumnHeader

                    ForEach(Array(workoutExercise.sortedSets.enumerated()), id: \.element.id) { index, set in
                        Divider()
                        HStack(spacing: RecordColumn.spacing) {
                            Text("\(index + 1)")
                                .font(AppFont.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: RecordColumn.set, alignment: .leading)
                            Text(set.weight.setWeightDisplay(unit: weightUnit))
                                .font(AppFont.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundStyle(set.isCompleted ? Color.primary : Color.secondary)
                                .frame(width: RecordColumn.weight, alignment: .trailing)
                            Text("\(set.reps)回")
                                .font(AppFont.subheadline)
                                .monospacedDigit()
                                .foregroundStyle(set.isCompleted ? Color.primary : Color.secondary)
                                .frame(width: RecordColumn.reps, alignment: .trailing)

                            let oneRM = set.isBodyweight ? 0 : WorkoutViewModel.estimateOneRM(weight: set.weight, reps: set.reps)
                            Text(oneRM > 0 ? oneRM.weightString() : "—")
                                .font(AppFont.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: RecordColumn.oneRM, alignment: .trailing)

                            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(AppFont.caption)
                                .foregroundStyle(set.isCompleted ? AppDesign.positive : Color.secondary)
                                .frame(width: RecordColumn.status)
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

    private var recordColumnHeader: some View {
        HStack(spacing: RecordColumn.spacing) {
            Text("セット").frame(width: RecordColumn.set, alignment: .leading)
            Text("重量").frame(width: RecordColumn.weight, alignment: .trailing)
            Text("回数").frame(width: RecordColumn.reps, alignment: .trailing)
            Text("1RM").frame(width: RecordColumn.oneRM, alignment: .trailing)
            Text("完了").frame(width: RecordColumn.status)
        }
        .font(AppFont.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.vertical, 6)
    }
}

private enum RecordColumn {
    static let set: CGFloat = 28
    static let weight: CGFloat = 82
    static let reps: CGFloat = 52
    static let oneRM: CGFloat = 62
    static let status: CGFloat = 28
    static let spacing: CGFloat = 5
}
