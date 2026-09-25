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

/// タブの切り替えと記録シートの表示を、画面をまたいで操作するための状態
@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .today
    @Published var trainingMode: TrainingMode = .strength
    @Published var isQuickAddPresented = false

    func open(_ tab: AppTab) {
        selectedTab = tab
    }

    func openTraining(_ mode: TrainingMode) {
        trainingMode = mode
        selectedTab = .training
    }
}
