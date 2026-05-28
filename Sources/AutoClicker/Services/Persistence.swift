import Foundation

public struct ApplicationSupportPaths {
    public var baseURL: URL

    public init(baseURL: URL? = nil) {
        if let baseURL {
            self.baseURL = baseURL
        } else {
            let defaultURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.baseURL = defaultURL.appendingPathComponent("AutoClicker", isDirectory: true)
        }
    }

    public var macrosDirectory: URL {
        baseURL.appendingPathComponent("macros", isDirectory: true)
    }

    public var settingsFile: URL {
        baseURL.appendingPathComponent("settings.json")
    }
}

public final class MacroStore: @unchecked Sendable {
    private let fileManager: FileManager
    private let paths: ApplicationSupportPaths
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileManager: FileManager = .default, paths: ApplicationSupportPaths = .init()) {
        self.fileManager = fileManager
        self.paths = paths
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func loadAll() throws -> [MacroDocument] {
        try ensureDirectories()
        let files = try fileManager.contentsOfDirectory(at: paths.macrosDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try files.map { try decoder.decode(MacroDocument.self, from: Data(contentsOf: $0)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func save(_ document: MacroDocument) throws {
        try ensureDirectories()
        let url = paths.macrosDirectory.appendingPathComponent(document.id.uuidString).appendingPathExtension("json")
        let data = try encoder.encode(document)
        try data.write(to: url, options: .atomic)
    }

    public func delete(_ document: MacroDocument) throws {
        let url = paths.macrosDirectory.appendingPathComponent(document.id.uuidString).appendingPathExtension("json")
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func ensureDirectories() throws {
        if !fileManager.fileExists(atPath: paths.baseURL.path) {
            try fileManager.createDirectory(at: paths.baseURL, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: paths.macrosDirectory.path) {
            try fileManager.createDirectory(at: paths.macrosDirectory, withIntermediateDirectories: true)
        }
    }
}

public final class SettingsStore: @unchecked Sendable {
    private let fileManager: FileManager
    private let paths: ApplicationSupportPaths
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileManager: FileManager = .default, paths: ApplicationSupportPaths = .init()) {
        self.fileManager = fileManager
        self.paths = paths
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func load() -> AppSettings {
        guard let data = try? Data(contentsOf: paths.settingsFile),
              let settings = try? decoder.decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    public func save(_ settings: AppSettings) throws {
        if !fileManager.fileExists(atPath: paths.baseURL.path) {
            try fileManager.createDirectory(at: paths.baseURL, withIntermediateDirectories: true)
        }
        let data = try encoder.encode(settings)
        try data.write(to: paths.settingsFile, options: .atomic)
    }
}
