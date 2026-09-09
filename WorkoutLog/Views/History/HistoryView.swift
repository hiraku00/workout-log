import SwiftUI
import SwiftData
import Charts

/// 履歴画面：月間カレンダーと負荷部位フィルターダッシュボード (モノトーンAppleスタイル)
struct HistoryView: View {
    @Query(sort: \Workout.date, order: .forward) private var allWorkouts: [Workout]

    @Environment(WorkoutViewModel.self) var viewModel
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Binding var mainTabSelection: Int

    @State private var selectedCategory: String = "すべて"
    @State private var selectedTab: String = "カレンダー"
    // 月初に正規化した値だけを選択状態にする。時刻を含む Date() を使うと
    // TabView の月初タグと一致せず、過去月が開くことがある。
    @State var selectedMonth: Date = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: Date())
    ) ?? Date()

    private let categories = ["すべて", "胸", "背中", "脚", "肩", "腕", "体幹"]
    let calendar = Calendar.current

    /// 完了済みワークアウトのみ (日付順)
    private var completedWorkouts: [Workout] {
        allWorkouts.filter { !$0.isActive }
    }

    /// 選択されたカテゴリに該当するワークアウトのみフィルタ
    var filteredWorkouts: [Workout] {
        if selectedCategory == "すべて" {
            return completedWorkouts
        }
        return completedWorkouts.filter { workout in
            workout.workoutExercises.contains { exercise in
                exercise.exerciseTemplate?.category == selectedCategory
            }
        }
    }

    /// フィルタされた日付のセット (yyyyMMdd形式)
    var workoutDateMap: [String: Workout] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        var map: [String: Workout] = [:]
        for workout in filteredWorkouts {
            let key = formatter.string(from: workout.date)
            map[key] = workout
        }
        return map
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. 上部部位フィルター
                categoryFilterBar

                // 2. カレンダー・グラフ切り替えタブ
                segmentControl

                ScrollView {
                    VStack(spacing: 24) {
                        if selectedTab == "カレンダー" {
                            // 3. 月間カレンダー
                            calendarCardView
                        } else {
                            // 4. グラフ表示 (Total weight & Max RM)
                            chartsSectionView
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(AppScreenBackground())
            .navigationTitle("履歴")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                selectedMonth = normalizedMonth(selectedMonth)
            }
        }
    }

    // MARK: - 1. 部位フィルター (赤を廃止し、黒・グレーに変更)
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { cat in
                    Button {
                        withAnimation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.28, dampingFraction: 1)) {
                            selectedCategory = cat
                        }
                    } label: {
                        Text(cat)
                            .font(AppFont.caption).fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedCategory == cat ? AppDesign.accent : AppDesign.elevatedSurface)
                            .foregroundStyle(selectedCategory == cat ? Color(.systemBackground) : Color.primary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppDesign.hairline, lineWidth: 0.5))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(AppDesign.appBackground)
        .sensoryFeedback(.selection, trigger: selectedCategory)
    }

    // MARK: - 2. セグメントコントロール
    private var segmentControl: some View {
        HStack(spacing: 0) {
            segmentButton(title: "カレンダー")
            segmentButton(title: "グラフ")
        }
        .padding(4)
        .background(AppDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.cornerMedium, style: .continuous)
                .stroke(AppDesign.hairline, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func segmentButton(title: String) -> some View {
        Button {
            withAnimation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.28, dampingFraction: 1)) {
                selectedTab = title
            }
        } label: {
            Text(title)
                .font(AppFont.subheadline).fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedTab == title ? AppDesign.subtleFill : Color.clear)
                .foregroundStyle(selectedTab == title ? Color.primary : Color.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: selectedTab == title ? .black.opacity(0.04) : .clear, radius: 2, x: 0, y: 1)
        }
    }
}
