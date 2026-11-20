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
    ["name": "create_project", "description": "Create a casting project. lang: fr or en. folder: where casting.json will be written.",
     "inputSchema": schema(["name": "Project name", "lang": "fr|en", "folder": "Absolute folder of the target project"], required: ["name"])],
    ["name": "add_characters", "description": "Add characters to a project. characters_json: JSON array of {name, role, lines[]}.",
     "inputSchema": schema(["project": "Project name or id", "characters_json": "JSON array"], required: ["project", "characters_json"])],
    ["name": "list_characters", "description": "List characters of a project with their cast voice.", "inputSchema": schema(["project": "Project name or id"], required: ["project"])],
    ["name": "search_voices", "description": "Search the voice library. Filters: gender (man|woman|child|animal|creature), age, pitch (low|medium|high), tone, species, text, lang (fr|en), limit.",
     "inputSchema": schema(["gender": "", "age": "", "pitch": "", "tone": "", "species": "", "text": "free text", "lang": "", "limit": "default 20"])],
    ["name": "set_casting", "description": "Assign a voice to a character (and an optional emotion style).",
     "inputSchema": schema(["project": "Project name or id", "character": "Character name or id", "voice_id": "Voice id", "style": "Emotion/delivery"], required: ["project", "character", "voice_id"])],
    ["name": "preview_voice", "description": "Generate a preview of a voice for a line (slow: runs the local TTS). Returns the audio path.",
     "inputSchema": schema(["voice_id": "Voice id", "text": "Line to speak", "lang": "fr|en", "style": "Emotion"], required: ["voice_id", "text"])],
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
    func s(_ k: String) -> String { (a[k] as? String) ?? "" }
    switch name {
    case "list_projects":
        return json(DataStore.projects().map { ["id": $0.id, "name": $0.name, "lang": $0.lang.rawValue, "characters": "\($0.characters.count)", "cast": "\($0.castCount)"] })
    case "create_project":
        let p = Project(name: s("name"), lang: Lang(rawValue: s("lang")) ?? .fr, folder: s("folder").isEmpty ? nil : s("folder"))
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
            (s("lang").isEmpty || v.samples[s("lang")] != nil)
        }.prefix(Int(s("limit")) ?? 20)
        return json(out.map { ["id": $0.id, "name": $0.name, "gender": $0.gender.rawValue, "age": $0.age, "pitch": $0.pitch, "tone": $0.tone, "recipe": $0.recipe] })
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
        return try LibraryGenerator.preview(voice: v, text: s("text"), lang: Lang(rawValue: s("lang")) ?? .fr, style: s("style")).path
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
        reply(id, result: ["protocolVersion": "2024-11-05", "capabilities": ["tools": [:]], "serverInfo": ["name": "mcasting", "version": "1.0.0"]])
    case "tools/list": reply(id, result: ["tools": tools])
    case "tools/call":
        let p = m["params"] as? [String: Any] ?? [:]
        do { reply(id, result: text(try call(p["name"] as? String ?? "", p["arguments"] as? [String: Any] ?? [:]))) }
        catch { var r = text(error.localizedDescription); r["isError"] = true; reply(id, result: r) }
    case "ping": reply(id, result: [:])
    default: if id != nil { reply(id, error: "Method not found") }
    }
}
