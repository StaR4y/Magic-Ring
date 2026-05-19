import Combine
import Foundation

@MainActor
final class PerformanceMonitor: ObservableObject {
    @Published private(set) var snapshot: PerformanceSnapshot?

    private var engine: SamplingEngine? = nil
    private var historyBuffer: FixedSizeRingBuffer<PerformanceSnapshot>

    let updateInterval: TimeInterval

    init(updateInterval: TimeInterval = 1.0, historyLimit: Int = 120) {
        let resolvedHistoryLimit = max(historyLimit, 1)

        self.updateInterval = updateInterval
        historyBuffer = FixedSizeRingBuffer(capacity: resolvedHistoryLimit)
        engine = SamplingEngine(updateInterval: updateInterval) { [weak self] snapshot in
            Task { @MainActor in
                self?.record(snapshot)
            }
        }
    }

    var recentSnapshots: [PerformanceSnapshot] {
        historyBuffer.values()
    }

    var cpuUsageHistory: [Double] {
        recentSnapshots.map(\.cpuUsage)
    }

    var memoryUsageHistory: [Double] {
        recentSnapshots.map(\.memoryUsage)
    }

    var diskUsageHistory: [Double] {
        recentSnapshots.map(\.diskUsage)
    }

    var thermalPressureHistory: [Double] {
        recentSnapshots.map { Self.thermalPressureValue(for: $0.thermalPressure) }
    }

    func start() {
        engine?.start()
    }

    func stop() {
        engine?.stop()
    }

    func resetHistory(keepingCurrentSnapshot: Bool = true) {
        let currentSnapshot = keepingCurrentSnapshot ? snapshot : nil

        historyBuffer.removeAll()
        snapshot = currentSnapshot

        if let currentSnapshot {
            historyBuffer.append(currentSnapshot)
        }
    }

    private func record(_ snapshot: PerformanceSnapshot) {
        self.snapshot = snapshot
        historyBuffer.append(snapshot)
    }

    private static func thermalPressureValue(for level: ThermalPressureLevel) -> Double {
        switch level {
        case .nominal:
            return 0.18
        case .fair:
            return 0.42
        case .serious:
            return 0.72
        case .critical:
            return 1
        case .unknown:
            return 0
        }
    }
}

private final class SamplingEngine: @unchecked Sendable {
    private let sampler = SystemMetricsSampler()
    private let queue = DispatchQueue(label: "com.starry.magicring.metrics", qos: .utility)
    private let updateInterval: TimeInterval
    private let onSnapshot: @Sendable (PerformanceSnapshot) -> Void

    private var timer: DispatchSourceTimer?

    init(
        updateInterval: TimeInterval,
        onSnapshot: @escaping @Sendable (PerformanceSnapshot) -> Void
    ) {
        self.updateInterval = max(updateInterval, 0.25)
        self.onSnapshot = onSnapshot
        start()
    }

    deinit {
        stop()
    }

    func start() {
        guard timer == nil else {
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        let interval = DispatchTimeInterval.milliseconds(Int(updateInterval * 1_000))
        let leeway = DispatchTimeInterval.milliseconds(Int(max(updateInterval * 0.15, 0.05) * 1_000))

        timer.schedule(deadline: .now(), repeating: interval, leeway: leeway)
        timer.setEventHandler { [weak self] in
            guard let self,
                  let snapshot = self.sampler.sample() else {
                return
            }

            self.onSnapshot(snapshot)
        }

        self.timer = timer
        timer.resume()
    }

    func stop() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }
}
