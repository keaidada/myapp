import Testing
import Foundation
@testable import myapp

struct AppScannerTests {
    /// mdfind 查询应用（依赖 Spotlight；某些环境可能为空，但不应崩溃）—— 只验证返回路径都以 .app 结尾
    @Test func scanReturnsAppPaths() {
        let apps = AppScanner.scan()
        if apps.isEmpty {
            // Spotlight 可能未启用，此时不抛错即可
            return
        }
        // 至少应能扫到常见应用目录里的应用
        #expect(apps.allSatisfy { $0.path.hasSuffix(".app") })
        #expect(apps.allSatisfy { !$0.name.isEmpty })
    }

    /// 验证已知应用能被扫到（若 Spotlight 正常，Sublime/iOA 应在结果中）
    @Test func scanFindsKnownAppsIfSpotlightAvailable() {
        let apps = AppScanner.scan()
        guard !apps.isEmpty else { return }
        let names = apps.map { $0.name.lowercased() }
        // 系统一定有 Safari
        #expect(names.contains("safari") || names.contains("finder"))
    }
}
