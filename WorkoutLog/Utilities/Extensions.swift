import Foundation
import SwiftUI

// MARK: - Date拡張
extension Date {
    /// 今日の日付かどうか
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// 表示用の日付文字列（例：6月29日（日））
    var displayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日（E）"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: self)
    }

    /// 短い日付文字列（例：6/29）
    var shortDisplayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: self)
    }

    /// 月日のみ（例：6月29日）
    var monthDayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: self)
    }

    /// 曜日付き短い表示（例：29日（日））
    var dayWeekString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d日（E）"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: self)
    }

    /// 同じカレンダー日かどうか
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    /// 今週のワークアウト用：週の始まり（月曜）を取得
    var startOfWeek: Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // 月曜始まり
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
}

// MARK: - TimeInterval拡張
extension TimeInterval {
    /// 経過時間を "mm:ss" または "hh:mm:ss" 形式に変換
    var timerString: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) / 60 % 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// 分単位の表示（例：45分）
    var minutesString: String {
        let minutes = max(1, Int(self) / 60)
        return "\(minutes)分"
    }

    /// 時間と分の表示（例：1時間30分）
    var hourMinuteString: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) / 60 % 60
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        }
        return "\(minutes)分"
    }
}

// MARK: - 重量単位
/// 表示用の重量単位。`AppStorage`の保存値と一致するRawValueを持つため、
/// `@AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg`のように
/// 文字列を経由せず直接使える。kg↔lbs換算をここへ一本化し、
/// 各画面に`* 2.20462`が個別にベタ書きされるのを防ぐ。
enum WeightUnit: String, CaseIterable, Equatable {
    case kg
    case lbs

    private static let kgToLbsFactor = 2.20462

    /// kg基準で保存されている値を、この単位での表示用の値に変換する。
    func fromKg(_ kgValue: Double) -> Double {
        self == .lbs ? kgValue * Self.kgToLbsFactor : kgValue
    }

    /// この単位で入力された値を、保存用のkg基準の値に変換する。
    func toKg(_ displayValue: Double) -> Double {
        self == .lbs ? displayValue / Self.kgToLbsFactor : displayValue
    }
}

// MARK: - Double拡張
extension Double {
    /// 重量の表示文字列（小数点が不要な場合は整数表示）
    func weightString(unit: String = "") -> String {
        if self == ExerciseSet.bodyweightValue { return "自重" }
        if self == 0 { return "0" }
        if self == Double(Int(self)) {
            return unit.isEmpty ? "\(Int(self))" : "\(Int(self)) \(unit)"
        }
        return unit.isEmpty ? String(format: "%.1f", self) : String(format: "%.1f %@", self, unit)
    }

    /// セット重量の表示（自重・単位変換対応）。selfはkg基準で保存された値。
    func setWeightDisplay(unit: WeightUnit) -> String {
        if self == ExerciseSet.bodyweightValue { return "自重" }
        return unit.fromKg(self).weightString(unit: unit.rawValue)
    }

    /// ボリューム等の大きい数値を「1000以上はk表記」で整形する（単位変換込み）。
    /// selfはkg基準の値。Settings／履歴詳細／日別記録画面で重複していたロジックをここへ統一。
    func formattedVolume(unit: WeightUnit) -> String {
        let value = unit.fromKg(self)
        return value >= 1000
            ? String(format: "%.1fk", value / 1000)
            : String(format: "%.0f", value)
    }
}

