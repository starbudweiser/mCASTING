// mCASTING — import / export d'un projet en cours, au même format pour l'appli et pour tout agent (MCP) :
// « mcasting-project/1 ». La fusion est idempotente : réimporter met à jour sans jamais effacer un casting déjà fait.
import Foundation

public enum ProjectImport {
    public enum Mode: String { case merge, replace }

    public struct Report: Codable {
        public var project: String
        public var dry_run: Bool
        public var project_created: Bool
        public var created: [String] = []
        public var updated: [String] = []
        public var unchanged: [String] = []
        public var removed: [String] = []
        public var warnings: [String] = []
    }

    // MARK: format d'entrée (tolérant : tableau nu de personnages ou objet complet ; lignes en tableau ou par langue)
    struct Spec: Decodable {
        var format: String?
        var name: String?
        var lang: String?
        var languages: [String]?
        var folder: String?
        var characters: [Item]
        struct Item: Decodable {
            var id: String?
            var key: String?
            var name: String
            var role: String?
            var kind: String?
            var notes: String?
            var line_count: Int?
            var lines: Lines?
            var current_voice: Current?
        }
        struct Current: Decodable {
            var description: String?
            var engine: String?
            var samples: [Sample]?
            struct Sample: Decodable {
                var file: String
                var text: String?
            }
        }
        enum Lines: Decodable {
            case list([String]), byLang([String: [String]])
            init(from d: Decoder) throws {
                let c = try d.singleValueContainer()
                if let a = try? c.decode([String].self) { self = .list(a) } else { self = .byLang(try c.decode([String: [String]].self)) }
            }
        }
    }

    static func decode(_ data: Data) throws -> Spec {
        let dec = JSONDecoder()
        if let s = try? dec.decode(Spec.self, from: data) { return s }
        if let items = try? dec.decode([Spec.Item].self, from: data) { return Spec(format: nil, name: nil, lang: nil, languages: nil, folder: nil, characters: items) }
        throw NSError(domain: "mcasting", code: 20, userInfo: [NSLocalizedDescriptionKey: "Invalid import JSON. Call get_import_guide for the expected format."])
    }

    /// Applique l'import à `projects` (en mémoire). `projectName` sert si le JSON n'a pas de nom (tableau nu).
    public static func apply(_ data: Data, projectName: String? = nil, mode: Mode = .merge, dryRun: Bool = false, to projects: inout [Project]) throws -> Report {
        let spec = try decode(data)
        guard let name = (projectName?.isEmpty == false ? projectName : spec.name), !name.isEmpty else {
            throw NSError(domain: "mcasting", code: 21, userInfo: [NSLocalizedDescriptionKey: "Missing project name"])
        }
        // Langues : « languages » (principale en premier) ou « lang » seule ; codes ISO 639-1, inconnus ignorés (avertissement).
        let listed = (spec.languages ?? []).compactMap { Lang(rawValue: $0) }
        let lang = listed.first ?? Lang(rawValue: spec.lang ?? "") ?? .fr
        let langs = listed.isEmpty ? (spec.lang.flatMap { Lang(rawValue: $0) }.map { [$0] }) : listed
        var work = projects
        var created = false
        var pi = work.firstIndex { $0.id == name || $0.name.lowercased() == name.lowercased() }
        if pi == nil { work.append(Project(name: name, lang: lang, second: langs?.dropFirst().first, folder: spec.folder)); pi = work.count - 1; created = true }
        let i = pi!
        if let f = spec.folder, !f.isEmpty { work[i].folder = f }
        if !created, let ls = langs { work[i].setLanguages(listed.isEmpty ? [ls[0]] + work[i].languages.filter { $0 != ls[0] } : ls) }
        let plang = work[i].lang
        var rep = Report(project: work[i].name, dry_run: dryRun, project_created: created)
        for c in (spec.languages ?? []) + [spec.lang].compactMap({ $0 }) where Lang(rawValue: c) == nil { rep.warnings.append("unknown language code: \(c)") }
        for l in work[i].languages where !Languages.library.contains(l) { rep.warnings.append("the voice library cannot be made in \(l.english); it can only be heard by cloning") }
        var seen = Set<String>()

        for it in spec.characters {
            let k = (it.key ?? it.id).flatMap { $0.isEmpty ? nil : $0 }
            let ci = work[i].characters.firstIndex { c in
                (k != nil && c.key == k) || c.name.lowercased() == it.name.lowercased()
            }
            var lines: [String]? = nil
            var alt: [String: [String]]? = nil
            switch it.lines {
            case .list(let a): lines = a
            case .byLang(let m): lines = m[plang.rawValue] ?? m.values.first; alt = m.filter { !$0.value.isEmpty }   // toutes les langues, pour passer de l'une à l'autre
            case nil: break
            }
            let cur = it.current_voice.map { CurrentVoice(description: $0.description, engine: $0.engine, samples: ($0.samples ?? []).map { .init(file: $0.file, text: $0.text) }) }
            for s in cur?.samples ?? [] where !FileManager.default.fileExists(atPath: s.file) { rep.warnings.append("\(it.name): sample not found: \(s.file)") }
            if let ci {
                var c = work[i].characters[ci]; let before = c
                c.key = k ?? c.key; c.name = it.name
                if let r = it.role { c.role = r }
                if let kd = it.kind { c.kind = kd }
                if let n = it.notes { c.notes = n }
                if let n = it.line_count { c.lineCount = n }
                if let l = lines { c.lines = l }
                if let a = alt { c.altLines = a }
                if let cur { c.current = cur }
                if c == before { rep.unchanged.append(it.name) } else { work[i].characters[ci] = c; rep.updated.append(it.name) }
                seen.insert(c.id)
            } else {
                let c = Character(key: k, name: it.name, role: it.role ?? "", lines: lines ?? [], lineCount: it.line_count, notes: it.notes, current: cur)
                var c2 = c; c2.altLines = alt; c2.kind = it.kind
                work[i].characters.append(c2); rep.created.append(it.name); seen.insert(c.id)
            }
        }
        if mode == .replace {
            for c in work[i].characters where !seen.contains(c.id) { rep.removed.append(c.name) }
            work[i].characters.removeAll { !seen.contains($0.id) }
        }
        if !dryRun { projects = work }
        return rep
    }

    /// Exporte un projet dans le même format (casting compris), pour qu'un agent le relise ou le transmette.
    public static func export(_ p: Project, voices: [Voice]) -> Data {
        struct Out: Encodable {
            var format = "mcasting-project/1"; var name: String; var lang: String; var languages: [String]; var folder: String?
            var characters: [C]
            struct C: Encodable {
                var id: String?, name: String, role: String, notes: String?, line_count: Int?, lines: [String]
                var current_voice: Cur?; var cast: Cast?
                struct Cur: Encodable { var description: String?, engine: String?; var samples: [S]; struct S: Encodable { var file: String; var text: String? } }
                struct Cast: Encodable { var voice_id: String, voice_name: String?, style: String }
            }
        }
        let o = Out(name: p.name, lang: p.lang.rawValue, languages: p.languages.map(\.rawValue), folder: p.folder, characters: p.characters.map { c in
            .init(id: c.key, name: c.name, role: c.role, notes: c.notes, line_count: c.lineCount, lines: c.lines,
                  current_voice: c.current.map { .init(description: $0.description, engine: $0.engine, samples: $0.samples.map { .init(file: $0.file, text: $0.text) }) },
                  cast: c.voiceID.map { v in .init(voice_id: v, voice_name: voices.first { $0.id == v }?.name, style: c.style) })
        })
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? e.encode(o)) ?? Data()
    }

    public static let guide = """
    mCASTING — importing an in-progress project (format "mcasting-project/1")

    GOAL: give mCASTING the list of characters (and, if they exist, their current voices) of a project so the user can cast voices for it.
    Works with any agent: build the JSON below from the project's files (script, dialogue data, game manifests…), then call the import_project tool
    (project_json = the JSON text, or path = absolute path of a .json file you wrote). Use dry_run=true first to preview. Re-importing is safe:
    characters are matched by "id" (your stable identifier) then by name, new ones are added, existing ones updated, and a casting already done is never erased.

    SCHEMA
    {
      "format": "mcasting-project/1",
      "name": "Project name (required)",
      "languages": ["de", "en"],               // the project's voice languages, ISO 639-1, main one first (1 or 2). Call list_languages.
                                               // ("lang": "fr" alone is still accepted: main language only.)
      "folder": "/absolute/path/of/the/project" // where casting.json will be written (optional but recommended)
      "characters": [
        {
          "id": "hero",                         // stable identifier in the source project (recommended)
          "name": "Hero",                       // required
          "role": "young deadpan adventurer",   // short description of who they are and how they should sound
          "kind": "human" | "creature" | "animal", // optional; non-human characters get creature voices and generated cries
          "notes": "free text (age, accent, relationships…)",
          "line_count": 383,                    // total number of lines the character speaks (optional)
          "lines": ["a few representative lines", "…"]   // in the main language, or by language {"de": [...], "en": [...]} ; 5–20 varied lines are plenty
          "current_voice": {                    // only if the project already has a voice for this character
            "description": "how it was generated / what it sounds like",
            "engine": "qwen3-customvoice",
            "samples": [ { "file": "/absolute/path/to/sample.mp3", "text": "what is said in the sample" } ]
          }
        }
      ]
    }

    TIPS FOR THE AGENT
    - Prefer a file ("path") for big projects. Absolute paths only for "folder" and sample "file"s.
    - Pick lines that show the character's range (calm, angry, joking…). Keep texts exactly as spoken.
    - Do not invent characters; one entry per speaking character (narrator included if it speaks).
    - Next steps after import: search_voices → set_casting → preview_voice → write_casting (writes casting.json into "folder").
    - export_project returns a project in this same format, casting included.
    """
}
