import SwiftUI
import SwiftData

/// セット記録の行コンポーネント
struct SetRowView: View {
    let exerciseSet: ExerciseSet
    let setNumber: Int
    let previousWorkoutSet: ExerciseSet?
    let onDelete: () -> Void
    let onCopyWeight: (() -> Void)?
    let onCopyReps: (() -> Void)?
    let onCopyNote: (() -> Void)?
    let onCompleted: () -> Void

    @AppStorage("weightUnit") private var weightUnit = "kg"
    @State private var showingRepsPicker = false

    private var oneRM: Double {
        exerciseSet.isBodyweight ? 0 : WorkoutViewModel.estimateOneRM(weight: exerciseSet.weight, reps: exerciseSet.reps)
    }

    var body: some View {
        @Bindable var exerciseSet = exerciseSet
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(setNumber)")
                    .font(AppFont.input)
                    .foregroundStyle(.secondary)
                    .frame(width: 44)

                weightInput(exerciseSet: exerciseSet)
                .frame(maxWidth: .infinity)

                pickerButton(
                    value: "\(exerciseSet.reps)",
                    unit: "回",
                    copyAction: onCopyReps
                ) {
                    showingRepsPicker = true
                }
                .frame(maxWidth: .infinity)

                Text(oneRM > 0 ? oneRM.weightString(unit: "") : "—")
                    .font(AppFont.input)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .frame(width: 58)

                Button {
                    exerciseSet.isCompleted.toggle()
                    if exerciseSet.isCompleted { onCompleted() }
                } label: {
                    Image(systemName: exerciseSet.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 21))
                        .foregroundStyle(exerciseSet.isCompleted ? AppDesign.accent : Color.secondary)
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel(exerciseSet.isCompleted ? "セット完了を取り消す" : "セットを完了")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)

            ZStack(alignment: .trailing) {
                TextField("メモ（任意）", text: $exerciseSet.comment)
                    .font(AppFont.body)
                    .padding(.leading, 12)
                    .padding(.trailing, 52)

                if let onCopyNote {
                    Button(action: onCopyNote) {
                        Image(systemName: "arrow.up.doc.fill")
                            .font(AppFont.subheadline)
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityLabel("前のメモをコピー")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(AppDesign.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous)
                    .stroke(AppDesign.hairline, lineWidth: 0.8)
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(exerciseSet.isCompleted ? AppDesign.accentFill : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous))
        .animation(.spring(response: 0.25, dampingFraction: 1), value: exerciseSet.isCompleted)
        .sensoryFeedback(.success, trigger: exerciseSet.isCompleted)
        .swipeActions(edge: .trailing) {
            Button("削除", role: .destructive, action: onDelete)
        }
        .sheet(isPresented: $showingRepsPicker) {
            wheelPickerSheet(
                title: "レップ数",
                isPresented: $showingRepsPicker,
                selection: Binding(
                    get: { Double(exerciseSet.reps) },
                    set: { exerciseSet.reps = Int($0) }
                ),
                options: Array(stride(from: 1.0, through: 50.0, by: 1.0))
            ) { val in
                "\(Int(val)) 回"
            }
        }
    }

    private func weightInput(exerciseSet: ExerciseSet) -> some View {
        HStack(spacing: 0) {
            if let onCopyWeight {
                Button(action: onCopyWeight) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(AppFont.caption)
                        .foregroundStyle(AppDesign.accent)
                        .frame(width: 32, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("前のセットの重量をコピー")
            }

            if exerciseSet.isBodyweight {
                Button {
                    exerciseSet.weight = 0
                } label: {
                    Text("自重")
                        .font(AppFont.input)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                }
                .buttonStyle(.plain)
                .accessibilityHint("タップすると重量入力へ戻ります")
            } else {
                TextField(
                    "0",
                    value: displayWeightBinding(for: exerciseSet),
                    format: .number.precision(.fractionLength(0...2))
                )
                .font(AppFont.input)
                .monospacedDigit()
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, minHeight: 44)

                Text(weightUnit)
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
            }

            Menu {
                if exerciseSet.isBodyweight {
                    Button("重量入力へ戻す", systemImage: "number") {
                        exerciseSet.weight = 0
                    }
                } else {
                    Button("自重として記録", systemImage: "figure.strengthtraining.traditional") {
                        exerciseSet.weight = ExerciseSet.bodyweightValue
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 44)
            }
            .accessibilityLabel("重量入力のオプション")
        }
        .background(AppDesign.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous)
                .stroke(AppDesign.hairline, lineWidth: 0.8)
        )
    }

    private func displayWeightBinding(for exerciseSet: ExerciseSet) -> Binding<Double> {
        Binding(
            get: {
                weightUnit == "lbs" ? exerciseSet.weight * 2.20462 : exerciseSet.weight
            },
            set: { displayValue in
                let sanitized = max(0, displayValue)
                exerciseSet.weight = weightUnit == "lbs" ? sanitized / 2.20462 : sanitized
            }
        )
    }

    private func pickerButton(
        value: String,
        unit: String,
        copyAction: (() -> Void)?,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 0) {
            if let copyAction {
                Button(action: copyAction) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(AppFont.caption)
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 44)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel("前のセットの値をコピー")
            }

            Button(action: action) {
                HStack(spacing: 6) {
                    Text(value)
                        .font(AppFont.input)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(AppFont.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .background(AppDesign.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous)
                .stroke(AppDesign.hairline, lineWidth: 0.8)
        )
    }

    private func wheelPickerSheet<T: BinaryFloatingPoint>(
        title: String,
        isPresented: Binding<Bool>,
        selection: Binding<T>,
        options: [T],
        label: @escaping (T) -> String
    ) -> some View where T.Stride: BinaryFloatingPoint {
        NavigationStack {
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { val in
                    Text(label(val)).tag(val)
                }
            }
            .pickerStyle(.wheel)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        isPresented.wrappedValue = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(260)])
    }
}

/// セット入力行のカラムヘッダー
struct SetRowColumnHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("セット")
                .frame(width: 44)
            Text("重量")
                .frame(maxWidth: .infinity)
            Text("回数")
                .frame(maxWidth: .infinity)
            Text("1RM")
                .frame(width: 58)
            Text("完了").frame(width: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(AppFont.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
    }
}
