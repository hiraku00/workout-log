import Foundation
import SwiftData

/// 種目のテンプレート（プリセット種目 + ユーザー追加カスタム種目）
@Model
final class ExerciseTemplate {
    var id: UUID = UUID()
    /// 種目名（例：ベンチプレス）
    var name: String = ""
    /// カテゴリ（例：胸、背中、脚）
    var category: String = ""
    /// 対象筋肉群（例：大胸筋）
    var muscleGroup: String = ""
    /// ユーザーが追加したカスタム種目か
    var isCustom: Bool = false
    /// 一覧から非表示にする。過去記録との関連は保持する。
    var isArchived: Bool = false

    init(name: String, category: String, muscleGroup: String, isCustom: Bool = false) {
        self.name = name
        self.category = category
        self.muscleGroup = muscleGroup
        self.isCustom = isCustom
    }
}
