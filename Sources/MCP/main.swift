// mcasting-mcp — serveur MCP (stdio, JSON-RPC 2.0) : un agent crée des projets, ajoute des personnages, cherche des voix
// dans la bibliothèque et écrit le casting validé dans le projet cible (casting.json). Mêmes fichiers que l'appli.
import Foundation

func reply(_ id: Any?, result: Any? = nil, error: String? = nil) {
    var m: [String: Any] = ["jsonrpc": "2.0"]
    if let id { m["id"] = id }
    if let error { m["error"] = ["code": -32000, "message": error] } else { m["result"] = result ?? [:] }
    if let d = try? JSONSerialization.data(withJSONObject: m), let s = String(data: d, encoding: .utf8) { print(s); fflush(stdout) }
}
func text(_ s: String) -> [String: Any] { ["content": [["type": "text", "text": s]]] }
func json<T: Encodable>(_ v: T) -> String {
    let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
    return (try? String(data: e.encode(v), encoding: .utf8)) ?? "{}"
}
func schema(_ props: [String: String], required: [String] = []) -> [String: Any] {
    ["type": "object", "properties": props.mapValues { ["type": "string", "description": $0] }, "required": required]
}

let tools: [[String: Any]] = [
    ["name": "list_projects", "description": "List casting projects with progress.", "inputSchema": schema([:])],
    ["name": "list_languages", "description": "Voice languages (ISO 639-1): those the voice library can be made in, those any voice can be heard in by cloning its timbre (installed models), and each project's languages.", "inputSchema": schema([:])],
    ["name": "create_project", "description": "Create a casting project. languages: 1 or 2 ISO 639-1 codes, main language first (e.g. \"de,en\"); call list_languages. The library samples of these languages are computed by the app. folder: where casting.json will be written.",
     "inputSchema": schema(["name": "Project name", "languages": "Comma-separated codes, main first (e.g. de,en). 'lang' alone is still accepted.", "folder": "Absolute folder of the target project"], required: ["name"])],
    ["name": "set_project_languages", "description": "Change a project's languages (1 or 2 ISO 639-1 codes, main first). Missing library samples are computed by the app.",
     "inputSchema": schema(["project": "Project name or id", "languages": "Comma-separated codes, main first"], required: ["project", "languages"])],
    ["name": "add_characters", "description": "Add characters to a project. characters_json: JSON array of {name, role, lines[]}.",
     "inputSchema": schema(["project": "Project name or id", "characters_json": "JSON array"], required: ["project", "characters_json"])],
    ["name": "list_characters", "description": "List characters of a project with their cast voice.", "inputSchema": schema(["project": "Project name or id"], required: ["project"])],
    ["name": "search_voices", "description": "Search the voice library. Filters: gender (man|woman|child|animal|creature), age, pitch (low|medium|high), tone, species, text, lang (ISO 639-1: voices with a ready sample in that language), limit. Cloned voices: cloned=true, source (title of the game, film or series), source_kind (game|film|series|other), character (original character), tags (comma-separated).",
     "inputSchema": schema(["gender": "", "age": "", "pitch": "", "tone": "", "species": "", "text": "free text", "lang": "", "limit": "default 20", "cloned": "true = cloned voices only", "source": "", "source_kind": "", "character": "", "tags": ""])],
    ["name": "update_voice", "description": "Complete the record of a cloned voice: name, character (original character), source_kind (game|film|series|other), source (title), gender, tags (comma-separated, replaces the list).",
     "inputSchema": schema(["voice_id": "Voice id", "name": "", "character": "", "source_kind": "", "source": "", "gender": "", "tags": ""], required: ["voice_id"])],
    ["name": "set_casting", "description": "Assign a voice to a character (and an optional emotion style).",
     "inputSchema": schema(["project": "Project name or id", "character": "Character name or id", "voice_id": "Voice id", "style": "Emotion/delivery"], required: ["project", "character", "voice_id"])],
    ["name": "preview_voice", "description": "Generate a preview of a voice for a line (slow: runs the local TTS). Returns the audio path.",
     "inputSchema": schema(["voice_id": "Voice id", "text": "Line to speak", "lang": "ISO 639-1 code of the language to speak (any code from list_languages: a voice can be heard in a language it has no sample in, by cloning its timbre; a slight accent may remain)", "style": "Emotion (only used when expressive is true)", "timbre_lang": "optional: language of the sample whose timbre is cloned (default: the sample of lang if it exists, else the project's main language)", "expressive": "true = apply the emotion (voice timbre approximate); default false = exact timbre of the library sample, no emotion"], required: ["voice_id", "text"])],
    ["name": "get_import_guide", "description": "START HERE to bring an existing project into mCASTING: returns the import format (mcasting-project/1) and how to build it from the project's files. Works with any agent.", "inputSchema": schema([:])],
    ["name": "import_project", "description": "Import (or update) an in-progress project: its characters, sample lines and current voices. Provide project_json (JSON text) OR path (absolute path of a .json file). mode: merge (default, never erases an existing casting) or replace. dry_run: true to preview only. Call get_import_guide first for the format.",
     "inputSchema": schema(["project_json": "Project JSON text (format mcasting-project/1, or a bare array of characters)", "path": "Absolute path of a JSON file (alternative to project_json)", "name": "Project name (needed only if the JSON has none)", "mode": "merge|replace", "dry_run": "true to preview without saving"])],
    ["name": "export_project", "description": "Export a project (characters, current voices, casting) as JSON in the same format as import_project.", "inputSchema": schema(["project": "Project name or id"], required: ["project"])],
    ["name": "list_line_sources", "description": "Line database: list the sources (games, films, series) whose lines were received (from mTALKIE or any tool dropping a package in the Inbox), with line counts, languages and top speakers.", "inputSchema": schema([:])],
    ["name": "search_lines", "description": "Search the line database to pick lines for characters. text: words (prefix match, accents ignored). Filters: source (id or title, comma-separated), character (speaker in the source), lang (ISO 639-1), tags (comma-separated: laugh, scream, insult, greeting, question, threat, exclamation), min_duration, max_duration (seconds), limit (default 30, max 200).",
     "inputSchema": schema(["text": "Words to find", "source": "Source id(s) or title(s)", "character": "Speaker", "lang": "", "tags": "", "min_duration": "", "max_duration": "", "limit": ""])],
    ["name": "get_line", "description": "Get one line of the database by id (text, source, speaker, tags, audio path).", "inputSchema": schema(["id": "Line id"], required: ["id"])],
    ["name": "assign_line", "description": "Assign a database line to a project character. mode: inspiration (default: the line is rewritten in 'text' before being spoken — required for published videos or games, since game/film lines and actors' voices are copyrighted) or original (verbatim, private tests only). text: the line the character will say (required for inspiration). emotion: optional delivery.",
     "inputSchema": schema(["project": "Project name or id", "character": "Character name or id", "id": "Line id", "mode": "inspiration|original", "text": "Rewritten line to speak", "emotion": "Delivery"], required: ["project", "character", "id"])],
    ["name": "unassign_line", "description": "Remove an assigned line from a character (assigned line id from list_characters).",
     "inputSchema": schema(["project": "Project name or id", "character": "Character name or id", "assigned_id": "Assigned line id"], required: ["project", "character", "assigned_id"])],
    ["name": "write_casting", "description": "Write casting.json into the project's folder.", "inputSchema": schema(["project": "Project name or id"], required: ["project"])],
]

func findProject(_ key: String, in p: [Project]) -> Int? { p.firstIndex { $0.id == key || $0.name.lowercased() == key.lowercased() } }

func logCall(_ name: String, _ a: [String: Any]) {
    let f = DateFormatter(); f.dateFormat = "HH:mm"
    let arg = (a["name"] ?? a["project"] ?? a["text"] ?? a["voice_id"] ?? "") as? String ?? ""
    let line = "\(f.string(from: Date()))  \(name)  \(arg.prefix(40))\n"
    let url = Paths.home.appendingPathComponent("mcp.log")
    if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close() }
    else { try? line.write(to: url, atomically: true, encoding: .utf8) }
}

func call(_ name: String, _ a: [String: Any]) throws -> String {
    Paths.prepare(); logCall(name, a)
    InboxImporter.processAll()          // paquets déposés pendant que l'appli était fermée
    func s(_ k: String) -> String { (a[k] as? String) ?? (a[k].map { "\($0)" } ?? "") }
    switch name {
    case "list_projects":
        return json(DataStore.projects().map { ["id": $0.id, "name": $0.name, "lang": $0.lang.rawValue, "languages": $0.languages.map(\.rawValue).joined(separator: ","), "characters": "\($0.characters.count)", "cast": "\($0.castCount)"] })
    case "list_languages":
        struct L: Encodable { var code: String, name: String, native: String }
        struct Out: Encodable { var library: [L]; var listen: [L]; var projects: [String: [String]]; var note: String }
        let f: (Lang) -> L = { L(code: $0.rawValue, name: $0.english, native: $0.native) }
        return json(Out(library: Languages.library.map(f), listen: Languages.listenable().map(f),
                        projects: Dictionary(DataStore.projects().map { ($0.name, $0.languages.map(\.rawValue)) }, uniquingKeysWith: { a, _ in a }),
                        note: "Project languages must be library languages. Any voice can be heard in a 'listen' language by cloning its timbre; a slight accent may remain."))
    case "create_project", "set_project_languages":
        let raw = s("languages").isEmpty ? s("lang") : s("languages")
        let codes = raw.split { $0 == "," || $0 == " " }.map(String.init)
        let ls = codes.compactMap { Lang(rawValue: $0) }
        if let bad = codes.first(where: { Lang(rawValue: $0) == nil }) { throw NSError(domain: "mcasting", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unknown language code: \(bad). Call list_languages."]) }
        if let no = ls.first(where: { !Languages.library.contains($0) }) { throw NSError(domain: "mcasting", code: 4, userInfo: [NSLocalizedDescriptionKey: "The voice library cannot be made in \(no.english). Call list_languages."]) }
        if name == "set_project_languages" {
            guard !ls.isEmpty else { throw NSError(domain: "mcasting", code: 4, userInfo: [NSLocalizedDescriptionKey: "languages is required"]) }
            var out: Project?
            try DataStore.updateProjects { all in
                guard let i = findProject(s("project"), in: all) else { throw NSError(domain: "mcasting", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown project"]) }
                all[i].setLanguages(ls); out = all[i]
            }
            return "Languages: " + (out?.languages.map(\.rawValue).joined(separator: ", ") ?? "")
        }
        let main = ls.first ?? Lang.system
        let p = Project(name: s("name"), lang: Languages.library.contains(main) ? main : .en, second: ls.dropFirst().first, folder: s("folder").isEmpty ? nil : s("folder"))
        try DataStore.updateProjects { $0.append(p) }
        return json(p)
    case "add_characters":
        struct C: Decodable { var name: String; var role: String?; var lines: [String]? }
        let cs = try JSONDecoder().decode([C].self, from: Data(s("characters_json").utf8))
        var added = 0
        try DataStore.updateProjects { all in
            guard let i = findProject(s("project"), in: all) else { throw NSError(domain: "mcasting", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown project"]) }
            for c in cs where !all[i].characters.contains(where: { $0.name.lowercased() == c.name.lowercased() }) {
                all[i].characters.append(Character(name: c.name, role: c.role ?? "", lines: c.lines ?? [])); added += 1
            }
        }
        return "Added \(added) character(s)."
    case "list_characters":
        guard let p = DataStore.projects().first(where: { $0.id == s("project") || $0.name.lowercased() == s("project").lowercased() }) else { throw NSError(domain: "mcasting", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown project"]) }
        return json(p.characters)
    case "search_voices":
        let vs = DataStore.voices()
        let q = s("text").lowercased()
        let out = vs.filter { v in
            (s("gender").isEmpty || v.gender.rawValue == s("gender")) && (s("age").isEmpty || v.age == s("age")) &&
            (s("pitch").isEmpty || v.pitch == s("pitch")) && (s("tone").isEmpty || v.tone.contains(s("tone"))) &&
            (s("species").isEmpty || v.species == s("species")) &&
            (q.isEmpty || (v.name + " " + v.recipe + " " + v.tone + " " + (v.species ?? "")).lowercased().contains(q)) &&
            (s("lang").isEmpty || v.samples[s("lang")] != nil) &&
            (s("cloned") != "true" || v.isClone) &&
            (s("source").isEmpty || (v.originTitle ?? "").lowercased().contains(s("source").lowercased())) &&
            (s("source_kind").isEmpty || v.originKind == s("source_kind")) &&
            (s("character").isEmpty || (v.character ?? "").lowercased().contains(s("character").lowercased())) &&
            s("tags").split(separator: ",").allSatisfy { t in (v.tags ?? []).contains { $0.lowercased() == t.trimmingCharacters(in: .whitespaces).lowercased() } }
        }.prefix(Int(s("limit")) ?? 20)
        return json(out.map { v -> [String: String] in
            var d = ["id": v.id, "name": v.name, "gender": v.gender.rawValue, "age": v.age, "pitch": v.pitch, "tone": v.tone, "recipe": v.recipe]
            if v.isClone { d["cloned"] = "true"; d["character"] = v.character ?? ""; d["source"] = v.originTitle ?? ""; d["source_kind"] = v.originKind; d["tags"] = (v.tags ?? []).joined(separator: ","); d["ref_text"] = v.refText ?? "" }
            return d
        })
    case "update_voice":
        try VoiceCloning.updateInfo(id: s("voice_id")) { v in
            if !s("name").isEmpty { v.name = s("name") }
            if a["character"] != nil { v.character = s("character").isEmpty ? nil : s("character") }
            if !s("source_kind").isEmpty { v.sourceKind = s("source_kind") }
            if a["source"] != nil { v.sourceTitle = s("source").isEmpty ? nil : s("source") }
            if let g = Gender(rawValue: s("gender")) { v.gender = g }
            if a["tags"] != nil { v.tags = s("tags").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        }
        return "OK"
    case "set_casting":
        try DataStore.updateProjects { all in
            guard let i = findProject(s("project"), in: all), let j = all[i].characters.firstIndex(where: { $0.id == s("character") || $0.name.lowercased() == s("character").lowercased() })
            else { throw NSError(domain: "mcasting", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown project or character"]) }
            guard DataStore.voices().contains(where: { $0.id == s("voice_id") }) else { throw NSError(domain: "mcasting", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unknown voice"]) }
            all[i].characters[j].voiceID = s("voice_id"); if !s("style").isEmpty { all[i].characters[j].style = s("style") }
        }
        return "OK"
    case "preview_voice":
        guard let v = DataStore.voices().first(where: { $0.id == s("voice_id") }) else { throw NSError(domain: "mcasting", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unknown voice"]) }
        if !s("lang").isEmpty, Lang(rawValue: s("lang")) == nil { throw NSError(domain: "mcasting", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unknown language code. Call list_languages."]) }
        return try LibraryGenerator.listen(voice: v, text: s("text"), lang: Lang(rawValue: s("lang")) ?? .fr, style: s("style"), expressive: (a["expressive"] as? Bool) ?? (s("expressive") == "true"), prefer: Lang(rawValue: s("timbre_lang"))).path
    case "get_import_guide": return ProjectImport.guide
    case "import_project":
        var data = Data(s("project_json").utf8)
        if data.isEmpty, !s("path").isEmpty { data = try Data(contentsOf: URL(fileURLWithPath: s("path"))) }
        guard !data.isEmpty else { throw NSError(domain: "mcasting", code: 22, userInfo: [NSLocalizedDescriptionKey: "Provide project_json or path. Call get_import_guide."]) }
        let dry = (a["dry_run"] as? Bool) ?? ["true", "1", "yes"].contains(s("dry_run").lowercased())
        let mode = ProjectImport.Mode(rawValue: s("mode")) ?? .merge
        var report: ProjectImport.Report?
        if dry { var tmp = DataStore.projects(); report = try ProjectImport.apply(data, projectName: s("name"), mode: mode, dryRun: true, to: &tmp) }
        else { try DataStore.updateProjects { report = try ProjectImport.apply(data, projectName: s("name"), mode: mode, dryRun: false, to: &$0) } }
        return json(report!)
    case "export_project":
        guard let p = DataStore.projects().first(where: { $0.id == s("project") || $0.name.lowercased() == s("project").lowercased() }) else { throw NSError(domain: "mcasting", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown project"]) }
        return String(decoding: ProjectImport.export(p, voices: DataStore.voices()), as: UTF8.self)
    case "list_line_sources":
        struct Src: Encodable { var id: String, title: String, kind: String, lines: Int, languages: [String], top_speakers: [String] }
        return json(LinesStore.sources().map { Src(id: $0.id, title: $0.title, kind: $0.kind, lines: $0.count, languages: $0.langs,
                                                   top_speakers: LinesStore.characters(source: $0.id, limit: 12).map { "\($0.0) (\($0.1))" }) })
    case "search_lines":
        var q = LinesStore.Query()
        q.text = s("text"); q.character = s("character"); q.lang = s("lang").lowercased()
        q.tags = s("tags").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let srcs = LinesStore.sources()
        q.sources = s("source").split(separator: ",").compactMap { k in
            let k = k.trimmingCharacters(in: .whitespaces).lowercased()
            return srcs.first { $0.id == k || $0.title.lowercased() == k || $0.title.lowercased().contains(k) }?.id
        }
        if !s("source").isEmpty, q.sources.isEmpty { throw NSError(domain: "mcasting", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unknown source. Call list_line_sources."]) }
        q.minDuration = Double(s("min_duration")); q.maxDuration = Double(s("max_duration"))
        q.limit = min(Int(s("limit")) ?? 30, 200)
        let r = LinesStore.search(q)
        struct Out: Encodable { var total: Int; var shown: Int; var lines: [LineRecord] }
        return json(Out(total: r.total, shown: r.lines.count, lines: r.lines))
    case "get_line":
        guard let id = Int64(s("id")), let r = LinesStore.get(id) else { throw NSError(domain: "mcasting", code: 6, userInfo: [NSLocalizedDescriptionKey: "Unknown line id"]) }
        return json(r)
    case "assign_line", "unassign_line":
        var out = AssignedLine(text: "")
        try DataStore.updateProjects { all in
            guard let i = findProject(s("project"), in: all), let j = all[i].characters.firstIndex(where: { $0.id == s("character") || $0.name.lowercased() == s("character").lowercased() })
            else { throw NSError(domain: "mcasting", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown project or character"]) }
            if name == "unassign_line" { all[i].characters[j].assigned?.removeAll { $0.id == s("assigned_id") }; return }
            guard let id = Int64(s("id")), let r = LinesStore.get(id) else { throw NSError(domain: "mcasting", code: 6, userInfo: [NSLocalizedDescriptionKey: "Unknown line id"]) }
            let mode = s("mode") == "original" ? "original" : "inspiration"
            out = AssignedLine(record: r, mode: mode, text: s("text"), emotion: s("emotion").isEmpty ? nil : s("emotion"))
            all[i].characters[j].assigned = (all[i].characters[j].assigned ?? []) + [out]
        }
        return name == "unassign_line" ? "OK" : json(out) + (out.mode == "inspiration" && s("text").isEmpty ? "\nNote: mode inspiration without 'text' keeps the original wording; rewrite it before any public use." : "")
    case "write_casting":
        guard let p = DataStore.projects().first(where: { $0.id == s("project") || $0.name.lowercased() == s("project").lowercased() }) else { throw NSError(domain: "mcasting", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown project"]) }
        return try CastingExport.write(p, voices: DataStore.voices()).path
    default: throw NSError(domain: "mcasting", code: 9, userInfo: [NSLocalizedDescriptionKey: "Unknown tool"])
    }
}

while let line = readLine() {
    guard let d = line.data(using: .utf8), let m = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { continue }
    let id = m["id"], method = m["method"] as? String ?? ""
    switch method {
    case "initialize":
        reply(id, result: ["protocolVersion": "2024-11-05", "capabilities": ["tools": [:], "prompts": [:], "resources": [:]], "serverInfo": ["name": "mcasting", "version": "1.0.0"]])
    case "tools/list": reply(id, result: ["tools": tools])
    case "tools/call":
        let p = m["params"] as? [String: Any] ?? [:]
        do { reply(id, result: text(try call(p["name"] as? String ?? "", p["arguments"] as? [String: Any] ?? [:]))) }
        catch { var r = text(error.localizedDescription); r["isError"] = true; reply(id, result: r) }
    case "prompts/list":
        reply(id, result: ["prompts": [["name": "import_project", "description": "Import the current project (characters and lines) into mCASTING to cast its voices."]]])
    case "prompts/get":
        reply(id, result: ["description": "Import a project into mCASTING", "messages": [["role": "user", "content": ["type": "text", "text": "Import the project in the current folder into mCASTING so I can cast its voices. Follow this guide, build the JSON from the project's files, run import_project with dry_run first, then for real.\n\n" + ProjectImport.guide]]]])
    case "resources/list":
        reply(id, result: ["resources": [["uri": "mcasting://import-guide", "name": "Import guide", "mimeType": "text/plain"]]])
    case "resources/read":
        reply(id, result: ["contents": [["uri": "mcasting://import-guide", "mimeType": "text/plain", "text": ProjectImport.guide]]])
    case "ping": reply(id, result: [:])
    default: if id != nil { reply(id, error: "Method not found") }
    }
}
