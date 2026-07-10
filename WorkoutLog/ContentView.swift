import SwiftUI

/// アプリのメインタブコンテナ
struct ContentView: View {
    @State private var selectedTab = 0

    init() {
        if let navigationFont = UIFont(name: AppFont.fontName, size: 17),
           let largeNavigationFont = UIFont(name: AppFont.fontName, size: 34),
           let tabFont = UIFont(name: AppFont.fontName, size: 11),
           let controlFont = UIFont(name: AppFont.fontName, size: 13) {
            UINavigationBar.appearance().titleTextAttributes = [.font: navigationFont]
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: largeNavigationFont]

            let tabAppearance = UITabBarAppearance()
            tabAppearance.configureWithDefaultBackground()
            [
                tabAppearance.stackedLayoutAppearance,
                tabAppearance.inlineLayoutAppearance,
                tabAppearance.compactInlineLayoutAppearance
            ].forEach { itemAppearance in
                itemAppearance.normal.titleTextAttributes = [.font: tabFont]
                itemAppearance.selected.titleTextAttributes = [.font: tabFont]
            }
            UITabBar.appearance().standardAppearance = tabAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance

            UISegmentedControl.appearance().setTitleTextAttributes([.font: controlFont], for: .normal)
            UISegmentedControl.appearance().setTitleTextAttributes([.font: controlFont], for: .selected)
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // ホームタブ
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }
                .tag(0)

            // 履歴タブ
            HistoryView(mainTabSelection: $selectedTab)
                .tabItem {
                    Label("履歴", systemImage: "calendar")
                }
                .tag(1)

            // 種目ライブラリタブ
            ExerciseLibraryView()
                .tabItem {
                    Label("種目", systemImage: "dumbbell")
                }
                .tag(2)

            // 設定タブ
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
                .tag(3)
        }
        .tint(AppDesign.accent)
        .font(AppFont.body)
    }
}
