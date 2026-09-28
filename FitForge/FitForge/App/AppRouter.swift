import SwiftUI

enum AppTab: Hashable {
    case today
    case meals
    case add
    case training
    case progress
}

enum TrainingMode: String, CaseIterable, Identifiable {
    case strength = "筋トレ"
    case cardio = "ラン・運動"

    var id: String { rawValue }
}

/// ワークアウト画面を開く内容。ルーティンがあれば、その種目を順番に記録する
struct WorkoutLaunch: Identifiable {
    let id = UUID()
    var exercise: String
    var routine: WorkoutRoutine?
}

/// タブの切り替えと記録シートの表示を、画面をまたいで操作するための状態
@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .today
    @Published var trainingMode: TrainingMode = .strength
    @Published var isQuickAddPresented = false
    @Published var workoutLaunch: WorkoutLaunch?

    func open(_ tab: AppTab) {
        selectedTab = tab
    }

    func startWorkoutSession(exercise: String) {
        workoutLaunch = WorkoutLaunch(exercise: exercise)
    }

    func startRoutine(_ routine: WorkoutRoutine) {
        guard let first = routine.exercises.first else { return }
        workoutLaunch = WorkoutLaunch(exercise: first.name, routine: routine)
    }

    func openTraining(_ mode: TrainingMode) {
        trainingMode = mode
        selectedTab = .training
    }
}
