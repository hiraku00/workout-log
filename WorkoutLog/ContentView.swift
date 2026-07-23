import SwiftUI

/// アプリのメインタブコンテナ
struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // ホームタブ
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("ホーム", systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            // 履歴タブ
            HistoryView(mainTabSelection: $selectedTab)
                .tabItem {
                    Label("履歴", systemImage: selectedTab == 1 ? "calendar.circle.fill" : "calendar")
                }
                .tag(1)

            // 種目ライブラリタブ
            ExerciseLibraryView()
                .tabItem {
                    Label("種目", systemImage: selectedTab == 2 ? "dumbbell.fill" : "dumbbell")
                }
                .tag(2)

            // 設定タブ
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: selectedTab == 3 ? "gearshape.fill" : "gearshape")
                }
                .tag(3)
        }
        .tint(AppDesign.accent)
    }
}
