import SwiftUI

// MARK: - 1RM計算機
struct RMCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @AppStorage("oneRMFormula") private var oneRMFormula = OneRMFormula.epley.rawValue
    @State private var weight: Double = 60
    @State private var reps: Int = 10

    private var weightOptions: [Double] {
        Array(stride(from: 0.0, through: 250.0, by: 1.0))
    }

    private var oneRM: Double {
        WorkoutViewModel.estimateOneRM(weight: weight, reps: reps, formula: OneRMFormula(rawValue: oneRMFormula) ?? .epley)
    }

    private var displayOneRM: Double {
        weightUnit.fromKg(oneRM)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("推定1RM")
                        .font(AppFont.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(displayOneRM.weightString(unit: weightUnit.rawValue))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .appCard(cornerRadius: AppDesign.cornerLarge, padding: 18)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("重量")
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                        Picker("重量", selection: $weight) {
                            ForEach(weightOptions, id: \.self) { val in
                                let display = weightUnit.fromKg(val)
                                Text(display.weightString(unit: weightUnit.rawValue)).tag(val)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("レップ数")
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                        Picker("レップ数", selection: $reps) {
                            ForEach(1...50, id: \.self) { val in
                                Text("\(val) 回").tag(val)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("1RM計算機")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
