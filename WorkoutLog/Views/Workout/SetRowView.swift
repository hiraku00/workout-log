import SwiftUI
import SwiftData

/// セット記録の行コンポーネント
struct SetRowView: View {
    let exerciseSet: ExerciseSet
    let setNumber: Int
    let onDelete: () -> Void
    let onCopyWeight: (() -> Void)?
    let onCopyReps: (() -> Void)?
    let onCopyNote: (() -> Void)?
    let onCompleted: () -> Void

    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @AppStorage("oneRMFormula") private var oneRMFormula = OneRMFormula.epley.rawValue
    @State private var showingRepsPicker = false

    private var oneRM: Double {
        exerciseSet.isBodyweight
            ? 0
            : WorkoutViewModel.estimateOneRM(
                weight: exerciseSet.weight,
                reps: exerciseSet.reps,
                formula: OneRMFormula(rawValue: oneRMFormula) ?? .epley
            )
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

                weightInput(exerciseSet: exerciseSet, copyAction: onCopyWeight)
                    .frame(width: SetRowLayout.inputWeight)

                Spacer(minLength: SetRowLayout.minimumGap)

                pickerButton(
                    value: "\(exerciseSet.reps)",
                    unit: "回",
                    copyAction: onCopyReps
                ) {
                    showingRepsPicker = true
                }
                .frame(width: SetRowLayout.inputReps)

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
                        .frame(width: SetRowLayout.delete, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("セットを削除")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)

            GeometryReader { proxy in
                let leading = SetRowLayout.setNumber + SetRowLayout.inputGap(for: proxy.size.width)
                let noteCopyWidth = onCopyNote == nil ? 0 : SetRowLayout.delete

                HStack(spacing: 0) {
                    Color.clear.frame(width: max(0, leading))

                    TextField("メモ（任意）", text: $exerciseSet.comment)
                        .font(AppFont.body)
                        .padding(.horizontal, 12)
                        .frame(width: max(0, proxy.size.width - leading - noteCopyWidth), height: 36)
                        .background(AppDesign.subtleFill)
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous)
                                .stroke(AppDesign.hairline, lineWidth: 0.8)
                        )

                    if let onCopyNote {
                        Button(action: onCopyNote) {
                            Image(systemName: "arrow.up.doc.fill")
                                .font(AppFont.caption)
                                .foregroundStyle(AppDesign.accent)
                                .frame(width: noteCopyWidth, height: 36)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("上のセットのメモをコピー")
                    }

                }
            }
            .frame(height: 36)
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
        .accessibilityHint("完了の右にあるゴミ箱でセットを削除できます")
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

    private func weightInput(exerciseSet: ExerciseSet, copyAction: (() -> Void)?) -> some View {
        HStack(spacing: 0) {
            if let copyAction {
                Button(action: copyAction) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(AppFont.caption)
                        .foregroundStyle(AppDesign.accent)
                        .frame(width: 20, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("上のセットの重量をコピー")
            }

            if exerciseSet.isBodyweight {
                Text("自重")
                    .font(AppFont.input)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
            } else {
                HStack(spacing: 4) {
                    WeightTextField(exerciseSet: exerciseSet, weightUnit: weightUnit)
                        .layoutPriority(1)

                    Text(weightUnit.rawValue)
                        .font(AppFont.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
                .padding(.trailing, 4)
            }

            Button {
                exerciseSet.weight = exerciseSet.isBodyweight ? 0 : ExerciseSet.bodyweightValue
            } label: {
                Text(exerciseSet.isBodyweight ? "解除" : "自重")
                    .font(AppFont.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(exerciseSet.isBodyweight ? Color.white : AppDesign.accent)
                    .frame(width: 34, height: 28)
                    .background(exerciseSet.isBodyweight ? AppDesign.accent : Color.clear)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(exerciseSet.isBodyweight ? "自重を解除" : "自重として記録")
        }
        .background(AppDesign.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous)
                .stroke(AppDesign.hairline, lineWidth: 0.8)
        )
        .accessibilityHint(exerciseSet.isBodyweight ? "自重が選択されています。右端の自重ボタンで解除できます" : "数値を直接入力できます。右端の自重ボタンで切り替えられます")
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
                        .foregroundStyle(AppDesign.accent)
                        .frame(width: 20, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("上のセットの回数をコピー")
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
                .frame(width: SetRowLayout.inputWeight)
            Spacer(minLength: SetRowLayout.minimumGap)
            Text("回数")
                .frame(width: SetRowLayout.inputReps)
            Spacer(minLength: SetRowLayout.minimumGap)
            Text("1RM")
                .frame(width: SetRowLayout.oneRM)
            Spacer(minLength: SetRowLayout.minimumGap)
            Text("完了").frame(width: SetRowLayout.complete)
            Spacer(minLength: SetRowLayout.minimumGap)
            Text("削除").frame(width: SetRowLayout.delete)
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

/// 文字列を保持して小数点入力を確実に扱う重量フィールド。
private struct WeightTextField: View {
    let exerciseSet: ExerciseSet
    let weightUnit: WeightUnit

    @State private var text = ""
    @State private var lastSyncedWeight: Double?
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("0", text: $text)
            .font(AppFont.input)
            .monospacedDigit()
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .focused($isFocused)
            .frame(maxWidth: .infinity, minHeight: 40)
            .onAppear {
                refreshText()
                lastSyncedWeight = exerciseSet.weight
            }
            .onChange(of: text) { _, newValue in updateWeight(from: newValue) }
            .onChange(of: exerciseSet.weight) { _, newValue in
                // 入力中の変更はupdateWeightで同期済み。それ以外の変更（コピー等）は
                // フォーカス中でも表示文字列へ反映する。
                if lastSyncedWeight != newValue {
                    refreshText()
                    lastSyncedWeight = newValue
                }
            }
            .onChange(of: weightUnit) { _, _ in refreshText() }
            .accessibilityLabel("重量を直接入力")
    }

    private func updateWeight(from input: String) {
        let normalized = input
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "．", with: ".")
        if normalized.isEmpty {
            exerciseSet.weight = 0
            lastSyncedWeight = exerciseSet.weight
            return
        }
        guard normalized.filter({ $0 == "." }).count <= 1,
              let value = Double(normalized),
              value >= 0 else { return }
        exerciseSet.weight = weightUnit.toKg(value)
        lastSyncedWeight = exerciseSet.weight
    }

    private func refreshText() {
        guard !exerciseSet.isBodyweight else { text = ""; return }
        let value = weightUnit.fromKg(exerciseSet.weight)
        text = Self.formatted(value)
    }

    private static func formatted(_ value: Double) -> String {
        guard value != 0 else { return "" }
        let result = String(format: "%.2f", value)
        return result
            .replacingOccurrences(of: #"\.0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(\.[0-9]*?)0+$"#, with: "$1", options: .regularExpression)
    }
}
