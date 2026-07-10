import SwiftUI
import SwiftData

/// 種目選択ピッカー（ワークアウトへの種目追加に使用）
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExerciseTemplate.name) private var allTemplates: [ExerciseTemplate]

    let onSelect: (ExerciseTemplate) -> Void
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var showingAddCustom = false
    @State private var customExerciseName = ""
    @State private var customExerciseCategory = "胸"
    @State private var customExerciseMuscle = ""
    @Environment(\.modelContext) private var modelContext

    /// フィルタリングされた種目一覧
    private var filteredTemplates: [ExerciseTemplate] {
        var results = allTemplates
        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            results = results.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return results
    }

    /// カテゴリ別にグループ化された種目
    private var groupedTemplates: [(String, [ExerciseTemplate])] {
        let categories = ExercisePresets.categories
        if selectedCategory != nil || !searchText.isEmpty {
            return [("結果", filteredTemplates)]
        }
        return categories.compactMap { category in
            let items = allTemplates.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // カテゴリフィルターバー
                categoryFilterBar

                // 種目リスト
                List {
                    ForEach(groupedTemplates, id: \.0) { category, templates in
                        Section {
                            ForEach(templates) { template in
                                ExerciseTemplateRow(template: template) {
                                    onSelect(template)
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    dismiss()
                                }
                            }
                        } header: {
                            if groupedTemplates.count > 1 {
                                Label(category, systemImage: ExercisePresets.iconName(for: category))
                                    .foregroundStyle(.secondary)
                                    .font(AppFont.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("種目を選択")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "種目を検索")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
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
        }
    }

    // MARK: - カテゴリフィルターバー

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 「すべて」ボタン
                FilterChip(
                    label: "すべて",
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation { selectedCategory = nil }
                }

                ForEach(ExercisePresets.categories, id: \.self) { category in
                    FilterChip(
                        label: category,
                        icon: ExercisePresets.iconName(for: category),
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(AppDesign.appBackground)
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
}

// MARK: - 種目行コンポーネント
struct ExerciseTemplateRow: View {
    let template: ExerciseTemplate
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // カテゴリアイコン（モノトーン）
                    ZStack {
                        Circle()
                            .fill(AppDesign.subtleFill)
                            .frame(width: 36, height: 36)
                        Image(systemName: ExercisePresets.iconName(for: template.category))
                            .font(AppFont.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }

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

                    Label("追加", systemImage: "plus")
                        .font(AppFont.caption)
                        .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 32)
                            .background(AppDesign.subtleFill)
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(template.name)を追加")
            .accessibilityHint("行全体をタップして追加できます")

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
    }
}

// MARK: - フィルターチップ（モノトーン）
struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(AppFont.caption2)
                Text(label)
                    .font(AppFont.caption).fontWeight(.semibold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? AppDesign.accent : AppDesign.elevatedSurface)
            .foregroundStyle(isSelected ? Color(.systemBackground) : Color.primary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppDesign.hairline, lineWidth: 0.5))
        }
    }
}
