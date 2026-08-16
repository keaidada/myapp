通过 .app 运行（bundle 后的应用，CFBundleIdentifier 存在时通知才可靠），停掉一个被监控服务，等轮询发现后应弹出系统通知。

- [ ] **Step 4: 提交**

~~~bash
git add Sources/AppManager
git commit -m "feat: offline notifications for monitored services"
~~~

### Task 6.3: 设置页与收尾

**Files:**
- Create: Sources/AppManager/Views/SettingsView.swift
- Modify: Sources/AppManager/AppManagerApp.swift（Settings 场景）

- [ ] **Step 1: 设置页**

轮询间隔（秒，默认 10）、健康检查超时（默认 5）、通知开关；保存到 UserDefaults。

- [ ] **Step 2: README**

创建 README.md：项目简介、swift run 运行方式、./scripts/bundle-app.sh 打包方式、数据文件位置（Application Support/AppManager/services.json）。

- [ ] **Step 3: 最终构建 + 全量测试 + 提交**

~~~bash
swift build && swift test
git add -A
git commit -m "chore: settings page, README and final polish"
~~~

---

## 风险与备注

1. **CLI 启动窗口**：swift run 时通过 setActivationPolicy(.regular) + activate 保证窗口前置（P0 已处理）。
2. **管道死锁**：CommandRunner 用 async let 并行读取 stdout/stderr，避免进程写满管道缓冲后阻塞（P1 已处理）。
3. **MenuBarExtra 依赖 .app bundle**：直接 swift run 菜单栏可能不显示，用 scripts/bundle-app.sh 打包后运行（P6 已处理）。
4. **通知依赖 bundle identifier**：离线通知在 swift run 下可能无效，需打包后运行。
5. **无沙盒**：应用需要执行任意命令，不开 App Sandbox，仅个人本机使用。
6. **数据位置**：services.json 存于 ~/Library/Application Support/AppManager/，备份即拷贝该文件。

---

## 执行记录（2026-08-16 实际完成情况）

**状态：P0–P6 全部完成并提交**（12 个 commit，27 个测试全绿，打包 .app 可运行）

### 与计划的偏差（均为环境适配）

| 项目 | 计划 | 实际 | 原因 |
|---|---|---|---|
| 测试框架 | CLT 自带 swift-testing | 从 GitHub 引入 swift-testing 0.99 源码包 | CLT 的 Testing.framework 缺 lib_TestingInterop.dylib（Xcode 才完整）；import Testing 可编译但运行必崩 |
| 测试链接 | — | Package.swift testTarget 声明 product Testing 依赖 | 同上 |
| shell | zsh -lc | zsh -c | 免去每次读 zprofile 的开销与污染（审查建议） |
| 进程监控 | ps comm= | ps command= | 完整路径+参数，pidPattern 匹配更准（审查建议） |
| 激活方式 | init() 里 setActivationPolicy | NSApplicationDelegateAdaptor + applicationDidFinishLaunching 里 NSApp.activate() | 更稳妥（审查建议） |
| 打包脚本 | cp .build/release/AppManager | 先 swift build -c release，再用 --show-bin-path 取路径 | --show-bin-path 不触发构建 |
| 轮询间隔 | 写死 10 秒 | Settings 可配（5–120 秒） | 顺带实现设置页 |

### 实施中修复的关键缺陷

1. CommandRunner 终止竞态（审查 P1-3）：terminationHandler 先注册再 run()，用 AsyncStream 传递退出事件。
2. CommandRunner 超时读取 terminationStatus 崩溃（实施中发现）：terminate() 后进程未真正退出就读状态抛 NSInvalidArgumentException "task still running"——超时后先有界等待退出（2 秒），仍不退则 SIGKILL。这是 swift-testing 并行跑测试时暴露的间歇性崩溃。
3. ServiceController openApplication 返回非可选（审查 P1-1）：改 do/catch。
4. CommandOutputView 传可选值（审查 P1-2）：if let output 解包（已包含在 P3 实现中）。
5. @MainActor + Set 字面量：DashboardViewModel 标注 @MainActor；Set<UUID> = [:] 是字典字面量改 []。
6. 本地健康测试：用 python3 -m http.server 起临时端口验证 200 判定。

### 验收结果

- swift build：通过，无错误
- swift test：27 个测试通过（连续 3 次稳定）
- swift run：窗口正常显示（冒烟测试）
- ./scripts/bundle-app.sh：生成 dist/AppManager.app（ad-hoc 签名），直接运行正常
