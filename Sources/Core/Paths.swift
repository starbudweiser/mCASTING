// mCASTING — emplacements des données (partagés par l'appli et le serveur MCP).
import Foundation

public enum Paths {
    public static let home: URL = {
        if let p = ProcessInfo.processInfo.environment["MCASTING_HOME"] { return URL(fileURLWithPath: p) }
        let dev = (Bundle.main.bundleIdentifier ?? "").hasSuffix(".dev")
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/" + (dev ? "mCASTING-dev" : "mCASTING"))
    }()
    public static var projects: URL { home.appendingPathComponent("projects.json") }
    public static var voices: URL { home.appendingPathComponent("voices.json") }
    public static var favorites: URL { home.appendingPathComponent("favorites.json") }
    public static var audio: URL { home.appendingPathComponent("audio") }
    public static var engine: URL { home.appendingPathComponent("engine") }
    public static var lock: URL { home.appendingPathComponent("compute.lock") }
    public static var jobs: URL { home.appendingPathComponent("jobs.json") }
    /// Boîte de réception : d'autres outils (mTALKIE…) y déposent des paquets (manifest.json + audio), importés tout seuls.
    public static var inbox: URL { home.appendingPathComponent("Inbox") }
    public static var lines: URL { home.appendingPathComponent("lines") }
    public static var linesDB: URL { home.appendingPathComponent("lines.sqlite") }

    public static func prepare() {
        for d in [home, audio, engine, inbox, lines] { try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true) }
    }
}
