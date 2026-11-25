import Foundation
import CoreMotion

/// 真实的系统计步数据源（CMPedometer）。
/// 用来在你的 App 里做「模拟 / 真实」一键切换，互相印证。
public final class RealStepSource: StepSource {

    public var onSnapshot: ((StepSnapshot) -> Void)?
    public private(set) var isRunning = false

    public var isAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    private let pedometer = CMPedometer()
    private var previousSteps: Int = 0
    private var previousDistance: Double = 0

    public init() {}

    public func start() throws {
        guard isAvailable else { throw StepSourceError.notAvailable }
        guard !isRunning else { return }

        reset()
        let now = Date()
        isRunning = true

        pedometer.startUpdates(from: now) { [weak self] data, _ in
            guard let self, let data else { return }

            let steps = data.numberOfSteps.intValue
            let distance = data.distance?.doubleValue ?? 0
            let deltaSteps = max(0, steps - self.previousSteps)
            let deltaDistance = max(0, distance - self.previousDistance)
            self.previousSteps = steps
            self.previousDistance = distance

            // currentCadence 单位是「步/秒」
            let cadencePerSecond = data.currentCadence?.doubleValue ?? 0
            let cadence = cadencePerSecond > 0 ? cadencePerSecond * 60 : 0
            let stride = steps > 0 ? distance / Double(steps) : 0

            let snapshot = StepSnapshot(
                timestamp: Date(),
                steps: deltaSteps,
                cadence: cadence,
                strideMeters: stride,
                distanceMeters: deltaDistance,
                totalSteps: steps,
                totalDistanceMeters: distance
            )

            DispatchQueue.main.async {
                self.onSnapshot?(snapshot)
            }
        }
    }

    public func stop() {
        guard isRunning else { return }
        pedometer.stopUpdates()
        isRunning = false
    }

    public func reset() {
        previousSteps = 0
        previousDistance = 0
    }
}
