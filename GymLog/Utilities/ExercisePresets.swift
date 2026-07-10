import Foundation

/// プリセット種目のデータ構造
struct ExercisePreset {
    let name: String
    let category: String
    let muscleGroup: String
}

/// アプリ内蔵のプリセット種目一覧（厳選された主要種目）
enum ExercisePresets {
    static let all: [ExercisePreset] = chest + back + legs + shoulders + arms + core

    // MARK: - 胸（Chest）
    static let chest: [ExercisePreset] = [
        ExercisePreset(name: "ベンチプレス", category: "胸", muscleGroup: "大胸筋"),
        ExercisePreset(name: "ダンベルフライ", category: "胸", muscleGroup: "大胸筋"),
        ExercisePreset(name: "プッシュアップ", category: "胸", muscleGroup: "大胸筋"),
    ]

    // MARK: - 背中（Back）
    static let back: [ExercisePreset] = [
        ExercisePreset(name: "デッドリフト", category: "背中", muscleGroup: "背中全体"),
        ExercisePreset(name: "ラットプルダウン", category: "背中", muscleGroup: "広背筋"),
        ExercisePreset(name: "懸垂", category: "背中", muscleGroup: "広背筋"),
    ]

    // MARK: - 脚（Legs）
    static let legs: [ExercisePreset] = [
        ExercisePreset(name: "スクワット", category: "脚", muscleGroup: "大腿四頭筋・臀筋"),
        ExercisePreset(name: "レッグプレス", category: "脚", muscleGroup: "大腿四頭筋"),
        ExercisePreset(name: "カーフレイズ", category: "脚", muscleGroup: "ふくらはぎ"),
    ]

    // MARK: - 肩（Shoulders）
    static let shoulders: [ExercisePreset] = [
        ExercisePreset(name: "ショルダープレス", category: "肩", muscleGroup: "三角筋"),
        ExercisePreset(name: "サイドレイズ", category: "肩", muscleGroup: "三角筋中部"),
    ]

    // MARK: - 腕（Arms）
    static let arms: [ExercisePreset] = [
        ExercisePreset(name: "アームカール", category: "腕", muscleGroup: "上腕二頭筋"),
        ExercisePreset(name: "ディップス", category: "腕", muscleGroup: "上腕三頭筋"),
    ]

    // MARK: - 体幹（Core）
    static let core: [ExercisePreset] = [
        ExercisePreset(name: "クランチ", category: "体幹", muscleGroup: "腹直筋"),
        ExercisePreset(name: "プランク", category: "体幹", muscleGroup: "体幹全体"),
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

