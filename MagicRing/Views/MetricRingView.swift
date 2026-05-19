import SwiftUI

struct MetricRingView: View {
    let title: String
    let systemImage: String
    let value: Double
    let tint: Color
    let size: CGFloat

    init(
        title: String,
        systemImage: String,
        value: Double,
        tint: Color,
        size: CGFloat = 58
    ) {
        self.title = title
        self.systemImage = systemImage
        self.value = value
        self.tint = tint
        self.size = size
    }

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.13), lineWidth: 7)

            Circle()
                .trim(from: 0, to: clampedValue)
                .stroke(
                    tint.gradient,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.30), radius: 6, y: 1)
                .animation(.spring(response: 0.7, dampingFraction: 0.82), value: clampedValue)

            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))

                Text(title)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.92))

                Text(MetricFormatting.percent(clampedValue))
                    .font(.system(size: 9, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(MetricFormatting.percent(clampedValue))")
    }
}
