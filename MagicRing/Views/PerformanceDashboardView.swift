import SwiftUI

struct PerformanceDashboardView: View {
    @ObservedObject private var monitor: PerformanceMonitor
    @ObservedObject private var settings: PanelSettings
    @State private var didAppear = false
    @State private var isProcessDetailsExpanded = false

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

    private var isEnglishEnabled: Bool {
        settings.isEnglishEnabled
    }

    var body: some View {
        VStack(spacing: 0) {
            dashboardHeader
            separator

            contentSwitcher

            separator
            footer
        }
        .frame(width: 370, height: 570)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(panelBorder)
        .scaleEffect(didAppear ? 1 : 0.97)
        .opacity(didAppear ? 1 : 0)
        .animation(.spring(response: 0.48, dampingFraction: 0.86), value: didAppear)
        .onAppear {
            didAppear = true
        }
    }

    private var contentSwitcher: some View {
        ZStack {
            if isProcessDetailsExpanded {
                processDetailsContent
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
            } else {
                overviewContent
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        )
                    )
            }
        }
        .frame(height: 420)
        .clipped()
        .animation(.spring(response: 0.44, dampingFraction: 0.86), value: isProcessDetailsExpanded)
    }

    private var overviewContent: some View {
        VStack(spacing: 10) {
            metricStrip
            innerSeparator
            cpuActivitySection
            innerSeparator
            detailStrip
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var processDetailsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localized(chinese: "应用占用情况", english: "App Usage"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.88))

                    Text(localized(chinese: "按 CPU 与内存占用排序", english: "Sorted by CPU and memory usage"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.46))
                }

                Spacer(minLength: 0)

                MetricChip(systemImage: "number", text: "\(snapshot?.processes.count ?? 0)")
            }

            HStack(alignment: .top, spacing: 14) {
                ProcessUsageGroup(
                    title: localized(chinese: "CPU 占用", english: "CPU Usage"),
                    rows: processCPURows,
                    tint: .red,
                    emptyText: localized(chinese: "等待采样", english: "Sampling")
                )

                ProcessUsageGroup(
                    title: localized(chinese: "内存占用", english: "Memory Usage"),
                    rows: processMemoryRows,
                    tint: .green,
                    emptyText: localized(chinese: "暂无数据", english: "No data")
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var dashboardHeader: some View {
        VStack(spacing: 2) {
            VStack(spacing: 2) {
                Text("MagicRing")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))

                Text(systemSubtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.52))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.top, 13)
        .padding(.bottom, 10)
    }

    private var metricStrip: some View {
        HStack(alignment: .top, spacing: 8) {
            GaugeMetricItem(
                title: "DISK",
                value: compactBytes(snapshot?.disk.usedBytes),
                detail: localized(chinese: "已使用", english: "Used"),
                progress: snapshot?.diskUsage ?? 0,
                tint: .blue,
                systemImage: "internaldrive.fill"
            )

            GaugeMetricItem(
                title: "BAT",
                value: batteryText,
                detail: batteryDetailText,
                progress: snapshot?.battery.level ?? 0,
                tint: batteryTint,
                systemImage: batteryIcon
            )

            GaugeMetricItem(
                title: "CPU",
                value: MetricFormatting.percent(snapshot?.cpuUsage ?? 0),
                detail: "\(localized(chinese: "负载", english: "Load")) \(MetricFormatting.load(snapshot?.cpu.loadAverage1m ?? 0))",
                progress: snapshot?.cpuUsage ?? 0,
                tint: .red,
                systemImage: "cpu"
            )

            GaugeMetricItem(
                title: "MEM",
                value: MetricFormatting.percent(snapshot?.memoryUsage ?? 0),
                detail: compactBytes(snapshot?.memory.usedBytes),
                progress: snapshot?.memoryUsage ?? 0,
                tint: .green,
                systemImage: "memorychip"
            )
        }
        .frame(height: 96)
    }

    private var cpuActivitySection: some View {
        TransparentSection {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(cpuText)
                            .font(.system(size: 27, weight: .bold))
                            .foregroundStyle(.white.opacity(0.92))
                            .monospacedDigit()

                        Text(localized(chinese: "CPU 负载", english: "CPU Load"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.60))
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "cpu")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.42))
                }

                UsageBarChart(values: monitor.cpuUsageHistory, tint: .red)
                    .frame(height: 36)
                    .padding(.horizontal, 8)

                HStack {
                    Text(localized(chinese: "现在", english: "Now"))
                    Spacer()
                    Text("20s")
                    Spacer()
                    Text("40s")
                    Spacer()
                    Text("1m")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.36))

                HStack(spacing: 8) {
                    MetricChip(systemImage: "gauge.with.dots.needle.33percent", text: MetricFormatting.load(snapshot?.cpu.loadAverage1m ?? 0))
                    Spacer(minLength: 0)

                    Text(cpuBreakdownText)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.56))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
        .frame(height: 140)
    }

    private var detailStrip: some View {
        HStack(alignment: .top, spacing: 18) {
            InfoColumn(title: localized(chinese: "内存", english: "Memory"), systemImage: "memorychip") {
                CompactLineChart(values: monitor.memoryUsageHistory, tint: .green)
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    detailLine(localized(chinese: "物理", english: "Physical"), value: compactBytes(snapshot?.memory.totalBytes))
                    detailLine(localized(chinese: "已用", english: "Used"), value: compactBytes(snapshot?.memory.usedBytes))
                    detailLine(localized(chinese: "缓存", english: "Cached"), value: compactBytes(snapshot?.memory.availableBytes))
                    detailLine(localized(chinese: "交换", english: "Swap"), value: compactBytes(snapshot?.memory.swapUsedBytes))
                }
            }

            InfoColumn(title: network.interfaceName, systemImage: "wifi") {
                VStack(alignment: .leading, spacing: 4) {
                    networkLine(localized(chinese: "本地", english: "Local"), value: network.localAddress ?? "--")
                    networkLine(localized(chinese: "公网", english: "Public"), value: "--")
                    HStack(spacing: 12) {
                        rateLine("arrow.up", value: MetricFormatting.bytesPerSecond(network.bytesOutPerSecond))
                        rateLine("arrow.down", value: MetricFormatting.bytesPerSecond(network.bytesInPerSecond))
                    }
                }

                NetworkLineChart(
                    downloadValues: monitor.networkDownloadHistory,
                    uploadValues: monitor.networkUploadHistory
                )
                .frame(height: 38)
            }
        }
        .frame(height: 118)
    }

    private var footer: some View {
        Button {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                isProcessDetailsExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isProcessDetailsExpanded ? "chevron.down.circle.fill" : "list.bullet.rectangle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.70))

                VStack(alignment: .leading, spacing: 2) {
                    Text(isProcessDetailsExpanded ? localized(chinese: "收起详情", english: "Hide Details") : localized(chinese: "详细数据", english: "Details"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.82))

                    Text(isProcessDetailsExpanded ? localized(chinese: "返回性能总览", english: "Back to overview") : localized(chinese: "查看应用 CPU / 内存占用", english: "View app CPU / memory usage"))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.42))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.36))
                    .rotationEffect(.degrees(isProcessDetailsExpanded ? 90 : 0))
                    .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isProcessDetailsExpanded)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 80)
    }

    private var separator: some View {
        Rectangle()
            .fill(.white.opacity(0.10))
            .frame(height: 1)
    }

    private var innerSeparator: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)
    }

    private var panelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: 25, style: .continuous)
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
        RoundedRectangle(cornerRadius: 25, style: .continuous)
            .strokeBorder(.white.opacity(appearance.borderOpacity), lineWidth: 0.9)
    }

    private var systemSubtitle: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "Mac · \(ProcessInfo.processInfo.processorCount) Cores · macOS \(version.majorVersion).\(version.minorVersion)"
    }

    private var cpuText: String {
        guard let usage = snapshot?.cpuUsage else {
            return "--"
        }

        return String(format: "%.2f%%", usage * 100)
    }

    private var cpuBreakdownText: String {
        guard let cpu = snapshot?.cpu else {
            return "System: -- | User: -- | Idle: --"
        }

        return "System: \(MetricFormatting.percent(cpu.systemUsage)) | User: \(MetricFormatting.percent(cpu.userUsage)) | Idle: \(MetricFormatting.percent(cpu.idleUsage))"
    }

    private var network: NetworkMetrics {
        snapshot?.network ?? NetworkMetrics(interfaceName: "--", localAddress: nil, bytesInPerSecond: 0, bytesOutPerSecond: 0)
    }

    private var processCPURows: [ProcessUsageRowData] {
        let sortedProcesses = (snapshot?.processes ?? [])
            .sorted { lhs, rhs in
                lhs.cpuUsage == rhs.cpuUsage ? lhs.memoryBytes > rhs.memoryBytes : lhs.cpuUsage > rhs.cpuUsage
            }
        let activeProcesses = sortedProcesses.filter { $0.cpuUsage > 0.0001 }
        let processes = (activeProcesses.isEmpty ? sortedProcesses : activeProcesses).prefix(8)

        return processes.map { process in
            ProcessUsageRowData(
                id: process.pid,
                name: process.name,
                value: MetricFormatting.compactPercent(process.cpuUsage),
                progress: min(max(process.cpuUsage, 0), 1)
            )
        }
    }

    private var processMemoryRows: [ProcessUsageRowData] {
        let totalMemory = Double(snapshot?.memory.totalBytes ?? 0)
        let processes = (snapshot?.processes ?? [])
            .sorted { lhs, rhs in
                lhs.memoryBytes == rhs.memoryBytes ? lhs.cpuUsage > rhs.cpuUsage : lhs.memoryBytes > rhs.memoryBytes
            }
            .prefix(8)

        return processes.map { process in
            let memoryProgress = totalMemory > 0 ? Double(process.memoryBytes) / totalMemory : 0
            return ProcessUsageRowData(
                id: process.pid,
                name: process.name,
                value: MetricFormatting.bytes(process.memoryBytes),
                progress: min(max(memoryProgress, 0), 1)
            )
        }
    }

    private var batteryText: String {
        guard let level = snapshot?.battery.level else {
            return "--"
        }

        return MetricFormatting.percent(level)
    }

    private var batteryDetailText: String {
        guard let battery = snapshot?.battery else {
            return localized(chinese: "估算中", english: "Estimating")
        }

        guard !battery.isCharging else {
            return localized(chinese: "正在充电", english: "Charging")
        }

        guard let seconds = trendBasedBatteryRemainingSeconds else {
            return localized(chinese: "估算中", english: "Estimating")
        }

        return formattedBatteryRemainingTime(seconds)
    }

    private var trendBasedBatteryRemainingSeconds: TimeInterval? {
        guard let currentLevel = snapshot?.battery.level,
              currentLevel > 0,
              snapshot?.battery.isCharging == false else {
            return nil
        }

        let samples = monitor.recentSnapshots
            .compactMap { snapshot -> (level: Double, timestamp: Date)? in
                guard let level = snapshot.battery.level,
                      !snapshot.battery.isCharging else {
                    return nil
                }

                return (level, snapshot.timestamp)
            }

        guard let latest = samples.last else {
            return nil
        }

        let candidates = samples.dropLast().filter { sample in
            latest.timestamp.timeIntervalSince(sample.timestamp) >= 300 &&
            sample.level > latest.level
        }

        guard let baseline = candidates.first else {
            return nil
        }

        let elapsed = latest.timestamp.timeIntervalSince(baseline.timestamp)
        let drainedLevel = baseline.level - latest.level
        guard elapsed > 0, drainedLevel >= 0.01 else {
            return nil
        }

        let drainPerSecond = drainedLevel / elapsed
        guard drainPerSecond > 0 else {
            return nil
        }

        return currentLevel / drainPerSecond
    }

    private func formattedBatteryRemainingTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        if isEnglishEnabled {
            if hours > 0 {
                return "\(hours)h \(minutes)m left"
            }

            return "\(max(minutes, 1))m left"
        }

        if hours > 0 {
            return "可用 \(hours)小时\(minutes)分钟"
        }

        return "可用 \(max(minutes, 1))分钟"
    }

    private var batteryIcon: String {
        guard let battery = snapshot?.battery else {
            return "powerplug"
        }

        return battery.isCharging ? "battery.100percent.bolt" : "battery.100percent"
    }

    private var batteryTint: Color {
        guard let level = snapshot?.battery.level else {
            return .white.opacity(0.45)
        }

        if level < 0.18 {
            return .red
        }

        if level < 0.35 {
            return .orange
        }

        return .green
    }

    private func compactBytes(_ value: UInt64?) -> String {
        guard let value else {
            return "--"
        }

        let gbValue = Double(value) / 1_073_741_824
        if gbValue >= 10 {
            return "\(Int(gbValue.rounded())) GB"
        }

        return String(format: "%.1f GB", gbValue)
    }

    private func localized(chinese: String, english: String) -> String {
        isEnglishEnabled ? english : chinese
    }

    private func detailLine(_ title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(title):")
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .foregroundStyle(.white.opacity(0.82))
                .fontWeight(.bold)
        }
        .font(.system(size: 9, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }

    private func networkLine(_ title: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text("\(title):")
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .foregroundStyle(.white.opacity(0.82))
                .fontWeight(.bold)
        }
        .font(.system(size: 10, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }

    private func rateLine(_ icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.52))
            Text(value)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
    }
}

private struct GaugeMetricItem: View {
    let title: String
    let value: String
    let detail: String
    let progress: Double
    let tint: Color
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                MiniGauge(value: progress, tint: tint, size: 47)

                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.42))
                    .offset(x: 8, y: -4)
            }
            .frame(height: 50)

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.52))

                Text(value)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.90))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Text(detail)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
    }
}

private struct TransparentSection<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct InfoColumn<Content: View>: View {
    let title: String
    let systemImage: String
    private let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.90))

                Spacer(minLength: 0)

                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.42))
            }

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct MiniGauge: View {
    let value: Double
    let tint: Color
    var size: CGFloat = 38

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 4)

            Circle()
                .trim(from: 0, to: clampedValue)
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.22), radius: 4)
                .animation(.spring(response: 0.45, dampingFraction: 0.84), value: clampedValue)

            Text(MetricFormatting.percent(clampedValue))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.76))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
        }
        .frame(width: size, height: size)
    }
}

private struct UsageBarChart: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(displayValues.enumerated()), id: \.offset) { _, value in
                    Capsule()
                        .fill(tint.opacity(0.36 + value * 0.58))
                        .frame(width: 3.5, height: max(4, proxy.size.height * value))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .animation(.easeOut(duration: 0.28), value: displayValues)
        }
    }

    private var displayValues: [Double] {
        let samples = Array(values.suffix(54))
        if samples.count >= 10 {
            return samples.map { min(max($0, 0), 1) }
        }

        return Array(repeating: 0.08, count: 54 - samples.count) + samples.map { min(max($0, 0), 1) }
    }
}

private struct CompactLineChart: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(.clear)

                LineHistoryShape(values: normalizedValues)
                    .stroke(tint.gradient, style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .animation(.easeOut(duration: 0.3), value: normalizedValues)
            }
        }
    }

    private var normalizedValues: [Double] {
        values.map { min(max($0, 0), 1) }
    }
}

private struct NetworkLineChart: View {
    let downloadValues: [Double]
    let uploadValues: [Double]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LineHistoryShape(values: normalized(downloadValues))
                    .stroke(.blue.opacity(0.95), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                LineHistoryShape(values: normalized(uploadValues))
                    .stroke(.green.opacity(0.95), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(.easeOut(duration: 0.3), value: downloadValues + uploadValues)
        }
    }

    private func normalized(_ values: [Double]) -> [Double] {
        let visibleValues = Array(values.suffix(48))
        let maximumValue = max(downloadValues.max() ?? 0, uploadValues.max() ?? 0, 1)
        return visibleValues.map { min(max($0 / maximumValue, 0), 1) }
    }
}

private struct LineHistoryShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        guard values.count > 1 else {
            return Path()
        }

        let stepX = rect.width / CGFloat(values.count - 1)
        var path = Path()

        for index in values.indices {
            let x = CGFloat(index) * stepX
            let y = rect.maxY - CGFloat(values[index]) * rect.height
            let point = CGPoint(x: x, y: y)

            if index == values.startIndex {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}

private struct ProcessUsageRowData: Identifiable, Equatable {
    let id: Int32
    let name: String
    let value: String
    let progress: Double
}

private struct ProcessUsageGroup: View {
    let title: String
    let rows: [ProcessUsageRowData]
    let tint: Color
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint.opacity(0.82))

            if rows.isEmpty {
                Text(emptyText)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.42))
                    .frame(height: 30, alignment: .center)
            } else {
                ForEach(rows) { row in
                    ProcessUsageRow(row: row, tint: tint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct ProcessUsageRow: View {
    let row: ProcessUsageRowData
    let tint: Color

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                Text(row.name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                Text(row.value)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.07))

                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: max(4, proxy.size.width * row.progress))
                }
            }
            .frame(height: 2)
        }
        .animation(.easeOut(duration: 0.25), value: row.progress)
    }
}

private struct MetricChip: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.46))

            Text(text)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.035), in: Capsule())
    }
}
