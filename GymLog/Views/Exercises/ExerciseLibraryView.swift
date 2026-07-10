import SwiftUI
import SwiftData

/// 種目ライブラリ画面：全プリセット種目一覧とPR記録
struct ExerciseLibraryView: View {
    @Query(sort: \ExerciseTemplate.name) private var allTemplates: [ExerciseTemplate]
    @Query(sort: \Workout.date, order: .reverse) private var allWorkouts: [Workout]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var showingDeleteConfirm = false
    @State private var templateToDelete: ExerciseTemplate?
    @State private var showingAddCustom = false
    @State private var customExerciseName = ""
    @State private var customExerciseCategory = "胸"
    @State private var customExerciseMuscle = ""

    private var completedWorkouts: [Workout] {
        allWorkouts.filter { !$0.isActive }
    }

    private var filteredTemplates: [ExerciseTemplate] {
        var result = allTemplates
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    private var groupedTemplates: [(String, [ExerciseTemplate])] {
        if selectedCategory != nil || !searchText.isEmpty {
            return [("検索結果", filteredTemplates)]
        }
        return ExercisePresets.categories.compactMap { cat in
            let items = allTemplates.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // カテゴリフィルター
                categoryFilter

                // 種目リスト
                List {
                    ForEach(groupedTemplates, id: \.0) { category, templates in
                        Section {
                            ForEach(templates) { template in
                                LibraryExerciseRow(
                                    template: template,
                                    personalRecord: personalRecord(for: template)
                                )
                                .swipeActions(edge: .trailing) {
                                    if template.isCustom {
                                        Button(role: .destructive) {
                                            templateToDelete = template
                                            showingDeleteConfirm = true
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: ExercisePresets.iconName(for: category))
                                    .foregroundStyle(.secondary)
                                Text(category)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(templates.count)種目")
                                    .foregroundStyle(.secondary)
                            }
                            .font(AppFont.subheadline)
                            .fontWeight(.semibold)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .background(AppDesign.appBackground)
            .navigationTitle("種目ライブラリ")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "種目を検索")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddCustom = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showingAddCustom) {
                addCustomExerciseSheet
            }
            .alert("削除しますか？", isPresented: $showingDeleteConfirm, presenting: templateToDelete) { template in
                Button("削除", role: .destructive) {
                    modelContext.delete(template)
                }
                Button("キャンセル", role: .cancel) {}
            } message: { template in
                Text("\"\(template.name)\" を削除します。")
            }
        }
    }

    // MARK: - カスタム種目追加シート

    private var addCustomExerciseSheet: some View {
        NavigationStack {
            Form {
                Section("種目名") {
                    TextField("例：ハンギングニーレイズ", text: $customExerciseName)
                }
                Section("カテゴリ") {
                    Picker("カテゴリ", selection: $customExerciseCategory) {
                        ForEach(ExercisePresets.categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                Section("対象筋肉（任意）") {
                    TextField("例：腹直筋", text: $customExerciseMuscle)
                }
            }
            .navigationTitle("カスタム種目を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { showingAddCustom = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        addCustomExercise()
                        showingAddCustom = false
                    }
                    .fontWeight(.semibold)
                    .disabled(customExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addCustomExercise() {
        let template = ExerciseTemplate(
            name: customExerciseName.trimmingCharacters(in: .whitespaces),
            category: customExerciseCategory,
            muscleGroup: customExerciseMuscle.isEmpty ? customExerciseCategory : customExerciseMuscle,
            isCustom: true
        )
        modelContext.insert(template)
        customExerciseName = ""
        customExerciseMuscle = ""
    }

    // MARK: - カテゴリフィルター

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: "すべて",
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation { selectedCategory = nil }
                }
                ForEach(ExercisePresets.categories, id: \.self) { cat in
                    FilterChip(
                        label: cat,
                        icon: ExercisePresets.iconName(for: cat),
                        isSelected: selectedCategory == cat
                    ) {
                        withAnimation {
                            selectedCategory = selectedCategory == cat ? nil : cat
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(AppDesign.appBackground)
    }

    /// 指定種目のPR（最高重量）を取得
    private func personalRecord(for template: ExerciseTemplate) -> Double {
        completedWorkouts
            .flatMap { $0.workoutExercises }
            .filter { $0.exerciseTemplate?.id == template.id }
            .flatMap { $0.sets }
            .map { $0.weight }
            .max() ?? 0
    }
}

// MARK: - ライブラリ種目行
struct LibraryExerciseRow: View {
    let template: ExerciseTemplate
    let personalRecord: Double
    @AppStorage("weightUnit") private var weightUnit = "kg"

    var body: some View {
        HStack(spacing: 12) {
            // カテゴリアイコン（モノトーン）
            ZStack {
                Circle()
                    .fill(AppDesign.subtleFill)
                    .frame(width: 38, height: 38)
                Image(systemName: ExercisePresets.iconName(for: template.category))
                    .font(AppFont.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            // 種目名・筋肉群
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(template.name)
                        .font(AppFont.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    if template.isCustom {
                        Text("カスタム")
                            .font(AppFont.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
                Text(template.muscleGroup)
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // PR表示
            if personalRecord > 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    let display = weightUnit == "lbs" ? personalRecord * 2.20462 : personalRecord
                    Text(display.weightString(unit: weightUnit))
                        .font(AppFont.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    Text("PR")
                        .font(AppFont.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }

            // 動作の参考画像を確認
            Button {
                ExerciseReference.openImageSearch(for: template.name)
            } label: {
                Image(systemName: "camera")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(template.name)の参考画像を検索")
        }
        .padding(.vertical, 4)
    }
}
