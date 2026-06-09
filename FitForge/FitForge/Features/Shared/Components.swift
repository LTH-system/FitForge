import SwiftUI

struct MetricCard: View {
    var title: String
    var value: String
    var unit: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.bold().monospacedDigit())
                    .minimumScaleFactor(0.7)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct DeltaCard: View {
    var title: String
    var kg: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(kg, specifier: "%+.2f")kg")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(kg <= 0 ? .green : .red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct PFCRow: View {
    var protein: Int
    var fat: Int
    var carb: Int

    var body: some View {
        HStack(spacing: 8) {
            macro("P", protein, .blue)
            macro("F", fat, .orange)
            macro("C", carb, .green)
        }
    }

    private func macro(_ label: String, _ value: Int, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label).bold()
            Text("\(value)g").monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }
}

struct ComparisonRow: View {
    var label: String
    var predicted: Double
    var actual: Double

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline.bold())
            Spacer()
            VStack(alignment: .trailing) {
                Text("理論 \(predicted, specifier: "%+.2f")kg")
                Text("実績 \(actual, specifier: "%+.2f")kg")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

extension View {
    func panelStyle() -> some View {
        self
            .padding(16)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}
