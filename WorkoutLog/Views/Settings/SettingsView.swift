import SwiftUI
import SwiftData

/// 設定画面
struct SettingsView: View {
    @AppStorage("weightUnit") private var weightUnit = "kg"
    @AppStorage("defaultSetCount") private var defaultSetCount = 3
    @AppStorage("restTimerDuration") private var restTimerDuration = 60
    @Query private var allWorkouts: [Workout]
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteAllConfirm = false

    private var totalWorkouts: Int {
        allWorkouts.filter { !$0.isActive }.count
    }
    private var totalSets: Int {
        allWorkouts.filter { !$0.isActive }.reduce(0) { $0 + $1.totalSets }
    }
    private var totalVolume: Double {
        allWorkouts.filter { !$0.isActive }.reduce(0) { $0 + $1.totalVolume }
    }

    var body: some View {
        NavigationStack {
            List {
                // 統計サマリー
                Section("あなたの記録") {
                    statsRow
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                // 単位設定
                Section("単位") {
                    Picker("重量の単位", selection: $weightUnit) {
                        Text("kg").tag("kg")
                        Text("lbs").tag("lbs")
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                }

                Section("トレーニング") {
                    Stepper("既定セット数：\(defaultSetCount)", value: $defaultSetCount, in: 1...10)
                    Picker("休憩時間", selection: $restTimerDuration) {
                        ForEach([30, 45, 60, 75, 90, 120, 180], id: \.self) { seconds in
                            Text("\(seconds)秒").tag(seconds)
                        }
                    }
                }

                // アプリ情報
                Section("アプリについて") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("開発者")
                        Spacer()
                        Text("Workout Log Team")
                            .foregroundStyle(.secondary)
                    }
                }

                // データ管理（危険ゾーン）
                Section {
                    Button(role: .destructive) {
                        showingDeleteAllConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("全データを削除")
                        }
                    }
                } header: {
                    Text("データ管理")
                } footer: {
                    Text("削除したデータは復元できません")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppScreenBackground())
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                "全データを削除しますか？\nこの操作は取り消せません。",
                isPresented: $showingDeleteAllConfirm,
                titleVisibility: .visible
            ) {
                Button("全データを削除", role: .destructive) {
                    deleteAllData()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    // MARK: - 統計行

    private var statsRow: some View {
        let vol = weightUnit == "lbs" ? totalVolume * 2.20462 : totalVolume
        return HStack(spacing: 0) {
            settingsMetric(value: "\(totalWorkouts)", label: "トレーニング")
            Divider().frame(height: 38)
            settingsMetric(value: "\(totalSets)", label: "セット")
            Divider().frame(height: 38)
            settingsMetric(
                value: vol >= 1000 ? String(format: "%.1fk", vol / 1000) : "\(Int(vol))",
                label: "ボリューム \(weightUnit)"
            )
        }
        .padding(18)
        .appCard(cornerRadius: AppDesign.cornerHero, padding: 0)
    }

    private func settingsMetric(value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(AppFont.title2).fontWeight(.semibold)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    /// 全データを削除する
    private func deleteAllData() {
        do {
            try modelContext.delete(model: Workout.self)
            try modelContext.delete(model: WorkoutExercise.self)
            try modelContext.delete(model: ExerciseSet.self)
        } catch {
            print("データ削除エラー: \(error)")
        }
    }
}
