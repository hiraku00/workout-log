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

// MARK: - Double拡張
extension Double {
    /// 重量の表示文字列（小数点が不要な場合は整数表示）
    func weightString(unit: String = "") -> String {
        if self == ExerciseSet.bodyweightValue { return "自重" }
        if self == 0 { return "0" }
        if self == Double(Int(self)) {
            return unit.isEmpty ? "\(Int(self))" : "\(Int(self))\(unit)"
        }
        return unit.isEmpty ? String(format: "%.1f", self) : String(format: "%.1f\(unit)", self)
    }

    /// セット重量の表示（自重・単位変換対応）
    func setWeightDisplay(unit: String) -> String {
        if self == ExerciseSet.bodyweightValue { return "自重" }
        let display = unit == "lbs" ? self * 2.20462 : self
        return display.weightString(unit: unit)
    }
}

// MARK: - Color拡張
extension Color {
    /// Appleスタイルのアクセントカラー（グレー基調）
    static let accentColor = Color(red: 0.3, green: 0.3, blue: 0.3)

    /// カテゴリ名からカラーを取得
    static func categoryColor(_ category: String) -> Color {
        switch category {
        case "胸":   return .blue
        case "背中": return .indigo
        case "脚":   return .green
        case "肩":   return .orange
        case "腕":   return .purple
        case "体幹": return .red
        case "有酸素": return .pink
        default:     return .secondary
        }
    }
}

// MARK: - セット入力行レイアウト定数（列ズレ防止）
enum SetRowLayout {
    static let setNumber: CGFloat = 32
    static let weight: CGFloat = 112
    static let reps: CGFloat = 92
    static let oneRM: CGFloat = 48
    static let delete: CGFloat = 36
}

// MARK: - デザインシステム
enum AppDesign {
    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 12
    static let spaceL: CGFloat = 16
    static let spaceXL: CGFloat = 24

    static let cornerSmall: CGFloat = 8
    static let cornerMedium: CGFloat = 12
    static let cornerLarge: CGFloat = 16
    static let cornerHero: CGFloat = 20

    static var appBackground: Color {
        Color(.systemGroupedBackground)
    }

    static var surface: Color {
        Color(.secondarySystemGroupedBackground)
    }

    static var elevatedSurface: Color {
        Color(.systemBackground)
    }

    static var subtleFill: Color {
        Color(.tertiarySystemFill)
    }

    static var hairline: Color {
        Color.primary.opacity(0.08)
    }

    static var accent: Color {
        Color.primary
    }
}

enum AppFont {
    static let fontName = "IPAexMincho"
    static let largeTitle = Font.custom(fontName, size: 34, relativeTo: .largeTitle)
    static let title = Font.custom(fontName, size: 28, relativeTo: .title)
    static let title2 = Font.custom(fontName, size: 22, relativeTo: .title2)
    static let title3 = Font.custom(fontName, size: 20, relativeTo: .title3)
    static let headline = Font.custom(fontName, size: 17, relativeTo: .headline)
    static let body = Font.custom(fontName, size: 17, relativeTo: .body)
    static let input = Font.custom(fontName, size: 18, relativeTo: .body)
    static let subheadline = Font.custom(fontName, size: 15, relativeTo: .subheadline)
    static let caption = Font.custom(fontName, size: 12, relativeTo: .caption)
    static let caption2 = Font.custom(fontName, size: 11, relativeTo: .caption2)
}

struct AppCardModifier: ViewModifier {
    var cornerRadius: CGFloat = AppDesign.cornerLarge
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppDesign.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppDesign.hairline, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 8)
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.headline).fontWeight(.semibold)
            .foregroundStyle(Color(.systemBackground))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(AppDesign.accent)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.subheadline).fontWeight(.semibold)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(AppDesign.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous)
                    .stroke(AppDesign.hairline, lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct AppIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .background(AppDesign.subtleFill)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct AppMetricItem: Identifiable {
    let id = UUID()
    let value: String
    let label: String
}

struct AppMetricGroup: View {
    let items: [AppMetricItem]

    var body: some View {
        ViewThatFits {
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().frame(height: 36) }
                    metric(item)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(items) { metric($0) }
            }
        }
        .appCard(cornerRadius: AppDesign.cornerLarge, padding: 16)
    }

    private func metric(_ item: AppMetricItem) -> some View {
        VStack(spacing: 4) {
            Text(item.value)
                .font(AppFont.title2).fontWeight(.semibold)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(item.label)
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct AppEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.secondary)
            Text(title).font(AppFont.headline)
            Text(message)
                .font(AppFont.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

// MARK: - 種目の動作参考画像
enum ExerciseReference {
    /// 種目名から、正しいフォームを確認できる検索URLを生成する。
    /// 通常のHTTPS URLを使い、端末で設定されたデフォルトブラウザで開く。
    static func imageSearchURL(for exerciseName: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [
            URLQueryItem(name: "tbm", value: "isch"),
            URLQueryItem(name: "q", value: "\(exerciseName) 正しいフォーム")
        ]
        return components?.url
    }

    /// Google アプリの Universal Link を避け、Brave で検索結果を開く。
    /// Brave が入っていない端末では、通常の HTTPS URL にフォールバックする。
    static func openImageSearch(for exerciseName: String) {
        guard let searchURL = imageSearchURL(for: exerciseName) else { return }

        var braveComponents = URLComponents()
        braveComponents.scheme = "brave"
        braveComponents.host = "open-url"
        braveComponents.queryItems = [
            URLQueryItem(name: "url", value: searchURL.absoluteString)
        ]

        if let braveURL = braveComponents.url,
           UIApplication.shared.canOpenURL(braveURL) {
            UIApplication.shared.open(braveURL)
        } else {
            UIApplication.shared.open(searchURL)
        }
    }
}

// MARK: - View拡張
extension View {
    func appCard(cornerRadius: CGFloat = AppDesign.cornerLarge, padding: CGFloat = 16) -> some View {
        modifier(AppCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    /// キーボードを閉じるためのツールバーを追加
    func keyboardDoneToolbar() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .fontWeight(.semibold)
            }
        }
    }
}
