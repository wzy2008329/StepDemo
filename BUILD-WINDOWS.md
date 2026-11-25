# 纯 Windows 装机流程：从这台电脑装到你的 iPhone

## 0. 先把事实说清楚

- iOS App 只能用 **macOS 工具链（Xcode）** 编译，Windows 上没有 iOS SDK，也做不出可安装的二进制。
- USB（Lockdown / Apple Mobile Device）只开放备份、文件传输、日志、恢复等能力，**系统不开放第三方 App 安装以外的入口**，更没有"直接写入运动数据"的接口。
- 所以最短的可行链路是：**云 macOS 编译 → 得到未签名 .ipa → Windows 上用它签名安装 → 手机上跑**。全流程都在你这台 Windows 上完成，只是多了个免费云端编译环节。

链路：`GitHub Actions（免费 macOS runner）` → `StepDemo-unsigned.ipa` → `Sideloadly（Windows）用你的免费 Apple ID 签名` → `iPhone`

---

## 1. 准备两样东西

| 需要 | 说明 |
|---|---|
| GitHub 账号 | 免费。**仓库设为 Public，Actions 的 macOS 分钟数才是无限免费**（私有仓库每月只有约 200 分钟 macOS 额度） |
| Sideloadly | Windows 版免费签名工具，官网 sideloadly.io。它依赖 Apple 的移动设备驱动，你机器上 `Apple Mobile Device Service` 已在运行，说明驱动就绪 |

不需要：付费开发者账号（99 美元）、Mac、越狱。

---

## 2. 把代码传到 GitHub

**方式 A：网页上传（不装 git，推荐）**

1. GitHub → New repository → 名字 `StepDemo` → **Public** → Create。
2. 解压源码包，**进入 `StepSourceDemo` 文件夹内部，全选里面的文件和文件夹再一起拖进 GitHub 上传区**——不要直接拖 `StepSourceDemo` 这个外层文件夹，否则仓库里会多出一层目录，workflow 就找不到路径了。
3. 要拖进去的内容（保持层级）：
   ```
   project.yml
   README.md
   .github/workflows/build-ipa.yml
   StepSourceKit/Package.swift
   StepSourceKit/Sources/StepSourceKit/*.swift   （6 个文件）
   DemoApp/StepDemoApp.swift
   DemoApp/DemoContentView.swift
   DemoApp/Info.plist
   ```
3. Commit changes。

> `.github` 这种点开头的目录，网页上传偶尔会被忽略。传完到仓库首页确认能看到 `.github/workflows/build-ipa.yml`；如果看不到，改用下面的方式 B：仓库 → **Actions** → `set up a workflow yourself` → 把 `build-ipa.yml` 的内容整段粘进去 → Commit，效果完全一样。

**方式 B：命令行**

```powershell
cd C:\Users\wzy20\Doubao\chats\2026-11-23\new-chat-2\StepSourceDemo
git init
git add .
git commit -m "init"
git remote add origin https://github.com/你的用户名/StepDemo.git
git push -u origin main
```

---

## 3. 云端编译，取回 .ipa

1. 仓库 → **Actions** 标签 → 左侧 `Build unsigned IPA` → 右侧 `Run workflow` → 选分支 → Run。
2. 等 3–6 分钟（第一次装 XcodeGen 稍慢），绿勾表示成功。
3. 点进这次运行 → 页面底部 **Artifacts** → 下载 `StepDemo-unsigned-ipa`（得到 zip，解压出 `StepDemo-unsigned.ipa`）。

如果失败，看日志里 `Build unsigned app` 那一步。这个工作流刻意用 `-target StepDemo` 而不是 `-scheme`，因为 CI 上没有 Xcode 自动生成的 scheme，用 `-scheme` 十有八九报 `scheme not found`；产物路径也用 `CONFIGURATION_BUILD_DIR` 写死了，不受 DerivedData 位置影响。日志里 `Generate Xcode project` 那步会打印 `xcodebuild -list`，可以用来核对 target 名字确实是 `StepDemo`。

---

## 4. 在 Windows 上用 Sideloadly 装进去

1. 手机用 USB 连好（已在连接状态）。
2. 打开 Sideloadly：
   - **Apple ID** 填你的账号（免费个人账号即可）
   - **IPA** 选刚解压的 `StepDemo-unsigned.ipa`
   - 设备下拉里选中你的 iPhone
   - 勾选 **Normal install**（不要选 Cydia Impactor 那类模式）
3. 点 **Start**。会依次：请求签名 → 让你在手机上/弹窗里输 **Apple ID 双重认证验证码** → 自动改 Bundle ID → 安装。
4. 装完首次打开会提示"未受信任的开发者"：
   设置 → 通用 → VPN与设备管理 → 开发者 App → 选你的 Apple ID → **信任**。
5. 回到桌面打开「虚拟计步源」，选软件模拟，拖步频步幅，点开始。

---

## 5. 免费签名的三条硬限制

- **有效期 7 天**，到期 App 打不开，重新用 Sideloadly 装一次即可（数据不丢）。
- 同时最多 **3 个**自签 App。
- 每周最多注册 **10 个** App ID，改 Bundle ID 别太频繁。

想彻底摆脱 7 天限制只有两条：付费开发者账号（1 年）/ 越狱免签工具（不建议，风险大）。

---

## 6. 常见报错对照

| 报错 | 原因 | 处理 |
|---|---|---|
| `Unable to install ... requires Developer Mode` | 手机没开开发者模式 | 设置 → 隐私与安全性 → 开发者模式 → 打开并重启 |
| `This app is not signed` / 安装后闪退 | IPA 是未签名包，Sideloadly 没签名成功 | 检查 Apple ID 是否登录成功、2FA 是否输入 |
| `Maximum number of apps for free development profiles` | 免费签名 3 个上限 | 删掉设备上其他自签 App 再装 |
| Sideloadly 一直在 `Signing...` 不动 | 苹果签名服务器慢/网络被拦 | 换网络（手机热点）、重试，或换个时段 |
| `Unable to communicate with device` | 驱动没就绪 | 装 Microsoft Store 的「Apple Devices」，或重插数据线换口 |
| Actions 报 `xcodebuild: error: scheme ... not found` | 用了 `-scheme` 构建，CI 上没这个 scheme | 已规避：本工作流用 `-target StepDemo`。别改回 `-scheme` |

---

## 7. 备选方案（如果 GitHub 这条路不通）

| 方案 | 成本 | 说明 |
|---|---|---|
| 云 Mac（MacinCloud / MacStadium） | 几十元/天 | 远程桌面里直接 Xcode ⌘R，最快最稳，5 分钟搞定 |
| Codemagic | 免费额度 | 类似的云 macOS 编译，也能产出未签名 IPA |
| 借一台 Mac | 0 | Xcode 连手机运行，个人免费签名同样 7 天 |

---

## 8. 边界再确认一次

这个 App 装在手机上只会**在它自己的界面里模拟**步频、步幅、距离、配速，不写健康、不出设备。如果目标是让你自己的另一个 App 读到这些数据，那个 App 也要走同一套装机流程，并且只能用 `StepSourceKit` 这种进程内注入的方式，不要让它去写健康库。
