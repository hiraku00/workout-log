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
    @State private var showingWeightEditor = false

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

            GeometryReader { proxy in
                let leading = SetRowLayout.setNumber + SetRowLayout.gap(for: proxy.size.width)

                TextField("メモ（任意）", text: $exerciseSet.comment)
                    .font(AppFont.body)
                    .padding(.horizontal, 12)
                    .frame(width: max(0, proxy.size.width - leading), height: 36)
                    .background(AppDesign.subtleFill)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous)
                            .stroke(AppDesign.hairline, lineWidth: 0.8)
                    )
                    .offset(x: leading)
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
        .sheet(isPresented: $showingWeightEditor) {
            WeightEditorSheet(
                exerciseSet: exerciseSet,
                weightUnit: weightUnit,
                isPresented: $showingWeightEditor
            )
        }
    }

    private func weightInput(exerciseSet: ExerciseSet) -> some View {
        Button {
            showingWeightEditor = true
        } label: {
            if exerciseSet.isBodyweight {
                Text("自重")
                    .font(AppFont.input)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
            } else {
                HStack(spacing: 2) {
                    Text(displayWeight.weightString())
                        .font(AppFont.input)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(weightUnit)
                        .font(AppFont.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .trailing)
                .padding(.horizontal, 5)
            }
        }
        .buttonStyle(.plain)
        .background(AppDesign.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerSmall, style: .continuous)
                .stroke(AppDesign.hairline, lineWidth: 0.8)
        )
        .accessibilityHint("タップして重量入力、自重、スライダーを設定できます")
    }

    private var displayWeight: Double {
        weightUnit == "lbs" ? exerciseSet.weight * 2.20462 : exerciseSet.weight
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

/// 重量を直接入力・スライダー・自重から選べる編集シート。
private struct WeightEditorSheet: View {
    let exerciseSet: ExerciseSet
    let weightUnit: String

    @Binding var isPresented: Bool
    @State private var isBodyweight: Bool
    @State private var text: String
    @State private var displayWeight: Double
    @State private var lastNumericWeight: Double
    @FocusState private var isInputFocused: Bool

    init(exerciseSet: ExerciseSet, weightUnit: String, isPresented: Binding<Bool>) {
        self.exerciseSet = exerciseSet
        self.weightUnit = weightUnit
        _isPresented = isPresented

        let value = exerciseSet.isBodyweight ? 0 : Self.displayValue(for: exerciseSet.weight, unit: weightUnit)
        _isBodyweight = State(initialValue: exerciseSet.isBodyweight)
        _displayWeight = State(initialValue: value)
        _lastNumericWeight = State(initialValue: value)
        _text = State(initialValue: Self.formatted(value))
    }

    private var sliderMaximum: Double {
        max(100, ceil(max(displayWeight, lastNumericWeight) / 25) * 25 + 25)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppDesign.spaceL) {
                Picker("種類", selection: $isBodyweight) {
                    Text("重量を入力").tag(false)
                    Text("自重").tag(true)
                }
                .pickerStyle(.segmented)

                if isBodyweight {
                    Label("自重として記録します", systemImage: "figure.strengthtraining.traditional")
                        .font(AppFont.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 132)
                } else {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        TextField("0", text: $text)
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($isInputFocused)
                            .onChange(of: text) { _, newValue in
                                updateWeight(from: newValue)
                            }
                            .accessibilityLabel("重量を直接入力")
                        Text(weightUnit)
                            .font(AppFont.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, AppDesign.spaceM)
                    .padding(.vertical, AppDesign.spaceS)
                    .background(AppDesign.subtleFill)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous))

                    VStack(spacing: AppDesign.spaceS) {
                        Slider(
                            value: $displayWeight,
                            in: 0...sliderMaximum,
                            step: 0.5,
                            onEditingChanged: { editing in
                                if !editing { syncTextAndModel() }
                            }
                        )
                        .accessibilityLabel("重量をスライダーで調整")
                        .onChange(of: displayWeight) { _, value in
                            lastNumericWeight = value
                            exerciseSet.weight = Self.storageValue(for: value, unit: weightUnit)
                        }

                        HStack {
                            Text("0")
                            Spacer()
                            Text("\(Int(sliderMaximum)) \(weightUnit)")
                        }
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(AppDesign.spaceL)
            .navigationTitle("重量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { isPresented = false }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if !isBodyweight { isInputFocused = true }
            }
            .onChange(of: isBodyweight) { _, bodyweight in
                if bodyweight {
                    lastNumericWeight = displayWeight
                    exerciseSet.weight = ExerciseSet.bodyweightValue
                    isInputFocused = false
                } else {
                    displayWeight = lastNumericWeight
                    syncTextAndModel()
                    isInputFocused = true
                }
            }
        }
        .presentationDetents([.height(330)])
    }

    private func updateWeight(from input: String) {
        let normalized = input
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "．", with: ".")
        guard normalized.filter({ $0 == "." }).count <= 1,
              let value = Double(normalized),
              value >= 0 else { return }
        displayWeight = value
        lastNumericWeight = value
        exerciseSet.weight = Self.storageValue(for: value, unit: weightUnit)
    }

    private func syncTextAndModel() {
        text = Self.formatted(displayWeight)
        exerciseSet.weight = Self.storageValue(for: displayWeight, unit: weightUnit)
    }

    private static func displayValue(for weight: Double, unit: String) -> Double {
        unit == "lbs" ? weight * 2.20462 : weight
    }

    private static func storageValue(for value: Double, unit: String) -> Double {
        unit == "lbs" ? value / 2.20462 : value
    }

    private static func formatted(_ value: Double) -> String {
        let result = String(format: "%.2f", value)
        return result
            .replacingOccurrences(of: #"\.0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(\.[0-9]*?)0+$"#, with: "$1", options: .regularExpression)
    }
}
