import SwiftUI
import SwiftData
import UserNotifications

@main
struct WorkoutLogApp: App {
    @UIApplicationDelegateAdaptor(WorkoutLogAppDelegate.self) private var appDelegate
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                Workout.self,
                WorkoutExercise.self,
                ExerciseSet.self,
                ExerciseTemplate.self,
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData ModelContainerの初期化に失敗しました: \(error)")
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .modelContainer(modelContainer)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                DataBackupExporter.export(modelContext: modelContainer.mainContext)
            }
        }
    }
}

/// 前面では通知表示を抑止する。完了音とポップアップは画面側で提示する。
/// バックグラウンドではシステムが通常の通知バナーと音を提示する。
final class WorkoutLogAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }
}

/// アプリ起動時の初期化を担当するビュー
struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { $0.isActive }) private var activeWorkouts: [Workout]
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @State private var viewModel = WorkoutViewModel()
    @State private var isInitialized = false

    var body: some View {
        ContentView()
            .environment(viewModel)
            .preferredColorScheme(preferredColorScheme)
            .task {
                if !isInitialized {
                    DataBackupImporter.restoreIfNeeded(modelContext: modelContext)
                    seedExerciseTemplatesIfNeeded()
                    if let active = activeWorkouts.first {
                        viewModel.resumeWorkout(active)
                    }
                    isInitialized = true
                }
            }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    /// 内蔵カタログとデータベースを同期する（実処理は`ExerciseTemplateSeeder`）。
    private func seedExerciseTemplatesIfNeeded() {
        let existingTemplates = (try? modelContext.fetch(FetchDescriptor<ExerciseTemplate>())) ?? []
        ExerciseTemplateSeeder.sync(existingTemplates: existingTemplates, modelContext: modelContext)

        do {
            try modelContext.save()
        } catch {
            print("プリセット種目の保存に失敗しました: \(error)")
        }
    }
}
