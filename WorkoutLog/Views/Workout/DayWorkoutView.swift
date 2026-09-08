import SwiftUI

/// 1日分のワークアウト画面（履歴カレンダーからの遷移先）
/// 左右スワイプで前後の日付へシームレスに遷移できる。
struct DayWorkoutView: View {
    let targetDate: Date

    @State private var currentDate: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(targetDate: Date) {
        self.targetDate = targetDate
        self._currentDate = State(initialValue: Calendar.current.startOfDay(for: targetDate))
    }

    var body: some View {
        TabView(selection: $currentDate) {
            ForEach(dateRange(), id: \.self) { date in
                ScrollView {
                    DayWorkoutContent(targetDate: date)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                }
                .tag(date)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(reduceMotion ? .linear(duration: 0.15) : .spring(response: 0.4, dampingFraction: 1), value: currentDate)
        .background(AppScreenBackground())
        .navigationTitle(currentDate.formatted(.dateTime.year().month().day()))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 前後365日分の日付を生成（スワイプで遷移できる範囲）
    ///
    /// 各ページ（前後1年分、最大約395件）を「選択中の前後だけの窓」に絞る最適化を
    /// 一度試したが、`currentDate`の変化と同時に`ForEach`の配列を組み替えると、
    /// スワイプ中のページ遷移とインデックスがずれて日付を1日飛ばしてしまう不具合が
    /// シミュレータで再現したため、安全な全件生成に戻している。対応するなら
    /// `UIPageViewController`を直接使うなど、選択とデータ変更を同時に起こさない
    /// 設計が必要。
    private func dateRange() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -365, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 30, to: today) ?? today

        var dates: [Date] = []
        var current = start
        while current <= end {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? end
        }
        return dates
    }
}

// 後方互換の型名
typealias ActiveWorkoutView = DayWorkoutView
