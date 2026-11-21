// mCASTING — installe le skill mCASTING et déclare le serveur MCP dans les agents IA présents sur ce Mac.
// Chaque fichier de configuration d'un autre logiciel est sauvegardé avant d'être modifié (…mcasting-backup).
import Foundation

public enum AgentInstaller {
    public struct Agent: Identifiable, Hashable {
        public let id: String          // claude-code · codex · cursor · claude-desktop
        public let name: String
        public var present: Bool
        public var skill: Bool?        // nil = cet agent ne prend pas de skill
        public var mcp: Bool
        public var installed: Bool { mcp && (skill ?? true) }
    }

    /// Dossier personnel (remplaçable pour les essais : MCASTING_AGENT_HOME, jamais les vrais réglages pendant les tests).
    static var home: URL {
        if let h = ProcessInfo.processInfo.environment["MCASTING_AGENT_HOME"] { return URL(fileURLWithPath: h) }
        return FileManager.default.homeDirectoryForCurrentUser
    }
    static func path(_ rel: String) -> URL { home.appendingPathComponent(rel) }
    static let fm = FileManager.default

    public static var mcpBinary: String { Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/mcasting-mcp").path }
    public static var skillSource: URL? { Bundle.main.url(forResource: "SKILL", withExtension: "md", subdirectory: "skill/mcasting") }
    static var claudeCLI: String? {
        ["~/.local/bin/claude", "~/.claude/local/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
            .map { $0.replacingOccurrences(of: "~", with: home.path) }.first { fm.isExecutableFile(atPath: $0) }
    }
    static var desktopConfig: URL { path("Library/Application Support/Claude/claude_desktop_config.json") }

    public static func detect() -> [Agent] {
        let skill = skillSource.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        func sameSkill(_ u: URL) -> Bool { (try? String(contentsOf: u, encoding: .utf8)) == skill && !skill.isEmpty }
        var out: [Agent] = []
        // Claude Code
        let cc = fm.fileExists(atPath: path(".claude").path)
        let ccMCP = (try? String(contentsOf: path(".claude.json"), encoding: .utf8))?.contains("\"mcasting\"") ?? false
        out.append(Agent(id: "claude-code", name: "Claude Code", present: cc, skill: sameSkill(path(".claude/skills/mcasting/SKILL.md")), mcp: ccMCP))
        // Codex
        let cx = fm.fileExists(atPath: path(".codex").path)
        let cxMCP = (try? String(contentsOf: path(".codex/config.toml"), encoding: .utf8))?.contains("[mcp_servers.mcasting]") ?? false
        out.append(Agent(id: "codex", name: "Codex (ChatGPT)", present: cx, skill: sameSkill(path(".codex/skills/mcasting/SKILL.md")), mcp: cxMCP))
        // Cursor
        let cu = fm.fileExists(atPath: path(".cursor").path)
        out.append(Agent(id: "cursor", name: "Cursor", present: cu, skill: nil, mcp: jsonHasServer(path(".cursor/mcp.json"))))
        // Claude Desktop
        let cd = fm.fileExists(atPath: desktopConfig.deletingLastPathComponent().path)
        out.append(Agent(id: "claude-desktop", name: "Claude Desktop", present: cd, skill: nil, mcp: jsonHasServer(desktopConfig)))
        return out
    }

    static func jsonHasServer(_ u: URL) -> Bool {
        guard let d = try? Data(contentsOf: u), let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
              let s = o["mcpServers"] as? [String: Any] else { return false }
        return s["mcasting"] != nil
    }
    static func backup(_ u: URL) {
        guard fm.fileExists(atPath: u.path) else { return }
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"
        try? fm.copyItem(at: u, to: u.deletingLastPathComponent().appendingPathComponent(u.lastPathComponent + ".mcasting-backup-" + f.string(from: Date())))
    }
    static func installSkill(at dir: URL) throws {
        guard let src = skillSource else { throw EngineError.failed("Skill missing from the app bundle") }
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let dst = dir.appendingPathComponent("SKILL.md")
        try? fm.removeItem(at: dst)
        try fm.copyItem(at: src, to: dst)
    }
    /// Ajoute "mcasting" à la clé mcpServers d'un fichier JSON (Cursor, Claude Desktop) sans toucher au reste.
    static func addJSONServer(_ u: URL) throws {
        var o: [String: Any] = [:]
        if let d = try? Data(contentsOf: u) {
            guard let parsed = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { throw EngineError.failed("Unreadable \(u.lastPathComponent): left untouched") }
            o = parsed
        }
        var servers = o["mcpServers"] as? [String: Any] ?? [:]
        servers["mcasting"] = ["command": mcpBinary, "args": [String]()]
        o["mcpServers"] = servers
        backup(u)
        try fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: o, options: [.prettyPrinted, .sortedKeys]).write(to: u, options: .atomic)
    }

    /// Installe le skill (si l'agent en prend) et déclare le serveur MCP. Renvoie une note quand une étape reste à faire à la main.
    @discardableResult
    public static func install(_ id: String) throws -> String? {
        switch id {
        case "claude-code":
            try installSkill(at: path(".claude/skills/mcasting"))
            guard let cli = claudeCLI else { return "claude mcp add --scope user mcasting -- \"\(mcpBinary)\"" }
            let env = ["HOME": home.path]     // les essais (MCASTING_AGENT_HOME) ne touchent jamais la vraie configuration
            _ = try? Engine.run(URL(fileURLWithPath: cli), ["mcp", "remove", "--scope", "user", "mcasting"], env: env)
            try Engine.run(URL(fileURLWithPath: cli), ["mcp", "add", "--scope", "user", "mcasting", "--", mcpBinary], env: env)
        case "codex":
            try installSkill(at: path(".codex/skills/mcasting"))
            let u = path(".codex/config.toml")
            var t = (try? String(contentsOf: u, encoding: .utf8)) ?? ""
            if !t.contains("[mcp_servers.mcasting]") {
                backup(u)
                t += (t.isEmpty || t.hasSuffix("\n") ? "" : "\n") + "\n[mcp_servers.mcasting]\ncommand = \"\(mcpBinary)\"\nargs = []\n"
                try fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
                try t.write(to: u, atomically: true, encoding: .utf8)
            }
        case "cursor": try addJSONServer(path(".cursor/mcp.json"))
        case "claude-desktop": try addJSONServer(desktopConfig)
        default: break
        }
        return nil
    }
}
