import SwiftUI
import SwiftData

/// 設定画面
struct SettingsView: View {
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("oneRMFormula") private var oneRMFormula = OneRMFormula.epley.rawValue
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
                        Text("kg").tag(WeightUnit.kg)
                        Text("lbs").tag(WeightUnit.lbs)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                }

                Section("外観") {
                    Picker("表示モード", selection: $appearanceMode) {
                        Text("システム設定").tag("system")
                        Text("ライト").tag("light")
                        Text("ダーク").tag("dark")
                    }
                }

                Section {
                    Stepper("既定セット数：\(defaultSetCount)", value: $defaultSetCount, in: 1...10)
                    Picker("休憩時間", selection: $restTimerDuration) {
                        ForEach([30, 45, 60, 75, 90, 120, 180], id: \.self) { seconds in
                            Text("\(seconds)秒").tag(seconds)
                        }
                    }

                    Picker("推定1RM", selection: $oneRMFormula) {
                        ForEach(OneRMFormula.allCases) { formula in
                            Text(formula.displayName).tag(formula.rawValue)
                        }
                    }
                } header: {
                    Text("トレーニング")
                } footer: {
                    Text("休憩終了はiOSのアラームで確実にお知らせします。再生中の音楽や動画は停止する場合があります。")
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
        HStack(spacing: 0) {
            settingsMetric(value: "\(totalWorkouts)", label: "トレーニング")
            Divider().frame(height: 38)
            settingsMetric(value: "\(totalSets)", label: "セット")
            Divider().frame(height: 38)
            settingsMetric(
                value: totalVolume.formattedVolume(unit: weightUnit),
                label: "ボリューム \(weightUnit.rawValue)"
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
            // Mac側の自動バックアップ（最大30世代）が後から復元用ファイルとして
            // 送り込まれても、削除した記録が復活しないようIDを記録しておく。
            let deletedIDs = try modelContext.fetch(FetchDescriptor<Workout>()).map(\.id)
            DeletedWorkoutTombstones.record(deletedIDs)

            try modelContext.delete(model: Workout.self)
            try modelContext.delete(model: WorkoutExercise.self)
            try modelContext.delete(model: ExerciseSet.self)

            // 端末側の自動書き出しをこの場で最新化し、Mac側の次回バックアップ取得を
            // 削除後の状態に早く追いつかせる。
            DataBackupExporter.export(modelContext: modelContext)
        } catch {
            print("データ削除エラー: \(error)")
        }
    }
}
