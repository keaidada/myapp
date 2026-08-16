# AppManager

一个运行在 macOS 上的原生 SwiftUI 应用，统一管理本地 App、自建 Web 服务与自定义命令。

## 功能

- **一键启动**：打开应用 / 网页 / 执行命令
- **健康监控**：定时轮询 HTTP 健康检查（支持 {key} 模板变量），绿/红点 + 延迟显示，离线通知
- **服务控制**：启动 / 停止 / 重启 / 查询状态（Homebrew、Docker、自定义命令）
- **预置模板库**：内置 20+ 常用模板（Homebrew 服务 / Docker / 开发 / 应用 / 网页），一键添加
- **自定义命令模板**：{key} 占位符 + 每行 key=value 的变量配置
- **图标选择器**：可视化选择 SF Symbol 图标
- **拖拽排序**：列表内直接拖动调整顺序
- **批量操作**：全部启动 / 停止 / 重启，并行执行 + 结果汇总
- **分类整理**：按分类侧栏 + 搜索过滤
- **资源查看**：按进程名匹配展示 CPU / 内存占用
- **菜单栏常驻**：离线变红警示 + 离线服务列表 + 快速启动
- **导出 / 导入配置**：JSON 备份与迁移，一键打开数据目录
- **运行历史**：记录最近 50 条命令执行，可查看输出、一键重跑

## 开发环境要求

- macOS 14+（开发机为 Apple Silicon，路径含 /opt/homebrew）
- Swift 6.x（Command Line Tools 即可，**无需 Xcode**）

## 运行

```bash
swift run          # 调试运行
swift test         # 运行测试（44 个）
```

> 首次运行会从 GitHub 拉取 swift-testing 源码构建（CLT 自带的 Testing 框架不完整）。

## 打包成 .app

```bash
./scripts/bundle-app.sh
open dist/AppManager.app
```

打包后（而非 swift run）运行时：菜单栏图标、系统通知才能完整工作。

## 数据存储

- 服务清单：~/Library/Application Support/AppManager/services.json
- 运行历史：~/Library/Application Support/AppManager/history.json

备份 = 拷贝以上两个文件；也可在应用内"更多 → 导出配置"。

## 使用建议

- 健康检查地址（checkURL）配 HTTP 接口；状态命令（statusCommand）配 pgrep 类命令（exit 0 = 正常运行）
- 启停命令适合 brew services start/stop/restart xxx、docker compose up -d / down 这类会自行退出的命令
- 前台型长驻命令（如 node server.js）会被 30 秒超时终止，请自行守护化（nohup / launchd / brew services）
