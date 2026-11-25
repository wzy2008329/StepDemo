import Foundation

/// 一次采样区间的数据快照。
/// 无论数据来自真实传感器还是模拟器，下游拿到的都是同一种结构，
/// 所以你的 App 只需要换数据源，不用改业务代码。
public struct StepSnapshot: Sendable, Identifiable {
    public let id = UUID()

    /// 采样时间
    public let timestamp: Date
    /// 本区间新增步数
    public let steps: Int
    /// 本区间瞬时步频（步/分钟）
    public let cadence: Double
    /// 步幅（米/步）
    public let strideMeters: Double
    /// 本区间新增距离（米）
    public let distanceMeters: Double
    /// 会话累计步数
    public let totalSteps: Int
    /// 会话累计距离（米）
    public let totalDistanceMeters: Double

    public init(
        timestamp: Date,
        steps: Int,
        cadence: Double,
        strideMeters: Double,
        distanceMeters: Double,
        totalSteps: Int,
        totalDistanceMeters: Double
    ) {
        self.timestamp = timestamp
        self.steps = steps
        self.cadence = cadence
        self.strideMeters = strideMeters
        self.distanceMeters = distanceMeters
        self.totalSteps = totalSteps
        self.totalDistanceMeters = totalDistanceMeters
    }

    /// 瞬时速度（米/秒）= 步频 × 步幅 ÷ 60
    public var speedMetersPerSecond: Double {
        cadence * strideMeters / 60
    }

    /// 瞬时速度（km/h）
    public var speedKmh: Double {
        speedMetersPerSecond * 3.6
    }

    /// 配速（秒/公里），速度过低时返回 nil
    public var paceSecondsPerKm: Double? {
        guard speedMetersPerSecond > 0.05 else { return nil }
        return 1000 / speedMetersPerSecond
    }

    /// 配速文本，如 5'30"
    public var paceText: String {
        guard let pace = paceSecondsPerKm else { return "--" }
        let total = Int(pace.rounded())
        return String(format: "%d'%02d\"", total / 60, total % 60)
    }
}
