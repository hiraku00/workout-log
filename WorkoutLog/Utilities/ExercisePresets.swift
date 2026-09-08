import Foundation

/// プリセット種目のデータ構造
struct ExercisePreset {
    let name: String
    let category: String
    let muscleGroup: String
}

/// アプリ内蔵のプリセット種目一覧
enum ExercisePresets {
    static let all: [ExercisePreset] = chest + back + legs + shoulders + arms + core

    // MARK: - 胸（Chest）
    static let chest: [ExercisePreset] = [
        ExercisePreset(name: "チェストプレス", category: "胸", muscleGroup: "大胸筋"),
        ExercisePreset(name: "インクラインダンベルプレス", category: "胸", muscleGroup: "大胸筋上部"),
    ]

    // MARK: - 背中（Back）
    static let back: [ExercisePreset] = [
        ExercisePreset(name: "チンニング", category: "背中", muscleGroup: "広背筋"),
        ExercisePreset(name: "フロントラットプルダウン", category: "背中", muscleGroup: "広背筋"),
        ExercisePreset(name: "シーテッドロウ", category: "背中", muscleGroup: "広背筋・僧帽筋"),
    ]

    // MARK: - 脚（Legs）
    static let legs: [ExercisePreset] = [
        ExercisePreset(name: "ブルガリアンスクワット", category: "脚", muscleGroup: "大腿四頭筋・臀筋"),
        ExercisePreset(name: "レッグカール", category: "脚", muscleGroup: "ハムストリングス"),
        ExercisePreset(name: "レッグエクステンション", category: "脚", muscleGroup: "大腿四頭筋"),
        ExercisePreset(name: "ヒップアブダクション", category: "脚", muscleGroup: "中臀筋"),
        ExercisePreset(name: "ヒップアダクション", category: "脚", muscleGroup: "内転筋群"),
    ]

    // MARK: - 肩（Shoulders）
    static let shoulders: [ExercisePreset] = [
        ExercisePreset(name: "ワンハンドサイドレイズ", category: "肩", muscleGroup: "三角筋中部"),
        ExercisePreset(name: "ダンベルショルダープレス", category: "肩", muscleGroup: "三角筋"),
    ]

    // MARK: - 腕（Arms）
    static let arms: [ExercisePreset] = [
        ExercisePreset(name: "ダンベルカール", category: "腕", muscleGroup: "上腕二頭筋"),
        ExercisePreset(name: "フレンチプレス", category: "腕", muscleGroup: "上腕三頭筋"),
        ExercisePreset(name: "ダンベルスカルクラッシャー", category: "腕", muscleGroup: "上腕三頭筋"),
    ]

    // MARK: - 体幹（Core）
    static let core: [ExercisePreset] = [
        ExercisePreset(name: "腹筋ローラー", category: "体幹", muscleGroup: "腹直筋・体幹"),
    ]

    // MARK: - カテゴリ情報
    static let categories: [String] = ["胸", "背中", "脚", "肩", "腕", "体幹"]

    static func iconName(for category: String) -> String {
        switch category {
        case "胸":   return "figure.strengthtraining.traditional"
        case "背中": return "figure.rowing"
        case "脚":   return "figure.run"
        case "肩":   return "figure.arms.open"
        case "腕":   return "dumbbell.fill"
        case "体幹": return "figure.core.training"
        default:     return "dumbbell.fill"
        }
    }
}
