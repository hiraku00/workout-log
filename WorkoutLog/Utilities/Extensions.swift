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

// MARK: - セット入力行レイアウト定数（列ズレ防止）
enum SetRowLayout {
    // 値そのものに必要な幅だけを確保する。余った横幅は列間で均等に配分し、
    // 端末が広いほど重量フィールドだけが太ることを防ぐ。
    static let setNumber: CGFloat = 24
    static let weight: CGFloat = 78       // 999.9 kg
    static let reps: CGFloat = 48         // 99 回
    static let oneRM: CGFloat = 56        // 999.9
    static let complete: CGFloat = 32
    static let delete: CGFloat = 32
    static let minimumGap: CGFloat = 6

    static let totalColumnWidth = setNumber + weight + reps + oneRM + complete + delete

    static func gap(for containerWidth: CGFloat) -> CGFloat {
        max(minimumGap, (containerWidth - totalColumnWidth) / 5)
    }

    // 入力行だけはコピー操作と自重ボタンを重量・回数の列内に含める。
    // 上セットのコピー操作と自重ボタンを表示しても、「999.9 kg」を通常の文字サイズで読める幅にする。
    // 回数列と列間余白を詰め、その分を入力頻度の高い重量列へ配分する。
    static let inputWeight: CGFloat = 120
    static let inputReps: CGFloat = 66
    static let inputColumnWidth = setNumber + inputWeight + inputReps + oneRM + complete + delete

    static func inputGap(for containerWidth: CGFloat) -> CGFloat {
        max(minimumGap, (containerWidth - inputColumnWidth) / 5)
    }
}

/// 入力画面と前回記録で共有する表の列幅。
enum WorkoutRecordColumn {
    static let set: CGFloat = SetRowLayout.setNumber
    static let weight: CGFloat = SetRowLayout.weight
    static let reps: CGFloat = SetRowLayout.reps
    static let oneRM: CGFloat = SetRowLayout.oneRM
    static let complete: CGFloat = SetRowLayout.complete
    static let delete: CGFloat = SetRowLayout.delete
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
        Color(.systemBackground)
    }

    static var subtleFill: Color {
        Color(.tertiarySystemFill)
    }

    static var hairline: Color {
        Color(.separator).opacity(0.55)
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
        Color(.separator).opacity(0.32)
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
    var cornerRadius: CGFloat = AppDesign.cornerLarge
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppDesign.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppDesign.materialEdge, lineWidth: 0.7)
            )
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.headline).fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(reduceMotion ? .linear(duration: 0.1) : .easeOut(duration: 0.12), value: configuration.isPressed)
            .modifier(AppProminentControlSurface())
            .contentShape(RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous))
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.subheadline).fontWeight(.semibold)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(AppDesign.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous)
                    .stroke(AppDesign.hairline, lineWidth: 0.5)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? .linear(duration: 0.1) : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppIconButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.9 : 1))
            .animation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.22, dampingFraction: 1), value: configuration.isPressed)
            .modifier(AppIconControlSurface(isPressed: configuration.isPressed))
    }
}

/// iOS 26以降では、コンテンツではなく操作コントロールだけにLiquid Glassを適用する。
private struct AppProminentControlSurface: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                .regular.tint(AppDesign.accent).interactive(),
                in: RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous)
            )
        } else {
            content
                .background(AppDesign.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous))
        }
    }
}

private struct AppIconControlSurface: ViewModifier {
    let isPressed: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                .regular.interactive(),
                in: Circle()
            )
        } else {
            content
                .background(isPressed ? AppDesign.accentFill : AppDesign.subtleFill)
                .clipShape(Circle())
        }
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

/// 画面の最背面。iOSのセマンティック背景色だけを使用し、外観モードに適応させる。
struct AppScreenBackground: View {
    var body: some View {
        AppDesign.appBackground.ignoresSafeArea()
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
    /// 種目名からGoogle画像検索URLを生成する。
    static func imageSearchURL(for exerciseName: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [
            URLQueryItem(name: "tbm", value: "isch"),
            URLQueryItem(name: "q", value: "\(exerciseName) 正しいフォーム")
        ]
        return components?.url
    }

    /// GoogleアプリのUniversal Linkを避け、Braveへ
    /// Google画像検索URLを渡す。Braveがない場合は通常のHTTPS URLへフォールバックする。
    static func openImageSearch(for exerciseName: String) {
        guard let searchURL = imageSearchURL(for: exerciseName) else { return }

        if let browserURL = braveOpenURL(for: searchURL),
           UIApplication.shared.canOpenURL(browserURL) {
            UIApplication.shared.open(browserURL)
        } else {
            UIApplication.shared.open(searchURL)
        }
    }

    static func braveOpenURL(for webURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = "brave"
        components.host = "open-url"
        components.queryItems = [
            URLQueryItem(name: "url", value: webURL.absoluteString)
        ]
        return components.url
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
