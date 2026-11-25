# 虚拟计步源 StepSourceKit

给你自己写的 App 用的**软件级计步数据源**：步频、步幅、距离、配速全部在 App 内存里算出来，**不申请健康权限、不写 HealthKit、不出设备**，退出即消失。跟上一版写健康库的方案相比，它不占用、也不污染你任何一条真实运动记录。

## 目录结构

```
StepSourceDemo/
├── project.yml                 # XcodeGen 工程描述（可选）
├── README.md
├── StepSourceKit/              # 可复用的 Swift Package
│   ├── Package.swift
│   └── Sources/StepSourceKit/
│       ├── StepSnapshot.swift      # 统一数据快照（步数/步频/步幅/距离/配速）
│       ├── StepSource.swift        # 数据源协议
│       ├── SimulatedStepSource.swift  # 软件模拟源（本项目核心）
│       ├── RealStepSource.swift    # 真实 CMPedometer 源
│       ├── StepMonitor.swift       # 绑 SwiftUI 的状态层
│       └── CSVExporter.swift       # 导出 CSV，便于回放/断言
└── DemoApp/                    # 演示 App（一个仪表盘）
    ├── StepDemoApp.swift
    ├── DemoContentView.swift
    └── Info.plist
```

## 为什么这套「不占你的记录」

| | 写健康库的方案 | 本方案 |
|---|---|---|
| 数据落在哪 | 系统共享健康库，所有 App 都能读 | 你的 App 进程内存 |
| 和真实记录的关系 | 叠加，混在一起 | 完全无关 |
| 清理 | 只能一条条删，删不干净 | 退出 App 自动消失 |
| 需要的权限 | 健康读写授权 | 模拟模式下零权限 |
| 开发者账号 | HealthKit 能力需付费账号 | 免费 Apple ID 即可 |

## 编译（Mac + Xcode，免费账号就够）

模拟模式只用到 CoreMotion 的框架导入，不申请任何能力，**免费 Apple ID 的个人签名就能装到那台旧 iPhone 上**，不用 99 美元。

### 路线 1：XcodeGen

```bash
brew install xcodegen
cd StepSourceDemo
xcodegen generate
open StepDemo.xcodeproj
```

### 路线 2：手动（不用装 XcodeGen）

1. Xcode → New → Project → iOS App，名字 `StepDemo`，SwiftUI + Swift。
2. **File → Add Package Dependencies → Add Local…** → 选中 `StepSourceKit` 文件夹 → 添加 `StepSourceKit` 库。
3. 删掉自动生成的 ContentView.swift / xxxApp.swift，把 `DemoApp/` 里两个 swift 拖进工程。
4. Target → Info 加一行：`NSMotionUsageDescription` = `切换到「本机传感器」时读取系统计步数据，用于和模拟数据进行对照。`（切真实源必需，只用模拟可以不弹权限）
5. Target → Signing：Team 选免费 Apple ID，Bundle Identifier 改成唯一值。
6. 选那台旧 iPhone 运行。免费签名有效期 7 天，到期重新 ⌘R 即可。

## 怎么用

跑起来后：选「软件模拟」→ 拖步频/步幅滑块（或点散步/快走/慢跑/竞速预设）→ 点开始。顶部实时出 km/h、步频、步幅、配速、累计步数和距离，下方是瞬时步频曲线。切到「本机传感器」就换成真实 CMPedometer，走两步能对照两者差异。

- 步频 90–130、步幅 0.6–0.8 米 ≈ 走路
- 步频 160–190、步幅 1.0–1.3 米 ≈ 跑步
- 步频抖动 0 = 机器般均匀，5–10 更像真人
- 「导出 CSV」把每次采样（时间戳、步数、步频、步幅、距离、速度）存成文件，方便做数据回放和断言

## 接进你自己的 App（三行）

```swift
import StepSourceKit

let monitor = StepMonitor()
let source: any StepSource = isDebug
    ? SimulatedStepSource(config: .init(cadence: 120, strideMeters: 0.78, jitterPercent: 8))
    : RealStepSource()

monitor.bind(source, label: isDebug ? "模拟" : "真实")
try monitor.start()
```

`StepMonitor` 是 `ObservableObject`，直接 `@StateObject var monitor = StepMonitor()` 绑到界面；`monitor.latest` 就是当前快照，`monitor.cadenceSeries` 可以直接画图。

如果你现在是用 `CMPedometer.startUpdates(from:withHandler:)` 自己接的，迁移方式：

| 原来 | 现在 |
|---|---|
| `pedometer.startUpdates(...)` 里解析 `CMPedometerData` | 交给 `RealStepSource` 输出 `StepSnapshot` |
| 自己算 `distance / steps` 得步幅 | 快照里直接有 `strideMeters` |
| 自己算速度、配速 | `speedKmh`、`paceSecondsPerKm`、`paceText` |
| 想造数据只能真走路 | 换 `SimulatedStepSource`，步频步幅随便调 |

## 可复现，方便写测试

`SimulatedStepSource(config:seed:)` 用确定性伪随机（xorshift64）。同 seed + 同配置 = 完全一样的数据流，单元测试里可以让它跑 60 秒固定 120 步/分，然后断言你的统计逻辑约等于 120 步。

## 常见的几个点

- **模拟器上「本机传感器」显示不可用**是正常的，CMPedometer 在模拟器里没数据；模拟源在模拟器上照跑，而且模拟器连签名都不用，最适合快速看界面。
- 和写健康库的方案一样，App 切后台/锁屏后计时器会被系统挂起，模拟停止。但这套本来就不需要长时间后台跑，重新点开始即可接着累加。
- 这套工具只解决「数据怎么产生」。如果你的 App 拿到数据后自己又写进健康库，污染问题会以你 App 的名义回来——那属于被测 App 自身行为，别在这个演示工程里开。
- 想让微信运动、支付宝这类第三方 App 读到，就绕不开写健康库；那种场景只能靠「独立旧 iPhone + 独立 Apple ID」把健康库整体隔开，不要用主力机。
