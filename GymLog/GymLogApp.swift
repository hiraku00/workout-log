import SwiftUI
import SwiftData

@main
struct GymLogApp: App {
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

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .modelContainer(modelContainer)
        }
    }
}

/// アプリ起動時の初期化を担当するビュー
struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exerciseTemplates: [ExerciseTemplate]
    @Query(filter: #Predicate<Workout> { $0.isActive }) private var activeWorkouts: [Workout]
    @State private var viewModel = WorkoutViewModel()
    @State private var isInitialized = false

    var body: some View {
        ContentView()
            .environment(viewModel)
            .task {
                if !isInitialized {
                    seedExerciseTemplatesIfNeeded()
                    if let active = activeWorkouts.first {
                        viewModel.resumeWorkout(active)
                    }
                    isInitialized = true
                }
            }
    }

    /// プリセット種目が未登録の場合にデータベースへ投入する
    private func seedExerciseTemplatesIfNeeded() {
        guard exerciseTemplates.isEmpty else { return }

        for preset in ExercisePresets.all {
            let template = ExerciseTemplate(
                name: preset.name,
                category: preset.category,
                muscleGroup: preset.muscleGroup,
                isCustom: false
            )
            modelContext.insert(template)
        }

        do {
            try modelContext.save()
        } catch {
            print("プリセット種目の保存に失敗しました: \(error)")
        }
    }
}
