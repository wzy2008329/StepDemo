import Foundation

public enum StepSourceError: LocalizedError {
    case notAvailable

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "当前设备不支持计步（CMPedometer 不可用，模拟器上属正常现象）"
        }
    }
}

/// 数据源抽象。你的 App 只跟这个协议打交道，
/// 真实传感器和模拟器可以随时互换，切换只需一行。
public protocol StepSource: AnyObject {
    /// 当前环境是否可用（模拟源永远为 true）
    var isAvailable: Bool { get }
    /// 是否正在输出数据
    var isRunning: Bool { get }
    /// 数据回调，约定在主线程触发
    var onSnapshot: ((StepSnapshot) -> Void)? { get set }

    func start() throws
    func stop()
    /// 清空会话累计，不动配置
    func reset()
}
