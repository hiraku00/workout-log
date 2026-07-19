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
    // iPhone 幅で「999.9 kg / 99 回 / 999.9 / 完了 / 削除」を
    // 等しく読める密度で収める。入力・前回記録・一覧で共通に使う。
    static let setNumber: CGFloat = 28
    static let weight: CGFloat = 96
    static let reps: CGFloat = 58
    static let oneRM: CGFloat = 62
    static let complete: CGFloat = 32
    static let delete: CGFloat = 32
    static let spacing: CGFloat = 6
}

/// 入力画面と前回記録で共有する表の列幅。
enum WorkoutRecordColumn {
    static let set: CGFloat = SetRowLayout.setNumber
    static let weight: CGFloat = SetRowLayout.weight
    static let reps: CGFloat = SetRowLayout.reps
    static let oneRM: CGFloat = SetRowLayout.oneRM
    static let complete: CGFloat = SetRowLayout.complete
    static let delete: CGFloat = SetRowLayout.delete
    static let spacing: CGFloat = SetRowLayout.spacing
}

// MARK: - デザインシステム
enum AppDesign {
    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 12
    static let spaceL: CGFloat = 16
    static let spaceXL: CGFloat = 24
    static let spaceXXL: CGFloat = 32

    static let cornerSmall: CGFloat = 8
    static let cornerMedium: CGFloat = 12
    static let cornerLarge: CGFloat = 16
    static let cornerHero: CGFloat = 20
    static let cornerSheet: CGFloat = 28

    static var appBackground: Color {
        Color(.systemGroupedBackground)
    }

    static var surface: Color {
        Color(.secondarySystemGroupedBackground)
    }

    static var elevatedSurface: Color {
        Color(.secondarySystemGroupedBackground)
    }

    static var subtleFill: Color {
        Color(.tertiarySystemFill)
    }

    static var hairline: Color {
        Color.primary.opacity(0.09)
    }

    static var accent: Color {
        Color.accentColor
    }

    static var accentFill: Color {
        Color.accentColor.opacity(0.14)
    }

    static var positive: Color {
        Color(.systemGreen)
    }

    static var materialEdge: Color {
        Color.white.opacity(0.22)
    }
}

enum AppFont {
    // Dynamic Typeと光学サイズ調整をOSに委ね、全画面でSan Franciscoを使う。
    static let fontName = ".AppleSystemUIFont"
    static let largeTitle = Font.system(.largeTitle, design: .default, weight: .bold)
    static let title = Font.system(.title, design: .default, weight: .bold)
    static let title2 = Font.system(.title2, design: .rounded, weight: .semibold)
    static let title3 = Font.system(.title3, design: .default, weight: .semibold)
    static let headline = Font.system(.headline, design: .default)
    static let body = Font.system(.body, design: .default)
    static let input = Font.system(.body, design: .rounded, weight: .semibold)
    static let subheadline = Font.system(.subheadline, design: .default)
    static let caption = Font.system(.caption, design: .default)
    static let caption2 = Font.system(.caption2, design: .default)
}

struct AppCardModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var cornerRadius: CGFloat = AppDesign.cornerLarge
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(reduceTransparency ? AnyShapeStyle(AppDesign.elevatedSurface) : AnyShapeStyle(.thinMaterial))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppDesign.materialEdge, lineWidth: 0.7)
            )
            .shadow(color: .black.opacity(0.055), radius: 16, x: 0, y: 7)
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.headline).fontWeight(.semibold)
            .foregroundStyle(Color(.systemBackground))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(AppDesign.accent)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous))
            .brightness(configuration.isPressed ? -0.08 : 0)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .animation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.24, dampingFraction: 1), value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous))
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.subheadline).fontWeight(.semibold)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(reduceTransparency ? AnyShapeStyle(AppDesign.elevatedSurface) : AnyShapeStyle(.thinMaterial))
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous)
                    .stroke(AppDesign.hairline, lineWidth: 0.5)
            )
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.24, dampingFraction: 1), value: configuration.isPressed)
    }
}

struct AppIconButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .background(configuration.isPressed ? AppDesign.accentFill : AppDesign.subtleFill)
            .clipShape(Circle())
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.9 : 1))
            .animation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.22, dampingFraction: 1), value: configuration.isPressed)
    }
}

/// リスト行やカード全体に、touch-downから分かる物理的な押下感を与える。
struct AppPressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.985 : 1))
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(reduceMotion ? .linear(duration: 0.08) : .spring(response: 0.2, dampingFraction: 1), value: configuration.isPressed)
    }
}

struct AppSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppFont.title3)
                .fontWeight(.semibold)
                .tracking(-0.2)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(AppFont.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .frame(minHeight: 32)
    }
}

/// 画面の最背面。大きな装飾を動かさず、淡い光だけで奥行きを作る。
struct AppScreenBackground: View {
    var body: some View {
        ZStack {
            AppDesign.appBackground
            RadialGradient(
                colors: [AppDesign.accent.opacity(0.11), .clear],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 360
            )
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
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
