import Foundation
import SwiftData

/// 内蔵プリセット種目とデータベースを同期する処理。
///
/// SwiftUIの`View`から切り離してあるのは、`@Query`のスナップショットに依存すると
/// 直前のinsert/更新が反映されないままになる（復元直後にプリセットが二重作成される
/// 不具合の原因だった）ため。呼び出し側は必ず`modelContext`から直接fetchした
/// 最新の一覧を渡すこと。
enum ExerciseTemplateSeeder {
    /// - Parameters:
    ///   - existingTemplates: `modelContext.fetch(FetchDescriptor<ExerciseTemplate>())`で
    ///     取得した最新の一覧（`@Query`のスナップショットを渡さないこと）。
    ///   - presets: 同期対象のプリセット一覧。テスト用に差し替えられるよう引数化している。
    static func sync(
        existingTemplates: [ExerciseTemplate],
        presets: [ExercisePreset] = ExercisePresets.all,
        modelContext: ModelContext
    ) {
        for preset in presets {
            if let template = existingTemplates.first(where: { !$0.isCustom && $0.name == preset.name }) {
                template.category = preset.category
                template.muscleGroup = preset.muscleGroup
                template.isArchived = false
            } else if let customMatch = existingTemplates.first(where: { $0.isCustom && $0.name == preset.name }) {
                // 同名のカスタム種目をすでに記録していた場合は、削除して作り直すのではなく
                // そのテンプレートを内蔵種目へ昇格させる。IDを変えないことで、紐づく過去の
                // ワークアウト記録・ベスト更新（PR）がそのまま引き継がれる。
                customMatch.isCustom = false
                customMatch.category = preset.category
                customMatch.muscleGroup = preset.muscleGroup
                customMatch.isArchived = false
            } else {
                modelContext.insert(ExerciseTemplate(
                    name: preset.name,
                    category: preset.category,
                    muscleGroup: preset.muscleGroup,
                    isCustom: false
                ))
            }
        }

        let activePresetNames = Set(presets.map(\.name))
        for template in existingTemplates where !template.isCustom && !activePresetNames.contains(template.name) {
            template.isArchived = true
        }
    }
}
