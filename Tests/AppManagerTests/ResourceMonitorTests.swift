import Testing
@testable import AppManager

struct ResourceMonitorTests {
    @Test func parsesSample() {
        let raw = """
        123   1.2   0.5 /usr/bin/redis-server
        456  12.3   4.5 /usr/bin/python3 http.server
        """
        let samples = ResourceMonitor.parse(raw)
        #expect(samples.count == 2)
        #expect(samples[0] == ProcessSample(pid: 123, cpu: 1.2, mem: 0.5, command: "/usr/bin/redis-server"))
        #expect(samples[1].cpu == 12.3)
    }

    @Test func ignoresMalformedLines() {
        let samples = ResourceMonitor.parse("not a number line\n789  0.1  0.2 cmd")
        #expect(samples.count == 1)
        #expect(samples[0].pid == 789)
    }

    @Test func commandKeepsSpaces() {
        let samples = ResourceMonitor.parse("999   0.0   0.0 /usr/bin/node /opt/x/app server.js")
        #expect(samples.count == 1)
        #expect(samples[0].command == "/usr/bin/node /opt/x/app server.js")
    }
}
