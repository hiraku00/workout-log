import SwiftUI
import SwiftData

@main
struct WorkoutLogApp: App {
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

    /// 内蔵カタログとデータベースを同期する。廃止種目は履歴保護のためアーカイブする。
    private func seedExerciseTemplatesIfNeeded() {
        for preset in ExercisePresets.all {
            if let template = exerciseTemplates.first(where: { !$0.isCustom && $0.name == preset.name }) {
                template.category = preset.category
                template.muscleGroup = preset.muscleGroup
                template.isArchived = false
            } else {
                modelContext.insert(ExerciseTemplate(
                    name: preset.name,
                    category: preset.category,
                    muscleGroup: preset.muscleGroup,
                    isCustom: false
                ))
            }
        }

        let activePresetNames = Set(ExercisePresets.all.map(\.name))
        for template in exerciseTemplates where !template.isCustom && !activePresetNames.contains(template.name) {
            template.isArchived = true
        }

        do {
            try modelContext.save()
        } catch {
            print("プリセット種目の保存に失敗しました: \(error)")
        }
    }
}
