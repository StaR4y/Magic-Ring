import SwiftUI

struct PerformanceDashboardView: View {
    @ObservedObject private var monitor: PerformanceMonitor
    @ObservedObject private var settings: PanelSettings
    @State private var didAppear = false

    init(monitor: PerformanceMonitor, settings: PanelSettings) {
        self.monitor = monitor
        self.settings = settings
    }

    private var snapshot: PerformanceSnapshot? {
        monitor.snapshot
    }

    private var appearance: PanelAppearance {
        settings.style.appearance
    }

    var body: some View {
        VStack(spacing: 12) {
            hardwareSummary
            separator
            statsStrip
            temperatureCurve
        }
        .padding(14)
        .frame(width: 328, height: 248)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(panelBorder)
        .shadow(color: .black.opacity(appearance.shadowOpacity), radius: 18, y: 8)
        .scaleEffect(didAppear ? 1 : 0.965)
        .opacity(didAppear ? 1 : 0)
        .animation(.spring(response: 0.55, dampingFraction: 0.86), value: didAppear)
        .onAppear {
            didAppear = true
        }
    }

    private var hardwareSummary: some View {
        HStack(spacing: 27) {
            MetricRingView(
                title: "CPU",
                systemImage: "cpu",
                value: snapshot?.cpuUsage ?? 0,
                tint: .green,
                size: 64
            )

            MetricRingView(
                title: "MEM",
                systemImage: "memorychip",
                value: snapshot?.memoryUsage ?? 0,
                tint: .mint,
                size: 64
            )

            MetricRingView(
                title: "DISK",
                systemImage: "internaldrive",
                value: snapshot?.diskUsage ?? 0,
                tint: .orange,
                size: 64
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var separator: some View {
        Rectangle()
            .fill(.white.opacity(0.10))
            .frame(height: 1)
            .padding(.horizontal, -14)
    }

    private var statsStrip: some View {
        HStack(spacing: 8) {
            StatTileView(
                title: "CPU Load",
                value: MetricFormatting.load(snapshot?.cpu.loadAverage1m ?? 0),
                progress: cpuLoadProgress,
                tint: .green,
                cardOpacity: appearance.cardOpacity
            )

            StatTileView(
                title: "Memory",
                value: memoryText,
                progress: snapshot?.memoryUsage ?? 0,
                tint: .mint,
                cardOpacity: appearance.cardOpacity
            )

            StatTileView(
                title: "Disk Used",
                value: diskText,
                progress: snapshot?.diskUsage ?? 0,
                tint: .orange,
                cardOpacity: appearance.cardOpacity
            )
        }
        .frame(height: 52)
    }

    private var temperatureCurve: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 12, weight: .semibold))

                Text("Temperature")
                    .font(.system(size: 12, weight: .semibold))

                Spacer(minLength: 0)
            }
            .foregroundStyle(.white.opacity(0.80))

            SparklineView(values: monitor.thermalPressureHistory, tint: thermalTint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(height: 55)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.white.opacity(appearance.cardOpacity))
        )
    }

    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            appearance.overlayStart,
                            appearance.overlayEnd
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var panelBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(.white.opacity(appearance.borderOpacity), lineWidth: 0.8)
    }

    private var cpuLoadProgress: Double {
        let processorCount = max(ProcessInfo.processInfo.processorCount, 1)
        return min((snapshot?.cpu.loadAverage1m ?? 0) / Double(processorCount), 1)
    }

    private var memoryText: String {
        guard let memory = snapshot?.memory else {
            return "--"
        }

        return MetricFormatting.bytes(memory.usedBytes)
    }

    private var diskText: String {
        guard let disk = snapshot?.disk else {
            return "--"
        }

        return MetricFormatting.bytes(disk.availableBytes)
    }

    private var thermalTint: Color {
        switch snapshot?.thermalPressure ?? .unknown {
        case .nominal:
            return .green
        case .fair:
            return .yellow
        case .serious:
            return .orange
        case .critical:
            return .red
        case .unknown:
            return .white.opacity(0.55)
        }
    }
}

private struct StatTileView: View {
    let title: String
    let value: String
    let progress: Double
    let tint: Color
    let cardOpacity: Double

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            ProgressCapsule(value: clampedProgress, tint: tint)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(cardOpacity))
        )
    }
}

private struct ProgressCapsule: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.08))

                Capsule()
                    .fill(tint.gradient)
                    .frame(width: max(7, proxy.size.width * value))
                    .shadow(color: tint.opacity(0.24), radius: 4)
                    .animation(.spring(response: 0.55, dampingFraction: 0.85), value: value)
            }
        }
        .frame(height: 6)
    }
}
