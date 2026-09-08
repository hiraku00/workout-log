import SwiftUI
import SwiftData

/// ワークアウト一覧の種目行（タップで詳細入力画面へ）
struct ExerciseRowView: View {
    let workoutExercise: WorkoutExercise
    var onDelete: (() -> Void)? = nil
    var onDeleteSet: ((ExerciseSet) -> Void)? = nil
    var embedded = false

    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @AppStorage("oneRMFormula") private var oneRMFormula = OneRMFormula.epley.rawValue

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
                        HStack(spacing: 0) {
                            Text("\(index + 1)")
                                .font(AppFont.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: WorkoutRecordColumn.set, alignment: .leading)
                            Spacer(minLength: SetRowLayout.minimumGap)
                            Text(set.weight.setWeightDisplay(unit: weightUnit))
                                .font(AppFont.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundStyle(set.isCompleted ? Color.primary : Color.secondary)
                                .frame(width: WorkoutRecordColumn.weight, alignment: .trailing)
                            Spacer(minLength: SetRowLayout.minimumGap)
                            Text("\(set.reps)回")
                                .font(AppFont.subheadline)
                                .monospacedDigit()
                                .foregroundStyle(set.isCompleted ? Color.primary : Color.secondary)
                                .frame(width: WorkoutRecordColumn.reps, alignment: .trailing)
                            Spacer(minLength: SetRowLayout.minimumGap)

                            let oneRM = set.isBodyweight
                                ? 0
                                : WorkoutViewModel.estimateOneRM(
                                    weight: set.weight,
                                    reps: set.reps,
                                    formula: OneRMFormula(rawValue: oneRMFormula) ?? .epley
                                )
                            Text(oneRM > 0 ? oneRM.weightString() : "—")
                                .font(AppFont.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: WorkoutRecordColumn.oneRM, alignment: .trailing)
                            Spacer(minLength: SetRowLayout.minimumGap)

                            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(AppFont.caption)
                                .foregroundStyle(set.isCompleted ? AppDesign.positive : Color.secondary)
                                .frame(width: WorkoutRecordColumn.complete)
                            Spacer(minLength: SetRowLayout.minimumGap)

                            if let onDeleteSet {
                                Button(role: .destructive) {
                                    onDeleteSet(set)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(AppFont.caption)
                                        .foregroundStyle(.red)
                                        .frame(width: WorkoutRecordColumn.delete, height: 32)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("セット\(index + 1)を削除")
                            } else {
                                Color.clear.frame(width: WorkoutRecordColumn.delete, height: 32)
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

    private var recordColumnHeader: some View {
        HStack(spacing: 0) {
            Text("セット").frame(width: WorkoutRecordColumn.set, alignment: .leading)
            Spacer(minLength: SetRowLayout.minimumGap)
            Text("重量").frame(width: WorkoutRecordColumn.weight, alignment: .trailing)
            Spacer(minLength: SetRowLayout.minimumGap)
            Text("回数").frame(width: WorkoutRecordColumn.reps, alignment: .trailing)
            Spacer(minLength: SetRowLayout.minimumGap)
            Text("1RM").frame(width: WorkoutRecordColumn.oneRM, alignment: .trailing)
            Spacer(minLength: SetRowLayout.minimumGap)
            Text("完了").frame(width: WorkoutRecordColumn.complete)
            Spacer(minLength: SetRowLayout.minimumGap)
            Color.clear.frame(width: WorkoutRecordColumn.delete)
        }
        .font(AppFont.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.vertical, 6)
    }
}
