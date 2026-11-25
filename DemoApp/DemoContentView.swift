import SwiftUI
import StepSourceKit

struct DemoContentView: View {
    @StateObject private var monitor = StepMonitor()

    @State private var simulator = SimulatedStepSource(config: .init())
    private let realSource = RealStepSource()

    @State private var usesRealDevice = false
    @State private var cadence: Double = 110
    @State private var stride: Double = 0.70
    @State private var jitter: Double = 8.0

    @State private var exportFile: ExportFile?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                    chartCard
                    sourceCard
                    if !usesRealDevice {
                        presetRow
                        paramCard
                    }
                    controlRow
                    noteCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("虚拟计步源")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                configureSource()
            }
            .onChange(of: usesRealDevice) { _ in
                monitor.stop()
                monitor.reset()
                configureSource()
            }
            .onChange(of: cadence) { newValue in
                simulator.config.cadence = newValue
            }
            .onChange(of: stride) { newValue in
                simulator.config.strideMeters = newValue
            }
            .onChange(of: jitter) { newValue in
                simulator.config.jitterPercent = newValue
            }
            .sheet(item: $exportFile) { file in
                VStack(spacing: 20) {
                    Text("本次采样 \(monitor.samples.count) 条")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ShareLink(item: file.url) {
                        Label("分享 CSV 文件", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .presentationDetents([.height(220)])
            }
        }
    }

    // MARK: - 状态

    private var statusCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(monitor.isRunning ? Color.green : Color.secondary.opacity(0.5))
                    .frame(width: 9, height: 9)
                Text("\(monitor.isRunning ? "运行中" : "已停止") · \(monitor.sourceLabel)")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if usesRealDevice && !realSource.isAvailable {
                    Text("本机计步不可用")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.2f", monitor.latest?.speedKmh ?? 0))
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("km/h")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                metric("步频", String(format: "%.0f", monitor.latest?.cadence ?? 0), "步/分")
                Divider().frame(height: 32)
                metric("步幅", String(format: "%.2f", monitor.latest?.strideMeters ?? 0), "米")
                Divider().frame(height: 32)
                metric("配速", monitor.latest?.paceText ?? "--", "/km")
            }

            HStack(spacing: 0) {
                metric("累计步数", "\(monitor.totalSteps)", "步")
                Divider().frame(height: 32)
                metric("累计距离", String(format: "%.0f", monitor.totalDistanceMeters), "米")
                Divider().frame(height: 32)
                metric("采样条数", "\(monitor.samples.count)", "条")
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func metric(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text("\(title)（\(unit)）")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 曲线

    private var chartCard: some View {
        let series = monitor.cadenceSeries
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("瞬时步频曲线")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("最近 \(series.count) 个采样点")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SparkLine(values: series)
                .stroke(Color.accentColor, lineWidth: 2)
                .frame(height: 110)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    if series.count < 2 {
                        Text("开始后这里会出现曲线")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 数据源

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("数据源", systemImage: "arrow.triangle.swap")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
            Picker("数据源", selection: $usesRealDevice) {
                Text("软件模拟").tag(false)
                Text("本机传感器").tag(true)
            }
            .pickerStyle(.segmented)
            .disabled(monitor.isRunning)

            Text(usesRealDevice
                 ? "读 CMPedometer，用真机走两步就能看到步频变化。"
                 : "纯内存生成，不写健康、不出设备，步频步幅完全由你控制。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 预设

    private var presetRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("常用组合")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                preset("散步", 85, 0.62)
                preset("快走", 120, 0.75)
                preset("慢跑", 160, 1.00)
                preset("竞速", 185, 1.25)
            }
        }
    }

    private func preset(_ name: String, _ cadenceValue: Double, _ strideValue: Double) -> some View {
        Button {
            cadence = cadenceValue
            stride = strideValue
            simulator.config.cadence = cadenceValue
            simulator.config.strideMeters = strideValue
        } label: {
            VStack(spacing: 2) {
                Text(name).font(.subheadline.weight(.medium))
                Text("\(Int(cadenceValue)) · \(String(format: "%.2f", strideValue))m")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .disabled(monitor.isRunning)
    }

    // MARK: - 参数

    private var paramCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("步频").font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(Int(cadence)) 步/分")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $cadence, in: 40...240, step: 5)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("步幅").font(.subheadline.weight(.medium))
                    Spacer()
                    Text(String(format: "%.2f 米（%.0f 厘米）", stride, stride * 100))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $stride, in: 0.30...1.70, step: 0.05)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("步频抖动").font(.subheadline.weight(.medium))
                    Spacer()
                    Text(String(format: "± %.0f %%", jitter))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $jitter, in: 0...20, step: 1)
                Text("0 是完全均匀的机器步频；5–10 更接近真人走路。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(String(format: "推算速度 %.2f km/h，跑完 1 公里约需 %.0f 步",
                        cadence * stride / 60 * 3.6,
                        1000 / max(stride, 0.01)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 控制

    private var controlRow: some View {
        VStack(spacing: 10) {
            Button {
                if monitor.isRunning {
                    monitor.stop()
                } else {
                    do {
                        try monitor.start()
                    } catch {
                        print("启动失败：\(error.localizedDescription)")
                    }
                }
            } label: {
                Text(monitor.isRunning ? "停止" : "开始")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(monitor.isRunning ? .red : .accentColor)
            .disabled(usesRealDevice && !realSource.isAvailable)

            HStack(spacing: 10) {
                Button {
                    monitor.stop()
                    monitor.reset()
                } label: {
                    Label("重置", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)

                Button {
                    if let url = try? CSVExporter.writeTempFile(from: monitor.samples) {
                        exportFile = ExportFile(url: url)
                    }
                } label: {
                    Label("导出 CSV", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .disabled(monitor.samples.isEmpty)
            }
        }
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("这套为什么不占你的记录")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("· 全程不申请健康权限、不写 HealthKit，数据只在本 App 进程内存里，退出即消失。")
            Text("· 步频、步幅、距离、配速都是软件算出来的，没有任何系统级残留。")
            Text("· 需要看真实数据时切到「本机传感器」，走两步即可对照。")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    // MARK: - 绑定

    private func configureSource() {
        if usesRealDevice {
            monitor.bind(realSource, label: "本机传感器")
        } else {
            monitor.bind(simulator, label: "软件模拟")
        }
    }
}

// MARK: - 辅助类型

struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// 迷你折线图
struct SparkLine: Shape {
    var values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }

        let maxValue = max(values.max() ?? 1, 1)
        let minValue = min(values.min() ?? 0, maxValue * 0.5)
        let span = max(maxValue - minValue, 1)

        for (index, value) in values.enumerated() {
            let x = rect.width * CGFloat(index) / CGFloat(values.count - 1)
            let normalized = (value - minValue) / span
            let y = rect.maxY - CGFloat(normalized) * rect.height
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

#Preview {
    DemoContentView()
}
