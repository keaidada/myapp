# myapp 🦫

一款原生 SwiftUI 编写的 macOS 应用管理器：统一管理本机应用、本地 Web 服务与自定义命令，支持一键启动、状态监控、标签分类与最近热度统计。

> 水豚图标，随开随用。所有数据保存在本地 `~/Library/Application Support/myapp/`，无需联网。

## ✨ 功能

- **三种服务类型**：应用（`.app`）、URL 服务、自定义命令（Command）
- **免配置添加**：从系统发现一键扫描本机应用（真实图标）与 Homebrew 服务（启停/状态命令自动填好）
- **一键启动 / 关闭**：应用类优雅退出（Electron 应用自动 TERM/KILL 兜底）、命令类执行启停脚本
- **状态监控**：进程检测 / 健康检查 URL / 状态命令，全局轮询，菜单栏实时汇总（离线变红警示）
- **标签系统**：标签增删改查、批量打标、点击标签过滤、标签级批量启停
- **最近热度 Top10**：自动记录启动次数与最近启动时间，侧边栏查看高频服务
- **搜索别名**：扫描应用时自动提取 `CFBundleName` / `CFBundleDisplayName`，支持中文名搜索（如 TencentMeeting → 腾讯会议）
- **预置模板库**：20+ 常用模板（Web 开发、数据库、AI 等）一键添加
- **批量操作**：多选模式批量启动 / 停止 / 重启 / 打标签
- **自定义命令模板**：变量占位符替换，灵活编排
- **运行历史**：记录每次命令执行结果，可回看输出
- **全局快速启动**：`Cmd + Shift + M` 呼出快速启动面板
- **导出 / 导入**：配置 JSON 备份与迁移
- **菜单栏常驻**：离线服务提醒、一键启动

## 🚀 使用

```bash
swift run          # 调试运行
swift test         # 运行测试（95 个）
```

> 首次构建会从 GitHub 拉取 swift-testing 源码（CLT 自带的 Testing 框架不完整）。

## 📦 打包成 .app

```bash
./scripts/bundle-app.sh   # 含图标与 ad-hoc 签名，输出到 dist/myapp.app
open dist/myapp.app
```

打包后（而非 swift run）运行时，菜单栏图标、系统通知才能完整工作。

## 📁 数据存储

| 文件 | 内容 |
| --- | --- |
| `services.json` | 服务清单（含标签、热度、别名等） |
| `history.json` | 命令运行历史 |

路径：`~/Library/Application Support/myapp/`

## 🧩 项目结构

```
Sources/myapp/
├── Models/        # 数据模型（服务、状态、类型）
├── Storage/       # 持久化（ServiceStore）
├── Services/      # 核心逻辑（启动/状态/扫描/模板/排序…）
├── Views/         # SwiftUI 界面
└── QuickLaunch/   # 全局快速启动面板
Tests/myappTests/  # 单元测试（swift-testing）
scripts/           # 打包与图标生成脚本
assets/            # 应用图标
```

## 🧪 测试

95 个单元测试覆盖：容错解码、存储持久化、命令执行、状态检测、健康检查、资源监控、标签、模板、热度排序、快速启动匹配、搜索别名等。

## 💡 使用建议

- 给应用打标签的例子：工作、娱乐、开发、设计、系统
- 批量操作适合：多选一批应用打同个标签；一键启动/关闭一组服务
- 前台型长驻命令（如 `node server.js`）会被 30 秒超时终止，请自行守护化

## 📄 License

MIT
