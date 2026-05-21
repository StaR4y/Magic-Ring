import Foundation

struct CPUMetrics: Sendable {
    let usage: Double
    let userUsage: Double
    let systemUsage: Double
    let idleUsage: Double
    let loadAverage1m: Double
    let loadAverage5m: Double
    let loadAverage15m: Double
}

struct MemoryMetrics: Sendable {
    let usedBytes: UInt64
    let availableBytes: UInt64
    let freeBytes: UInt64
    let inactiveBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let totalBytes: UInt64
    let swapUsedBytes: UInt64
    let swapTotalBytes: UInt64

    var usage: Double {
        guard totalBytes > 0 else {
            return 0
        }

        return Double(usedBytes) / Double(totalBytes)
    }

    var swapUsage: Double {
        guard swapTotalBytes > 0 else {
            return 0
        }

        return Double(swapUsedBytes) / Double(swapTotalBytes)
    }
}

struct DiskMetrics: Sendable {
    let usedBytes: UInt64
    let availableBytes: UInt64
    let totalBytes: UInt64

    var usage: Double {
        guard totalBytes > 0 else {
            return 0
        }

        return Double(usedBytes) / Double(totalBytes)
    }

    var unusedRatio: Double {
        guard totalBytes > 0 else {
            return 0
        }

        return Double(availableBytes) / Double(totalBytes)
    }
}

struct BatteryMetrics: Sendable {
    let level: Double?
    let isCharging: Bool
    let timeRemainingSeconds: TimeInterval?

    var isAvailable: Bool {
        level != nil
    }
}

struct NetworkMetrics: Sendable {
    let interfaceName: String
    let localAddress: String?
    let bytesInPerSecond: Double
    let bytesOutPerSecond: Double
}

struct ProcessMetrics: Identifiable, Sendable {
    let pid: Int32
    let name: String
    let cpuUsage: Double
    let memoryBytes: UInt64

    var id: Int32 {
        pid
    }
}

enum ThermalPressureLevel: String, Sendable {
    case nominal
    case fair
    case serious
    case critical
    case unknown
}

struct PerformanceSnapshot: Sendable {
    let cpu: CPUMetrics
    let memory: MemoryMetrics
    let disk: DiskMetrics
    let battery: BatteryMetrics
    let network: NetworkMetrics
    let processes: [ProcessMetrics]
    let thermalPressure: ThermalPressureLevel
    let timestamp: Date

    var cpuUsage: Double { cpu.usage }
    var memoryUsage: Double { memory.usage }
    var diskUsage: Double { disk.usage }
    var diskUnusedRatio: Double { disk.unusedRatio }
}
