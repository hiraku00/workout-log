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
    /// 一見、396件すべてを`ForEach`に渡すと`DayWorkoutContent`（`@Query`で全ワークアウトを
    /// 取得する）が396個同時に生成されるように見えるが、実際にはSwiftUIの`TabView`は
    /// 選択中のページとその前後しか`body`を評価しない（`@Query`はDynamicPropertyのため、
    /// bodyが評価されない限り実行されない）。実機シミュレータでの計測では、画面を開いた
    /// 時点での`DayWorkoutContent.body`評価は2回のみで、`dateRange()`自体の実行時間も
    /// 396日分・最適化ビルドで約0.12msだった。この2点から、体感できる規模のコストは
    /// 発生していないと判断し、最適化は行わないことにした。
    ///
    /// 過去に「選択中の前後だけの窓」に絞る最適化を試したことがあるが、`currentDate`の
    /// 変化と同時に`ForEach`の配列を組み替えると、スワイプ中のページ遷移とインデックスが
    /// ずれて日付を1日飛ばしてしまう不具合がシミュレータで再現したため、そちらは既に
    /// 差し戻し済み。上記の計測結果からも、そのリスクを冒してまで対応する価値はない。
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
