// mCASTING — stockage JSON atomique, avec verrou de fichier : l'appli et le serveur MCP partagent les mêmes fichiers.
import Foundation

public enum DataStore {
    private static let enc: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e }()

    public static func load<T: Decodable>(_ type: T.Type, from url: URL, default d: T) -> T {
        guard let data = try? Data(contentsOf: url), let v = try? JSONDecoder().decode(T.self, from: data) else { return d }
        return v
    }
    public static func save<T: Encodable>(_ v: T, to url: URL) throws {
        Paths.prepare()
        try enc.encode(v).write(to: url, options: .atomic)
    }
    public static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    public static func projects() -> [Project] { load([Project].self, from: Paths.projects, default: []) }
    public static func saveProjects(_ p: [Project]) throws { try save(p, to: Paths.projects) }
    public static func voices() -> [Voice] { load([Voice].self, from: Paths.voices, default: []) }
    public static func favorites() -> Set<String> { Set(load([String].self, from: Paths.favorites, default: [])) }
    public static func saveFavorites(_ f: Set<String>) throws { try save(f.sorted(), to: Paths.favorites) }
    public static func saveVoices(_ v: [Voice]) throws { try save(v, to: Paths.voices) }

    /// Modification d'un projet sous verrou (lecture → modification → écriture) pour éviter les écrasements app/MCP.
    @discardableResult
    public static func updateProjects(_ body: (inout [Project]) throws -> Void) throws -> [Project] {
        Paths.prepare()
        let fd = open(Paths.home.appendingPathComponent("data.lock").path, O_CREAT | O_RDWR, 0o600)
        defer { if fd >= 0 { flock(fd, LOCK_UN); close(fd) } }
        if fd >= 0 { flock(fd, LOCK_EX) }
        var p = projects()
        try body(&p)
        try saveProjects(p)
        return p
    }
}
