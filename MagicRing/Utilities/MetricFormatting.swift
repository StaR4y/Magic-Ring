import Foundation

enum MetricFormatting {
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.isAdaptive = true
        return formatter
    }()

    private static let rateFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.isAdaptive = true
        return formatter
    }()

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    static func compactPercent(_ value: Double) -> String {
        let percentValue = max(value, 0) * 100
        if percentValue >= 10 {
            return "\(Int(percentValue.rounded()))%"
        }

        return String(format: "%.1f%%", percentValue)
    }

    static func bytes(_ value: UInt64) -> String {
        byteFormatter.string(fromByteCount: Int64(value))
    }

    static func bytesPerSecond(_ value: Double) -> String {
        "\(rateFormatter.string(fromByteCount: Int64(max(value, 0).rounded())))/s"
    }

    static func load(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
