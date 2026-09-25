import SwiftUI

/// 筋トレと有酸素（ラン・HYROX・マラソン）をまとめたトレーニングタブ
struct TrainingHubView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack {
            Group {
                switch router.trainingMode {
                case .strength:
                    TrainingView()
                case .cardio:
                    CardioView()
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                FFSegmentedPicker(
                    options: TrainingMode.allCases,
                    label: { $0.rawValue },
                    selection: $router.trainingMode,
                    tint: router.trainingMode == .strength ? FF.strength : FF.run
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(FF.background)
            }
            .navigationTitle("トレーニング")
        }
    }
}
