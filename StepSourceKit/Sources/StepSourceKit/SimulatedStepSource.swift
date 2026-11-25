import Foundation

/// 纯软件模拟的计步数据源。
/// 数据只在内存里生成，不写健康、不出设备，跑完即弃。
public final class SimulatedStepSource: StepSource {

    public struct Config: Sendable {
        /// 目标步频（步/分钟）
        public var cadence: Double
        /// 步幅（米/步）
        public var strideMeters: Double
        /// 步频随机抖动幅度（百分比）。0 = 完全均匀，接近真实行走建议 5–10
        public var jitterPercent: Double
        /// 采样间隔（秒）
        public var tickInterval: TimeInterval
        /// 达到该步数后自动停止，nil = 一直跑
        public var targetSteps: Int?

        public init(
            cadence: Double = 110,
            strideMeters: Double = 0.70,
            jitterPercent: Double = 8,
            tickInterval: TimeInterval = 0.5,
            targetSteps: Int? = nil
        ) {
            self.cadence = cadence
            self.strideMeters = strideMeters
            self.jitterPercent = jitterPercent
            self.tickInterval = tickInterval
            self.targetSteps = targetSteps
        }
    }

    public var config: Config
    public var onSnapshot: ((StepSnapshot) -> Void)?
    public private(set) var isRunning = false
    public var isAvailable: Bool { true }

    private var timer: DispatchSourceTimer?
    private var generator: SeededGenerator
    private var pendingSteps: Double = 0
    private var lastTick: Date?
    private var totalSteps: Int = 0
    private var totalDistance: Double = 0

    private let queue = DispatchQueue(label: "step.sourcekit.simulated", qos: .userInitiated)

    /// - Parameter seed: 随机种子。同一种子 + 同一配置 = 完全可复现的数据流，方便写自动化测试。
    public init(config: Config = Config(), seed: UInt64 = 20_261_123) {
        self.config = config
        self.generator = SeededGenerator(seed: seed)
    }

    public func start() throws {
        guard !isRunning else { return }
        reset()
        isRunning = true
        lastTick = Date()

        let interval = max(0.1, config.tickInterval)
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(40))
        t.setEventHandler { [weak self] in
            self?.tick()
        }
        t.resume()
        timer = t
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        timer?.cancel()
        timer = nil
        lastTick = nil
        pendingSteps = 0
    }

    public func reset() {
        totalSteps = 0
        totalDistance = 0
        pendingSteps = 0
        lastTick = Date()
    }

    // MARK: - 生成

    private func tick() {
        guard isRunning else { return }
        let now = Date()
        defer { lastTick = now }
        guard let last = lastTick else { return }

        // 上限 3 秒，避免计时器被系统压制后一次性补出大量步数
        let delta = max(0, min(now.timeIntervalSince(last), 3.0))

        let base = config.cadence
        let jitter: Double
        if config.jitterPercent > 0 {
            jitter = base * (config.jitterPercent / 100) * (generator.nextUnit() * 2 - 1)
        } else {
            jitter = 0
        }
        let cadenceNow = max(0, base + jitter)

        pendingSteps += cadenceNow / 60 * delta
        let whole = floor(pendingSteps)
        if whole >= 1 {
            pendingSteps -= whole
        }

        let steps = Int(whole)
        totalSteps += steps
        let strideNow = config.strideMeters
        let distance = Double(steps) * strideNow
        totalDistance += distance

        let snapshot = StepSnapshot(
            timestamp: now,
            steps: steps,
            cadence: cadenceNow,
            strideMeters: strideNow,
            distanceMeters: distance,
            totalSteps: totalSteps,
            totalDistanceMeters: totalDistance
        )

        let reachedTarget = config.targetSteps.map { totalSteps >= $0 } ?? false

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onSnapshot?(snapshot)
            if reachedTarget {
                self.stop()
            }
        }
    }
}

/// 确定性伪随机数（xorshift64），保证同一 seed 的数据流可复现
struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func nextUnit() -> Double {
        Double(next() % 1_000_000) / 1_000_000.0
    }
}
