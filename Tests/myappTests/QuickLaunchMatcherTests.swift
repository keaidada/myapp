import Testing
import Foundation
@testable import myapp

struct QuickLaunchMatcherTests {
    private func app(_ name: String, tags: [String] = [], category: String = "应用") -> ManagedService {
        var s = ManagedService(name: name, category: category)
        s.tags = tags
        return s
    }

    @Test func emptyQueryReturnsAllUpToLimit() {
        let services = (0..<20).map { app("App\($0)") }
        let results = QuickLaunchMatcher.ranked(services, query: "")
        #expect(results.count == 15)
    }

    @Test func prefixMatchRankedFirst() {
        let services = [
            app("Chrome"),
            app("Chrome 扩展助手"),
            app("微信"),
            app("VSCode")
        ]
        let results = QuickLaunchMatcher.ranked(services, query: "chr")
        #expect(results.first?.name == "Chrome")
        #expect(results.map(\.name).contains("Chrome 扩展助手"))
        #expect(!results.map(\.name).contains("微信"))
    }

    @Test func matchesByTag() {
        let services = [app("微信", tags: ["通讯"]), app("Chrome", tags: ["浏览器"])]
        let results = QuickLaunchMatcher.ranked(services, query: "通讯")
        #expect(results.count == 1)
        #expect(results[0].name == "微信")
    }

    @Test func matchesByAlias() {
        var s = app("TencentMeeting", tags: ["通讯"])
        s.aliases = ["腾讯会议"]
        let results = QuickLaunchMatcher.ranked([s], query: "腾讯会议")
        #expect(results.count == 1)
        #expect(results[0].name == "TencentMeeting")
    }

    @Test func aliasMatchRanksLikeName() {
        var a = app("TencentMeeting")
        a.aliases = ["腾讯会议"]
        let b = app("企业微信")
        let results = QuickLaunchMatcher.ranked([b, a], query: "腾讯")
        #expect(results.first?.name == "TencentMeeting")
    }

    @Test func matchesByNameContains() {
        let services = [app("企业微信"), app("微信读书")]
        let results = QuickLaunchMatcher.ranked(services, query: "微信")
        #expect(results.count == 2)
        // 前缀优先：企业微信 不是前缀，微信读书 是前缀
        #expect(results[0].name == "微信读书")
    }

    @Test func noMatchReturnsEmpty() {
        let services = [app("Chrome"), app("Safari")]
        let results = QuickLaunchMatcher.ranked(services, query: "不存在的应用zzz")
        #expect(results.isEmpty)
    }

    @Test func matchesCaseInsensitive() {
        let services = [app("VS Code")]
        #expect(QuickLaunchMatcher.matches(services[0], query: "vs"))
        #expect(QuickLaunchMatcher.matches(services[0], query: "CODE"))
    }
}
