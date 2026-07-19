import SwiftUI
import SwiftData

/// 種目選択ピッカー（ワークアウトへの種目追加に使用）
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExerciseTemplate.name) private var allTemplates: [ExerciseTemplate]

    let existingTemplateIDs: Set<UUID>
    let onSelect: ([ExerciseTemplate]) -> Void
    @State private var selectedTemplateIDs: Set<UUID> = []
    @State private var expandedCategories: Set<String> = []
    @State private var searchText = ""
    @State private var showingAddCustom = false
    @State private var customExerciseName = ""
    @State private var customExerciseCategory = "胸"
    @State private var customExerciseMuscle = ""
    @Environment(\.modelContext) private var modelContext

    /// カテゴリ別にグループ化された種目
    private var groupedTemplates: [(String, [ExerciseTemplate])] {
        ExercisePresets.categories.compactMap { category in
            var items = allTemplates.filter { !$0.isArchived && $0.category == category }
            if !searchText.isEmpty {
                items = items.filter {
                    $0.name.localizedCaseInsensitiveContains(searchText)
                        || $0.muscleGroup.localizedCaseInsensitiveContains(searchText)
                }
            }
            return items.isEmpty ? nil : (category, items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedTemplates, id: \.0) { category, templates in
                    Section {
                        ForEach(visibleTemplates(in: category, templates: templates)) { template in
                            ExerciseTemplateRow(
                                template: template,
                                isSelected: selectedTemplateIDs.contains(template.id),
                                isDisabled: existingTemplateIDs.contains(template.id)
                            ) {
                                if selectedTemplateIDs.contains(template.id) {
                                    selectedTemplateIDs.remove(template.id)
                                } else {
                                    selectedTemplateIDs.insert(template.id)
                                }
                            }
                        }
                    } header: {
                        Label(category, systemImage: ExercisePresets.iconName(for: category))
                            .foregroundStyle(.secondary)
                            .font(AppFont.subheadline)
                            .fontWeight(.semibold)
                    } footer: {
                        HStack {
                            Button("種目を追加") {
                                customExerciseCategory = category
                                showingAddCustom = true
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(category)に種目を追加")

                            Spacer()

                            if searchText.isEmpty && templates.count > 3 {
                                Button(expandedCategories.contains(category) ? "閉じる" : "すべて表示") {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedCategories.contains(category) {
                                            expandedCategories.remove(category)
                                        } else {
                                            expandedCategories.insert(category)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(category)の種目を\(expandedCategories.contains(category) ? "3件に戻す" : "すべて表示")")
                            }
                        }
                        .font(AppFont.subheadline)
                        .textCase(nil)
                    }
                }

                if groupedTemplates.isEmpty {
                    AppEmptyState(
                        icon: "magnifyingglass",
                        title: "種目が見つかりません",
                        message: "別の名前または対象筋肉で検索してください"
                    )
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(24)
            .scrollContentBackground(.hidden)
            .background(AppScreenBackground())
            .navigationTitle("種目を選択")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "種目を検索")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddCustom) {
                addCustomExerciseSheet
            }
            .safeAreaInset(edge: .bottom) {
                if !selectedTemplateIDs.isEmpty {
                    Button("\(selectedTemplateIDs.count)種目を追加") {
                        onSelect(allTemplates.filter { selectedTemplateIDs.contains($0.id) })
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dismiss()
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .padding(16)
                    .background(.ultraThinMaterial)
                }
            }
        }
    }

    private func visibleTemplates(in category: String, templates: [ExerciseTemplate]) -> [ExerciseTemplate] {
        guard searchText.isEmpty, !expandedCategories.contains(category) else { return templates }
        return Array(templates.prefix(3))
    }

    // MARK: - カスタム種目追加シート

    private var addCustomExerciseSheet: some View {
        NavigationStack {
            Form {
                Section("カテゴリ") {
                    LabeledContent("部位", value: customExerciseCategory)
                }
                Section("種目名") {
                    TextField("例：ハンギングニーレイズ", text: $customExerciseName)
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
                    .disabled(!canAddCustomExercise)
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

    private var canAddCustomExercise: Bool {
        let name = customExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && !allTemplates.contains { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
    }
}

// MARK: - 種目行コンポーネント
struct ExerciseTemplateRow: View {
    let template: ExerciseTemplate
    let isSelected: Bool
    let isDisabled: Bool
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

                    Label(isDisabled ? "追加済み" : (isSelected ? "選択中" : "選択"), systemImage: isDisabled ? "checkmark.circle.fill" : (isSelected ? "checkmark.circle.fill" : "circle"))
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
            .disabled(isDisabled)
            .accessibilityLabel("\(template.name)、\(isDisabled ? "追加済み" : (isSelected ? "選択中" : "未選択"))")

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
        .buttonStyle(AppPressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
