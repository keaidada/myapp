import Foundation
import Observation

struct CommandEntry: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var serviceName: String
    var command: String
    var timestamp: Date
    var exitCode: Int32
    var stdout: String
    var stderr: String
    var isTimedOut: Bool

    var outputText: String {
        var text = stdout
        if !stderr.isEmpty {
            if !text.isEmpty { text += "\n" }
            text += stderr
        }
        return text
    }

    var succeeded: Bool { exitCode == 0 && !isTimedOut }
}

@MainActor
@Observable
final class CommandLog {
    private(set) var entries: [CommandEntry] = []
    let fileURL: URL
    private let maxEntries = 50

    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppManager", isDirectory: true)
        return base.appendingPathComponent("history.json")
    }

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        load()
    }

    func record(serviceName: String, command: String, result: CommandResult) {
        entries.insert(
            CommandEntry(
                serviceName: serviceName,
                command: command,
                timestamp: Date(),
                exitCode: result.exitCode,
                stdout: result.stdout,
                stderr: result.stderr,
                isTimedOut: result.isTimedOut
            ),
            at: 0
        )
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }

    func clear() {
        entries = []
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([CommandEntry].self, from: data) {
            entries = decoded
        }
    }

    private func save() {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
