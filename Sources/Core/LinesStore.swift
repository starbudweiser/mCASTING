// mCASTING — base de répliques (lines.sqlite) : répliques reçues d'autres outils (mTALKIE…) ou de toute source (jeu,
// film, série), avec recherche plein texte (FTS5). SQLite est fourni par macOS : aucune dépendance. Partagée app + MCP.
import Foundation
import SQLite3

/// Une réplique de la base.
public struct LineRecord: Codable, Identifiable, Hashable {
    public var id: Int64
    public var source: String        // identifiant de la source (ex. « mi2se »)
    public var sourceTitle: String   // titre affiché (« Monkey Island 2 : Special Edition »)
    public var sourceKind: String    // game / film / series / other
    public var key: String           // nom de la réplique dans la source (« gb_0412 »)
    public var text: String
    public var character: String     // personnage qui parle (vide si inconnu)
    public var lang: String          // code ISO 639-1
    public var duration: Double
    public var tags: [String]        // laugh, scream, insult, greeting, question, threat, exclamation…
    public var audio: String?        // chemin absolu de l'audio (nil : texte seul)
}

/// Une source de répliques (jeu, film, série).
public struct LineSource: Codable, Identifiable, Hashable {
    public var id: String, title: String, kind: String, count: Int, imported: Date
    public var langs: [String]
}

public enum LinesStore {
    public static let knownTags = ["laugh", "scream", "insult", "greeting", "question", "threat", "exclamation"]
    private static let lock = NSLock()
    nonisolated(unsafe) private static var db: OpaquePointer?
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    // MARK: ouverture
    private static func open() -> OpaquePointer? {
        if let db { return db }
        Paths.prepare()
        var h: OpaquePointer?
        guard sqlite3_open_v2(Paths.linesDB.path, &h, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else { return nil }
        sqlite3_busy_timeout(h, 5000)
        exec(h, """
        PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS sources(id TEXT PRIMARY KEY, title TEXT, kind TEXT, imported REAL);
        CREATE TABLE IF NOT EXISTS lines(id INTEGER PRIMARY KEY, source TEXT, key TEXT, text TEXT, character TEXT, lang TEXT,
                                         duration REAL, tags TEXT, audio TEXT);
        CREATE INDEX IF NOT EXISTS lines_source ON lines(source);
        CREATE VIRTUAL TABLE IF NOT EXISTS lines_fts USING fts5(text, character, tokenize='unicode61 remove_diacritics 2');
        """)
        db = h
        return h
    }
    @discardableResult
    private static func exec(_ h: OpaquePointer?, _ sql: String) -> Bool { sqlite3_exec(h, sql, nil, nil, nil) == SQLITE_OK }
    private static func prepare(_ h: OpaquePointer?, _ sql: String) throws -> OpaquePointer? {
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(h, sql, -1, &st, nil) == SQLITE_OK else { throw err(h) }
        return st
    }
    private static func err(_ h: OpaquePointer?) -> NSError {
        NSError(domain: "mCASTING.lines", code: Int(sqlite3_errcode(h)), userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(h))])
    }
    private static func bind(_ st: OpaquePointer?, _ vals: [Any?]) {
        for (i, v) in vals.enumerated() {
            let n = Int32(i + 1)
            switch v {
            case let s as String: sqlite3_bind_text(st, n, s, -1, transient)
            case let d as Double: sqlite3_bind_double(st, n, d)
            case let x as Int: sqlite3_bind_int64(st, n, Int64(x))
            case let x as Int64: sqlite3_bind_int64(st, n, x)
            default: sqlite3_bind_null(st, n)
            }
        }
    }
    private static func col(_ st: OpaquePointer?, _ i: Int32) -> String { sqlite3_column_text(st, i).map { String(cString: $0) } ?? "" }

    // MARK: écriture
    public struct NewLine {
        public var key: String, text: String, character: String, lang: String, duration: Double, tags: [String], audio: String?
        public init(key: String, text: String, character: String, lang: String, duration: Double, tags: [String], audio: String?) {
            self.key = key; self.text = text; self.character = character; self.lang = lang; self.duration = duration; self.tags = tags; self.audio = audio
        }
    }

    /// Remplace toutes les répliques d'une source (un nouvel envoi de la même source annule le précédent).
    public static func replace(source id: String, title: String, kind: String, lines: [NewLine]) throws {
        lock.lock(); defer { lock.unlock() }
        guard let h = open() else { throw NSError(domain: "mCASTING.lines", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot open lines.sqlite"]) }
        exec(h, "BEGIN IMMEDIATE")
        do {
            try removeLocked(h, id)
            let s = try prepare(h, "INSERT INTO sources(id,title,kind,imported) VALUES(?,?,?,?)"); defer { sqlite3_finalize(s) }
            bind(s, [id, title, kind, Date().timeIntervalSince1970]); guard sqlite3_step(s) == SQLITE_DONE else { throw err(h) }
            let ins = try prepare(h, "INSERT INTO lines(source,key,text,character,lang,duration,tags,audio) VALUES(?,?,?,?,?,?,?,?)"); defer { sqlite3_finalize(ins) }
            let fts = try prepare(h, "INSERT INTO lines_fts(rowid,text,character) VALUES(?,?,?)"); defer { sqlite3_finalize(fts) }
            for l in lines {
                sqlite3_reset(ins); sqlite3_clear_bindings(ins)
                bind(ins, [id, l.key, l.text, l.character, l.lang, l.duration, l.tags.isEmpty ? "" : "," + l.tags.joined(separator: ",") + ",", l.audio])
                guard sqlite3_step(ins) == SQLITE_DONE else { throw err(h) }
                let row = sqlite3_last_insert_rowid(h)
                sqlite3_reset(fts); sqlite3_clear_bindings(fts)
                bind(fts, [row, l.text, l.character])
                guard sqlite3_step(fts) == SQLITE_DONE else { throw err(h) }
            }
            exec(h, "COMMIT")
        } catch { exec(h, "ROLLBACK"); throw error }
    }

    private static func removeLocked(_ h: OpaquePointer?, _ id: String) throws {
        let a = try prepare(h, "DELETE FROM lines_fts WHERE rowid IN (SELECT id FROM lines WHERE source=?)"); defer { sqlite3_finalize(a) }
        bind(a, [id]); sqlite3_step(a)
        for sql in ["DELETE FROM lines WHERE source=?", "DELETE FROM sources WHERE id=?"] {
            let st = try prepare(h, sql); bind(st, [id]); sqlite3_step(st); sqlite3_finalize(st)
        }
    }

    /// Retire une source et ses répliques (les fichiers audio sont effacés par l'appelant).
    public static func remove(source id: String) throws {
        lock.lock(); defer { lock.unlock() }
        guard let h = open() else { return }
        exec(h, "BEGIN IMMEDIATE"); try removeLocked(h, id); exec(h, "COMMIT")
        try? FileManager.default.removeItem(at: Paths.lines.appendingPathComponent(safe(id)))
    }

    /// Retire des répliques précises (base + index plein texte) et efface leurs fichiers audio, sans toucher au reste.
    /// Seuls les fichiers situés dans le dossier des répliques de l'appli sont effacés. Renvoie le nombre retiré.
    @discardableResult
    public static func remove(lines ids: [Int64]) throws -> Int {
        guard !ids.isEmpty else { return 0 }
        lock.lock(); defer { lock.unlock() }
        guard let h = open() else { return 0 }
        var audios: [String] = [], n = 0
        exec(h, "BEGIN IMMEDIATE")
        do {
            let sel = try prepare(h, "SELECT audio FROM lines WHERE id=?"); defer { sqlite3_finalize(sel) }
            let d1 = try prepare(h, "DELETE FROM lines_fts WHERE rowid=?"); defer { sqlite3_finalize(d1) }
            let d2 = try prepare(h, "DELETE FROM lines WHERE id=?"); defer { sqlite3_finalize(d2) }
            for id in ids {
                sqlite3_reset(sel); sqlite3_clear_bindings(sel); bind(sel, [id])
                if sqlite3_step(sel) == SQLITE_ROW { let a = col(sel, 0); if !a.isEmpty { audios.append(a) } }
                for st in [d1, d2] { sqlite3_reset(st); sqlite3_clear_bindings(st); bind(st, [id]); guard sqlite3_step(st) == SQLITE_DONE else { throw err(h) } }
                n += 1
            }
            // Une source sans réplique est retirée aussi (plus rien à afficher).
            exec(h, "DELETE FROM sources WHERE id NOT IN (SELECT DISTINCT source FROM lines)")
            exec(h, "COMMIT")
        } catch { exec(h, "ROLLBACK"); throw error }
        let root = Paths.lines.standardizedFileURL.path + "/"
        for a in audios {
            let u = (a.hasPrefix("/") ? URL(fileURLWithPath: a) : Paths.lines.appendingPathComponent(a)).standardizedFileURL
            if u.path.hasPrefix(root) { try? FileManager.default.removeItem(at: u) }
        }
        return n
    }

    /// Nom de dossier sûr pour une source.
    public static func safe(_ id: String) -> String {
        let s = id.lowercased().map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "-" }
        return String(s).isEmpty ? "source" : String(s)
    }

    // MARK: lecture
    public static func sources() -> [LineSource] {
        lock.lock(); defer { lock.unlock() }
        guard let h = open(), let st = try? prepare(h, """
            SELECT s.id, s.title, s.kind, s.imported, COUNT(l.id), GROUP_CONCAT(DISTINCT l.lang)
            FROM sources s LEFT JOIN lines l ON l.source = s.id GROUP BY s.id ORDER BY s.title
            """) else { return [] }
        defer { sqlite3_finalize(st) }
        var out: [LineSource] = []
        while sqlite3_step(st) == SQLITE_ROW {
            out.append(LineSource(id: col(st, 0), title: col(st, 1), kind: col(st, 2), count: Int(sqlite3_column_int64(st, 4)),
                                  imported: Date(timeIntervalSince1970: sqlite3_column_double(st, 3)),
                                  langs: col(st, 5).split(separator: ",").map(String.init).sorted()))
        }
        return out
    }

    public struct Query {
        public var text = "", sources: [String] = [], character = "", lang = "", tags: [String] = []
        public var minDuration: Double? = nil, maxDuration: Double? = nil, limit = 200
        public init() {}
    }

    /// Recherche : texte (mots en préfixe, accents ignorés), filtres ; renvoie les répliques et le nombre total trouvé.
    public static func search(_ q: Query) -> (lines: [LineRecord], total: Int) {
        lock.lock(); defer { lock.unlock() }
        guard let h = open() else { return ([], 0) }
        var whereSQL: [String] = [], vals: [Any?] = []
        let words = q.text.lowercased().split { !$0.isLetter && !$0.isNumber && $0 != "'" }.map { $0.replacingOccurrences(of: "'", with: " ") }
        if !words.isEmpty {
            whereSQL.append("l.id IN (SELECT rowid FROM lines_fts WHERE lines_fts MATCH ?)")
            vals.append(words.map { "\"\($0)\"*" }.joined(separator: " "))
        }
        if !q.sources.isEmpty { whereSQL.append("l.source IN (" + q.sources.map { _ in "?" }.joined(separator: ",") + ")"); vals += q.sources }
        if !q.character.isEmpty { whereSQL.append("l.character LIKE ?"); vals.append("%" + q.character + "%") }
        if !q.lang.isEmpty { whereSQL.append("l.lang = ?"); vals.append(q.lang) }
        for t in q.tags { whereSQL.append("l.tags LIKE ?"); vals.append("%," + t + ",%") }
        if let m = q.minDuration { whereSQL.append("l.duration >= ?"); vals.append(m) }
        if let m = q.maxDuration { whereSQL.append("l.duration < ?"); vals.append(m) }
        let w = whereSQL.isEmpty ? "" : " WHERE " + whereSQL.joined(separator: " AND ")
        var total = 0
        if let c = try? prepare(h, "SELECT COUNT(*) FROM lines l" + w) {
            bind(c, vals); if sqlite3_step(c) == SQLITE_ROW { total = Int(sqlite3_column_int64(c, 0)) }; sqlite3_finalize(c)
        }
        let sql = "SELECT l.id,l.source,s.title,s.kind,l.key,l.text,l.character,l.lang,l.duration,l.tags,l.audio FROM lines l LEFT JOIN sources s ON s.id=l.source"
            + w + " ORDER BY (l.text = ''), l.source, l.id LIMIT \(max(1, min(q.limit, 2000)))"
        guard let st = try? prepare(h, sql) else { return ([], total) }
        defer { sqlite3_finalize(st) }
        bind(st, vals)
        var out: [LineRecord] = []
        while sqlite3_step(st) == SQLITE_ROW { out.append(record(st)) }
        return (out, total)
    }

    public static func get(_ id: Int64) -> LineRecord? {
        lock.lock(); defer { lock.unlock() }
        guard let h = open(), let st = try? prepare(h, "SELECT l.id,l.source,s.title,s.kind,l.key,l.text,l.character,l.lang,l.duration,l.tags,l.audio FROM lines l LEFT JOIN sources s ON s.id=l.source WHERE l.id=?") else { return nil }
        defer { sqlite3_finalize(st) }
        bind(st, [id])
        return sqlite3_step(st) == SQLITE_ROW ? record(st) : nil
    }

    /// Personnages d'une source (ou de toutes), du plus bavard au moins bavard.
    public static func characters(source: String? = nil, limit: Int = 60) -> [(String, Int)] {
        lock.lock(); defer { lock.unlock() }
        guard let h = open(), let st = try? prepare(h, "SELECT character, COUNT(*) n FROM lines WHERE character <> ''" + (source == nil ? "" : " AND source=?") + " GROUP BY character ORDER BY n DESC LIMIT \(limit)") else { return [] }
        defer { sqlite3_finalize(st) }
        if let source { bind(st, [source]) }
        var out: [(String, Int)] = []
        while sqlite3_step(st) == SQLITE_ROW { out.append((col(st, 0), Int(sqlite3_column_int64(st, 1)))) }
        return out
    }

    private static func record(_ st: OpaquePointer?) -> LineRecord {
        let a = col(st, 10)
        return LineRecord(id: sqlite3_column_int64(st, 0), source: col(st, 1), sourceTitle: col(st, 2), sourceKind: col(st, 3), key: col(st, 4),
                          text: col(st, 5), character: col(st, 6), lang: col(st, 7), duration: sqlite3_column_double(st, 8),
                          tags: col(st, 9).split(separator: ",").map(String.init),
                          audio: a.isEmpty ? nil : (a.hasPrefix("/") ? a : Paths.lines.appendingPathComponent(a).path))
    }
}
