import SwiftUI
import SwiftData

/// セット記録の行コンポーネント
struct SetRowView: View {
    let exerciseSet: ExerciseSet
    let setNumber: Int
    let onDelete: () -> Void
    let onCompleted: () -> Void

    @AppStorage("weightUnit") private var weightUnit = "kg"
    @State private var showingRepsPicker = false

    private var oneRM: Double {
        exerciseSet.isBodyweight ? 0 : WorkoutViewModel.estimateOneRM(weight: exerciseSet.weight, reps: exerciseSet.reps)
    }

    var body: some View {
        @Bindable var exerciseSet = exerciseSet
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Text("\(setNumber)")
                    .font(AppFont.input)
                    .foregroundStyle(.secondary)
                    .frame(width: SetRowLayout.setNumber)

                Spacer(minLength: SetRowLayout.minimumGap)

                weightInput(exerciseSet: exerciseSet)
                    .frame(width: SetRowLayout.weight)

                Spacer(minLength: SetRowLayout.minimumGap)

                pickerButton(
                    value: "\(exerciseSet.reps)",
                    unit: "回"
                ) {
                    showingRepsPicker = true
                }
                .frame(width: SetRowLayout.reps)

                Spacer(minLength: SetRowLayout.minimumGap)

                Text(oneRM > 0 ? oneRM.weightString(unit: "") : "—")
                    .font(AppFont.input)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .frame(width: SetRowLayout.oneRM)

                Spacer(minLength: SetRowLayout.minimumGap)

                Button {
                    exerciseSet.isCompleted.toggle()
                    if exerciseSet.isCompleted { onCompleted() }
                } label: {
                    Image(systemName: exerciseSet.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 21))
                        .foregroundStyle(exerciseSet.isCompleted ? AppDesign.accent : Color.secondary)
                }
                .frame(width: SetRowLayout.complete, height: 40)
                .accessibilityLabel(exerciseSet.isCompleted ? "セット完了を取り消す" : "セットを完了")

                Spacer(minLength: SetRowLayout.minimumGap)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(AppFont.subheadline)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .frame(width: SetRowLayout.delete, height: 40)
                .accessibilityLabel("セットを削除")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)

            HStack(spacing: 0) {
                TextField("メモ（任意）", text: $exerciseSet.comment)
                    .font(AppFont.body)
                    .padding(.leading, 12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(AppDesign.subtleFill)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous)
                    .stroke(AppDesign.hairline, lineWidth: 0.8)
            )
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(exerciseSet.isCompleted ? AppDesign.accentFill : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous))
        .animation(.spring(response: 0.25, dampingFraction: 1), value: exerciseSet.isCompleted)
        .sensoryFeedback(.success, trigger: exerciseSet.isCompleted)
        .swipeActions(edge: .trailing) {
            Button("削除", role: .destructive, action: onDelete)
        }
        .accessibilityHint("右端のゴミ箱でセットを削除できます")
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
            if exerciseSet.isBodyweight {
                Button {
                    exerciseSet.weight = 0
                } label: {
                    Text("自重")
                        .font(AppFont.input)
                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .trailing)
                }
                .buttonStyle(.plain)
                .accessibilityHint("タップすると重量入力へ戻ります")
            } else {
                WeightTextField(exerciseSet: exerciseSet, weightUnit: weightUnit)

                Text(weightUnit)
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
            }

        }
        .background(AppDesign.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous)
                .stroke(AppDesign.hairline, lineWidth: 0.8)
        )
        .contextMenu {
            if exerciseSet.isBodyweight {
                Button("重量入力へ戻す", systemImage: "number") {
                    exerciseSet.weight = 0
                }
            } else {
                Button("自重として記録", systemImage: "figure.strengthtraining.traditional") {
                    exerciseSet.weight = ExerciseSet.bodyweightValue
                }
            }
        }
        .accessibilityHint("長押しで自重入力に切り替えられます")
    }

    private func pickerButton(
        value: String,
        unit: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 0) {
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
                .frame(maxWidth: .infinity, minHeight: 40)
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
        HStack(spacing: 0) {
            Text("セット")
                .frame(width: SetRowLayout.setNumber)
            Spacer(minLength: SetRowLayout.minimumGap)
            Text("重量")
                .frame(width: SetRowLayout.weight)
            Spacer(minLength: SetRowLayout.minimumGap)
            Text("回数")
                .frame(width: SetRowLayout.reps)
            Spacer(minLength: SetRowLayout.minimumGap)
            Text("1RM")
                .frame(width: SetRowLayout.oneRM)
            Spacer(minLength: SetRowLayout.minimumGap)
            Text("完了").frame(width: SetRowLayout.complete)
            Spacer(minLength: SetRowLayout.minimumGap)
            Color.clear.frame(width: SetRowLayout.delete)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(AppFont.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.vertical, 6)
    }
}

/// Formatter付きの数値Bindingでは入力途中の「.」が消えるため、文字列を保持して小数入力を確実に扱う。
private struct WeightTextField: View {
    let exerciseSet: ExerciseSet
    let weightUnit: String

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("0", text: $text)
            .font(AppFont.input)
            .monospacedDigit()
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .focused($isFocused)
            .frame(maxWidth: .infinity, minHeight: 40)
            .onAppear { refreshText() }
            .onChange(of: text) { _, newValue in
                updateWeight(from: newValue)
            }
            .onChange(of: exerciseSet.weight) { _, _ in
                if !isFocused { refreshText() }
            }
            .onChange(of: weightUnit) { _, _ in
                refreshText()
            }
            .accessibilityLabel("重量")
    }

    private func updateWeight(from input: String) {
        let normalized = input
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "．", with: ".")
        guard normalized.filter({ $0 == "." }).count <= 1,
              let value = Double(normalized),
              value >= 0 else { return }
        exerciseSet.weight = weightUnit == "lbs" ? value / 2.20462 : value
    }

    private func refreshText() {
        guard !exerciseSet.isBodyweight else {
            text = ""
            return
        }
        let value = weightUnit == "lbs" ? exerciseSet.weight * 2.20462 : exerciseSet.weight
        text = formatted(value)
    }

    private func formatted(_ value: Double) -> String {
        let result = String(format: "%.2f", value)
        return result
            .replacingOccurrences(of: #"\.0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(\.[0-9]*?)0+$"#, with: "$1", options: .regularExpression)
    }
}
