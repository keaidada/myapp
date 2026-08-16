# myapp

一个运行在 macOS 上的原生 SwiftUI 应用，统一管理本地 App、自建 Web 服务与自定义命令。

## 核心亮点

### 免配置添加
**添加服务 → 从系统发现…**，自动扫描并列出你 Mac 上的内容，点一下就添加好，命令自动帮你填：
- **已安装应用**：自动扫描 /Applications、~/Applications、/System/Applications，显示真实图标，一键"全部添加"
- **Homebrew 服务**：自动读取 brew services list，显示运行状态，一键添加（启停/状态命令自动填好）

### 智能状态显示
- **应用**：自动检测进程是否在运行 → 运行中 🟢 / 未运行 ⚪（无需配置）
- **Web 服务**：健康检查地址（支持 {key} 变量）→ 正常/离线 + 延迟
- **命令服务**：状态命令（exit 0 = 运行中）

### 标签分类整理
- 每个服务可打多个标签，编辑表单里逗号分隔输入
- **批量打标签**：多选服务 → 底部操作栏"标签"→ 输入或点已有标签，一次给 N 个服务打上
- **按标签整理**：侧边栏"标签"区列出所有标签，点击即过滤；"未打标签"查看待整理项

### 其他功能
- 一键启动 / 服务控制（启停/重启/状态）/ 批量操作（全选/反选/选中批量）
- 预置模板库（20+ 常用模板）/ 自定义命令模板 / 图标选择器 / 拖拽排序
- 资源查看（CPU/内存）/ 菜单栏常驻（离线变红警示）/ 导出导入配置 / 运行历史

## 开发环境要求

- macOS 14+（开发机为 Apple Silicon，路径含 /opt/homebrew）
- Swift 6.x（Command Line Tools 即可，**无需 Xcode**）

## 运行

```bash
swift run          # 调试运行
swift test         # 运行测试（56 个）
```

> 首次运行会从 GitHub 拉取 swift-testing 源码构建（CLT 自带的 Testing 框架不完整）。

## 打包成 .app

```bash
./scripts/bundle-app.sh
open dist/myapp.app
```

打包后（而非 swift run）运行时：菜单栏图标、系统通知才能完整工作。

## 数据存储

- 服务清单：~/Library/Application Support/myapp/services.json
- 运行历史：~/Library/Application Support/myapp/history.json

## 使用建议

- 给应用打标签的例子：工作、娱乐、开发、设计、系统
- 批量操作适合：多选一批应用打同个标签；一键启动/关闭一组服务
- 前台型长驻命令（如 node server.js）会被 30 秒超时终止，请自行守护化
