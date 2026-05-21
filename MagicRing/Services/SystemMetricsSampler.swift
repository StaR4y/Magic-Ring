import Darwin
import Foundation
import IOKit.ps

final class SystemMetricsSampler: @unchecked Sendable {
    private struct CPUTicks {
        let user: UInt64
        let system: UInt64
        let nice: UInt64
        let idle: UInt64

        let active: UInt64
        let total: UInt64
    }

    private struct NetworkCounters {
        let bytesIn: UInt64
        let bytesOut: UInt64
        let timestamp: Date
        let interfaceName: String
        let localAddress: String?
    }

    private struct ProcessCounters {
        let cpuTimeNanoseconds: UInt64
        let timestamp: Date
    }

    private let pageSize: UInt64
    private let totalMemoryBytes: UInt64
    private var previousCPUTicks: CPUTicks?
    private var previousNetworkCounters: NetworkCounters?
    private var previousProcessCounters: [Int32: ProcessCounters] = [:]

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

        let timestamp = Date()
        return PerformanceSnapshot(
            cpu: cpu,
            memory: memory,
            disk: disk,
            battery: readBatteryMetrics(),
            network: readNetworkMetrics(),
            processes: readProcessMetrics(timestamp: timestamp),
            thermalPressure: readThermalPressure(),
            timestamp: timestamp
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

        var userTicks: UInt64 = 0
        var systemTicks: UInt64 = 0
        var niceTicks: UInt64 = 0
        var idleTicks: UInt64 = 0

        for cpuIndex in 0..<Int(cpuCount) {
            let offset = cpuIndex * stride
            let user = UInt64(info[offset + Int(CPU_STATE_USER)])
            let system = UInt64(info[offset + Int(CPU_STATE_SYSTEM)])
            let idle = UInt64(info[offset + Int(CPU_STATE_IDLE)])
            let nice = UInt64(info[offset + Int(CPU_STATE_NICE)])

            userTicks += user
            systemTicks += system
            niceTicks += nice
            idleTicks += idle
        }

        let activeTicks = userTicks + systemTicks + niceTicks
        let totalTicks = activeTicks + idleTicks
        let currentTicks = CPUTicks(
            user: userTicks,
            system: systemTicks,
            nice: niceTicks,
            idle: idleTicks,
            active: activeTicks,
            total: totalTicks
        )
        let usageBreakdown = cpuUsageBreakdown(from: currentTicks)
        let loadAverage = readLoadAverage()

        return CPUMetrics(
            usage: usageBreakdown.active,
            userUsage: usageBreakdown.user,
            systemUsage: usageBreakdown.system,
            idleUsage: usageBreakdown.idle,
            loadAverage1m: loadAverage.0,
            loadAverage5m: loadAverage.1,
            loadAverage15m: loadAverage.2
        )
    }

    private func cpuUsageBreakdown(from currentTicks: CPUTicks) -> (active: Double, user: Double, system: Double, idle: Double) {
        defer { previousCPUTicks = currentTicks }

        guard let previousCPUTicks else {
            guard currentTicks.total > 0 else {
                return (0, 0, 0, 0)
            }

            return (
                clamp(Double(currentTicks.active) / Double(currentTicks.total)),
                clamp(Double(currentTicks.user + currentTicks.nice) / Double(currentTicks.total)),
                clamp(Double(currentTicks.system) / Double(currentTicks.total)),
                clamp(Double(currentTicks.idle) / Double(currentTicks.total))
            )
        }

        let activeDelta = currentTicks.active &- previousCPUTicks.active
        let userDelta = (currentTicks.user &- previousCPUTicks.user) + (currentTicks.nice &- previousCPUTicks.nice)
        let systemDelta = currentTicks.system &- previousCPUTicks.system
        let idleDelta = currentTicks.idle &- previousCPUTicks.idle
        let totalDelta = currentTicks.total &- previousCPUTicks.total
        guard totalDelta > 0 else {
            return (0, 0, 0, 0)
        }

        return (
            clamp(Double(activeDelta) / Double(totalDelta)),
            clamp(Double(userDelta) / Double(totalDelta)),
            clamp(Double(systemDelta) / Double(totalDelta)),
            clamp(Double(idleDelta) / Double(totalDelta))
        )
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

    private func readBatteryMetrics() -> BatteryMetrics {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as NSDictionary? else {
            return BatteryMetrics(level: nil, isCharging: false, timeRemainingSeconds: nil)
        }

        let currentCapacity = numberValue(description, key: kIOPSCurrentCapacityKey)
        let maximumCapacity = numberValue(description, key: kIOPSMaxCapacityKey)
        let level = maximumCapacity > 0 ? clamp(currentCapacity / maximumCapacity) : nil
        let isCharging = (description[kIOPSIsChargingKey] as? NSNumber)?.boolValue ?? false
        let timeKey = isCharging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
        let remainingMinutes = numberValue(description, key: timeKey)
        let remainingSeconds = remainingMinutes > 0 ? remainingMinutes * 60 : nil

        return BatteryMetrics(
            level: level,
            isCharging: isCharging,
            timeRemainingSeconds: remainingSeconds
        )
    }

    private func readNetworkMetrics() -> NetworkMetrics {
        let counters = readNetworkCounters()
        defer { previousNetworkCounters = counters }

        guard let previousNetworkCounters else {
            return NetworkMetrics(
                interfaceName: counters.interfaceName,
                localAddress: counters.localAddress,
                bytesInPerSecond: 0,
                bytesOutPerSecond: 0
            )
        }

        let interval = counters.timestamp.timeIntervalSince(previousNetworkCounters.timestamp)
        guard interval > 0 else {
            return NetworkMetrics(
                interfaceName: counters.interfaceName,
                localAddress: counters.localAddress,
                bytesInPerSecond: 0,
                bytesOutPerSecond: 0
            )
        }

        let bytesInDelta = counters.bytesIn >= previousNetworkCounters.bytesIn ? counters.bytesIn - previousNetworkCounters.bytesIn : 0
        let bytesOutDelta = counters.bytesOut >= previousNetworkCounters.bytesOut ? counters.bytesOut - previousNetworkCounters.bytesOut : 0

        return NetworkMetrics(
            interfaceName: counters.interfaceName,
            localAddress: counters.localAddress,
            bytesInPerSecond: Double(bytesInDelta) / interval,
            bytesOutPerSecond: Double(bytesOutDelta) / interval
        )
    }

    private func readNetworkCounters() -> NetworkCounters {
        var firstAddress: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&firstAddress) == 0, let firstAddress else {
            return NetworkCounters(bytesIn: 0, bytesOut: 0, timestamp: .now, interfaceName: "--", localAddress: nil)
        }

        defer {
            freeifaddrs(firstAddress)
        }

        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        var preferredInterface: String?
        var localAddresses: [String: String] = [:]
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddress

        while let current = cursor {
            let interface = current.pointee
            cursor = interface.ifa_next

            guard let namePointer = interface.ifa_name,
                  let address = interface.ifa_addr else {
                continue
            }

            let name = String(cString: namePointer)
            guard isReadableNetworkInterface(name, flags: interface.ifa_flags) else {
                continue
            }

            switch Int32(address.pointee.sa_family) {
            case AF_LINK:
                guard let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self).pointee else {
                    continue
                }

                bytesIn += UInt64(data.ifi_ibytes)
                bytesOut += UInt64(data.ifi_obytes)
                preferredInterface = preferredInterface ?? name
            case AF_INET:
                guard let addressString = networkAddressString(from: UnsafePointer(address)) else {
                    continue
                }

                localAddresses[name] = addressString
                if preferredInterface == nil || name == "en0" {
                    preferredInterface = name
                }
            default:
                continue
            }
        }

        let interfaceName = preferredInterface ?? localAddresses.keys.sorted().first ?? "--"
        return NetworkCounters(
            bytesIn: bytesIn,
            bytesOut: bytesOut,
            timestamp: .now,
            interfaceName: interfaceName,
            localAddress: localAddresses[interfaceName]
        )
    }

    private func readProcessMetrics(timestamp: Date) -> [ProcessMetrics] {
        let pidBufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard pidBufferSize > 0 else {
            previousProcessCounters.removeAll(keepingCapacity: true)
            return []
        }

        var pids = [pid_t](repeating: 0, count: Int(pidBufferSize) / MemoryLayout<pid_t>.stride)
        let resolvedBufferSize = pids.withUnsafeMutableBufferPointer { buffer in
            proc_listpids(
                UInt32(PROC_ALL_PIDS),
                0,
                buffer.baseAddress,
                Int32(buffer.count * MemoryLayout<pid_t>.stride)
            )
        }
        let resolvedCount = max(0, min(pids.count, Int(resolvedBufferSize) / MemoryLayout<pid_t>.stride))

        var counters: [Int32: ProcessCounters] = [:]
        counters.reserveCapacity(resolvedCount)
        var metrics: [ProcessMetrics] = []
        metrics.reserveCapacity(min(resolvedCount, 128))

        for pid in pids.prefix(resolvedCount) where pid > 0 {
            guard let taskInfo = processTaskInfo(for: pid),
                  let processName = processName(for: pid) else {
                continue
            }

            let cpuTime = taskInfo.pti_total_user + taskInfo.pti_total_system
            let previous = previousProcessCounters[Int32(pid)]
            let cpuUsage = processCPUUsage(currentCPUTime: cpuTime, previous: previous, timestamp: timestamp)
            counters[Int32(pid)] = ProcessCounters(cpuTimeNanoseconds: cpuTime, timestamp: timestamp)

            let memoryBytes = UInt64(taskInfo.pti_resident_size)
            guard memoryBytes > 0 || cpuUsage > 0 else {
                continue
            }

            metrics.append(
                ProcessMetrics(
                    pid: Int32(pid),
                    name: processName,
                    cpuUsage: cpuUsage,
                    memoryBytes: memoryBytes
                )
            )
        }

        previousProcessCounters = counters

        let topCPU = metrics
            .sorted { lhs, rhs in
                lhs.cpuUsage == rhs.cpuUsage ? lhs.memoryBytes > rhs.memoryBytes : lhs.cpuUsage > rhs.cpuUsage
            }
            .prefix(8)
        let topMemory = metrics
            .sorted { lhs, rhs in
                lhs.memoryBytes == rhs.memoryBytes ? lhs.cpuUsage > rhs.cpuUsage : lhs.memoryBytes > rhs.memoryBytes
            }
            .prefix(8)

        var seenPids = Set<Int32>()
        return (topCPU + topMemory).compactMap { metric in
            guard seenPids.insert(metric.pid).inserted else {
                return nil
            }

            return metric
        }
    }

    private func processTaskInfo(for pid: pid_t) -> proc_taskinfo? {
        var taskInfo = proc_taskinfo()
        let expectedSize = Int32(MemoryLayout<proc_taskinfo>.stride)
        let result = withUnsafeMutablePointer(to: &taskInfo) { pointer in
            proc_pidinfo(pid, PROC_PIDTASKINFO, 0, pointer, expectedSize)
        }

        return result == expectedSize ? taskInfo : nil
    }

    private func processName(for pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = buffer.withUnsafeMutableBufferPointer { pointer in
            proc_name(pid, pointer.baseAddress, UInt32(pointer.count))
        }

        guard length > 0 else {
            return nil
        }

        let name = String(cString: buffer)
        return name.isEmpty ? nil : name
    }

    private func processCPUUsage(currentCPUTime: UInt64, previous: ProcessCounters?, timestamp: Date) -> Double {
        guard let previous else {
            return 0
        }

        let elapsed = timestamp.timeIntervalSince(previous.timestamp)
        guard elapsed > 0, currentCPUTime >= previous.cpuTimeNanoseconds else {
            return 0
        }

        let cpuTimeDelta = currentCPUTime - previous.cpuTimeNanoseconds
        return max(Double(cpuTimeDelta) / 1_000_000_000 / elapsed, 0)
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

    private func numberValue(_ dictionary: NSDictionary, key: String) -> Double {
        (dictionary[key] as? NSNumber)?.doubleValue ?? 0
    }

    private func isReadableNetworkInterface(_ name: String, flags: UInt32) -> Bool {
        let blockedPrefixes = ["lo", "awdl", "llw", "utun", "gif", "stf", "ap", "p2p"]
        guard !blockedPrefixes.contains(where: { name.hasPrefix($0) }) else {
            return false
        }

        return (flags & UInt32(IFF_UP)) != 0
    }

    private func networkAddressString(from address: UnsafePointer<sockaddr>) -> String? {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            address,
            socklen_t(address.pointee.sa_len),
            &hostname,
            socklen_t(hostname.count),
            nil,
            0,
            NI_NUMERICHOST
        )

        guard result == 0 else {
            return nil
        }

        return String(cString: hostname)
    }
}
