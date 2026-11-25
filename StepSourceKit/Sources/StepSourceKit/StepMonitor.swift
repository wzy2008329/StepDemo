import Foundation
import Combine

/// 把任意 StepSource 的流接成可直接绑到 SwiftUI 的状态。
@MainActor
public final class StepMonitor: ObservableObject {

    @Published public private(set) var latest: StepSnapshot?
    @Published public private(set) var totalSteps: Int = 0
    @Published public private(set) var totalDistanceMeters: Double = 0
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var sourceLabel: String = "未绑定"
    /// 最近一段时间的瞬时步频序列，用于画曲线
    @Published public private(set) var cadenceSeries: [Double] = []

    /// 原始采样记录，可用于导出 CSV 或写断言
    public private(set) var samples: [StepSnapshot] = []

    private var source: (any StepSource)?
    private let historyLimit: Int

    public init(historyLimit: Int = 120) {
        self.historyLimit = historyLimit
    }

    public func bind(_ source: any StepSource, label: String) {
        self.source = source
        self.sourceLabel = label
        source.onSnapshot = { [weak self] snapshot in
            Task { @MainActor in
                self?.ingest(snapshot)
            }
        }
    }

    public func unbind() {
        source?.onSnapshot = nil
        source = nil
        sourceLabel = "未绑定"
    }

    public func start() throws {
        guard let source else { return }
        try source.start()
        isRunning = true
    }

    public func stop() {
        source?.stop()
        isRunning = false
    }

    public func reset() {
        source?.reset()
        latest = nil
        totalSteps = 0
        totalDistanceMeters = 0
        cadenceSeries.removeAll()
        samples.removeAll()
    }

    private func ingest(_ snapshot: StepSnapshot) {
        latest = snapshot
        totalSteps = snapshot.totalSteps
        totalDistanceMeters = snapshot.totalDistanceMeters

        if snapshot.cadence > 0 {
            cadenceSeries.append(snapshot.cadence)
            if cadenceSeries.count > historyLimit {
                cadenceSeries.removeFirst(cadenceSeries.count - historyLimit)
            }
        }

        samples.append(snapshot)
    }
}
