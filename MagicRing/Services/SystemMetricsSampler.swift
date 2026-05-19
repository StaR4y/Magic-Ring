import Darwin
import Foundation

final class SystemMetricsSampler: @unchecked Sendable {
    private struct CPUTicks {
        let active: UInt64
        let total: UInt64
    }

    private let pageSize: UInt64
    private let totalMemoryBytes: UInt64
    private var previousCPUTicks: CPUTicks?

    init() {
        var resolvedPageSize: vm_size_t = vm_kernel_page_size
        if host_page_size(mach_host_self(), &resolvedPageSize) != KERN_SUCCESS {
            resolvedPageSize = vm_kernel_page_size
        }

        pageSize = UInt64(resolvedPageSize)
        totalMemoryBytes = max(ProcessInfo.processInfo.physicalMemory, Self.readPhysicalMemorySize())
    }

    func sample() -> PerformanceSnapshot? {
        guard let cpu = readCPUMetrics(),
              let memory = readMemoryMetrics(),
              let disk = readDiskMetrics() else {
            return nil
        }

        return PerformanceSnapshot(
            cpu: cpu,
            memory: memory,
            disk: disk,
            thermalPressure: readThermalPressure(),
            timestamp: .now
        )
    }

    private func readCPUMetrics() -> CPUMetrics? {
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0
        var cpuCount: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &cpuInfo,
            &cpuInfoCount
        )

        guard result == KERN_SUCCESS, let cpuInfo else {
            return nil
        }

        defer {
            let size = Int(cpuInfoCount) * MemoryLayout<integer_t>.stride
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(size))
        }

        let stride = Int(CPU_STATE_MAX)
        let info = UnsafeBufferPointer(start: cpuInfo, count: Int(cpuInfoCount))

        var activeTicks: UInt64 = 0
        var totalTicks: UInt64 = 0

        for cpuIndex in 0..<Int(cpuCount) {
            let offset = cpuIndex * stride
            let user = UInt64(info[offset + Int(CPU_STATE_USER)])
            let system = UInt64(info[offset + Int(CPU_STATE_SYSTEM)])
            let idle = UInt64(info[offset + Int(CPU_STATE_IDLE)])
            let nice = UInt64(info[offset + Int(CPU_STATE_NICE)])

            activeTicks += user + system + nice
            totalTicks += user + system + nice + idle
        }

        let currentTicks = CPUTicks(active: activeTicks, total: totalTicks)
        let usage = cpuUsage(from: currentTicks)
        let loadAverage = readLoadAverage()

        return CPUMetrics(
            usage: usage,
            loadAverage1m: loadAverage.0,
            loadAverage5m: loadAverage.1,
            loadAverage15m: loadAverage.2
        )
    }

    private func cpuUsage(from currentTicks: CPUTicks) -> Double {
        defer { previousCPUTicks = currentTicks }

        guard let previousCPUTicks else {
            guard currentTicks.total > 0 else {
                return 0
            }

            return clamp(Double(currentTicks.active) / Double(currentTicks.total))
        }

        let activeDelta = currentTicks.active &- previousCPUTicks.active
        let totalDelta = currentTicks.total &- previousCPUTicks.total
        guard totalDelta > 0 else {
            return 0
        }

        return clamp(Double(activeDelta) / Double(totalDelta))
    }

    private func readMemoryMetrics() -> MemoryMetrics? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        let activeBytes = UInt64(stats.active_count) * pageSize
        let wiredBytes = UInt64(stats.wire_count) * pageSize
        let compressedBytes = UInt64(stats.compressor_page_count) * pageSize
        let inactiveBytes = UInt64(stats.inactive_count) * pageSize
        let freeBytes = UInt64(stats.free_count) * pageSize

        let usedBytes = min(activeBytes + wiredBytes + compressedBytes, totalMemoryBytes)
        let availableBytes = min(freeBytes + inactiveBytes, totalMemoryBytes)
        let swapUsage = readSwapUsage()

        return MemoryMetrics(
            usedBytes: usedBytes,
            availableBytes: availableBytes,
            freeBytes: freeBytes,
            inactiveBytes: inactiveBytes,
            wiredBytes: wiredBytes,
            compressedBytes: compressedBytes,
            totalBytes: totalMemoryBytes,
            swapUsedBytes: swapUsage.usedBytes,
            swapTotalBytes: swapUsage.totalBytes
        )
    }

    private func readDiskMetrics() -> DiskMetrics? {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let freeSpace = attributes[.systemFreeSize] as? NSNumber,
              let totalSpace = attributes[.systemSize] as? NSNumber else {
            return nil
        }

        let availableBytes = freeSpace.uint64Value
        let totalBytes = totalSpace.uint64Value
        let usedBytes = totalBytes > availableBytes ? totalBytes - availableBytes : 0

        return DiskMetrics(
            usedBytes: usedBytes,
            availableBytes: availableBytes,
            totalBytes: totalBytes
        )
    }

    private func readLoadAverage() -> (Double, Double, Double) {
        var values = [Double](repeating: 0, count: 3)
        let resolvedCount = values.withUnsafeMutableBufferPointer { buffer in
            getloadavg(buffer.baseAddress, Int32(buffer.count))
        }

        guard resolvedCount == Int32(values.count) else {
            return (0, 0, 0)
        }

        return (values[0], values[1], values[2])
    }

    private func readSwapUsage() -> (usedBytes: UInt64, totalBytes: UInt64) {
        var swapUsage = xsw_usage()
        var length = MemoryLayout.size(ofValue: swapUsage)

        let result = sysctlbyname("vm.swapusage", &swapUsage, &length, nil, 0)
        guard result == 0 else {
            return (0, 0)
        }

        return (UInt64(swapUsage.xsu_used), UInt64(swapUsage.xsu_total))
    }

    private func readThermalPressure() -> ThermalPressureLevel {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return .nominal
        case .fair:
            return .fair
        case .serious:
            return .serious
        case .critical:
            return .critical
        @unknown default:
            return .unknown
        }
    }

    private static func readPhysicalMemorySize() -> UInt64 {
        var value: UInt64 = 0
        var length = MemoryLayout<UInt64>.size

        let result = sysctlbyname("hw.memsize", &value, &length, nil, 0)
        return result == 0 ? value : 0
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
