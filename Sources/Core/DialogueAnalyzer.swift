// mCASTING — analyse des personnages par une IA de texte locale (Ollama, LM Studio ou tout serveur compatible OpenAI),
// et lecture de répliques en CSV ou en texte « NOM : réplique ».
import Foundation

public enum DialogueAnalyzer {
    public struct Server: Hashable { public let name: String; public let base: String; public var models: [String] }
    public static let known = [("Ollama", "http://127.0.0.1:11434"), ("LM Studio", "http://127.0.0.1:1234")]

    static func request(_ url: String, body: [String: Any]? = nil, timeout: TimeInterval) -> Data? {
        guard let u = URL(string: url) else { return nil }
        var r = URLRequest(url: u); r.timeoutInterval = timeout
        if let body { r.httpMethod = "POST"; r.setValue("application/json", forHTTPHeaderField: "Content-Type"); r.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        let sem = DispatchSemaphore(value: 0); var out: Data?
        URLSession.shared.dataTask(with: r) { d, resp, _ in if (resp as? HTTPURLResponse)?.statusCode == 200 { out = d }; sem.signal() }.resume()
        sem.wait(); return out
    }

    /// Serveurs de texte locaux joignables et leurs modèles (API /v1/models, commune à Ollama et LM Studio).
    public static func discover(extra: String? = ProcessInfo.processInfo.environment["MCASTING_LLM_BASE"]) -> [Server] {
        var list = known; if let e = extra { list.insert(("Local", e), at: 0) }
        return list.compactMap { n, b in
            guard let d = request(b + "/v1/models", timeout: 1.5), let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
                  let arr = o["data"] as? [[String: Any]] else { return nil }
            let audio = ["embed", "tts", "audio", "voice", "whisper", "chatterbox", "fish", "kokoro", "asr", "speech", "music", "sfx"]
            let ms = arr.compactMap { $0["id"] as? String }.filter { id in !audio.contains { id.lowercased().contains($0) } }
            return ms.isEmpty ? nil : Server(name: n, base: b, models: ms)
        }
    }
    /// Modèle conseillé : un modèle d'instructions récent et moyen, sinon le premier.
    public static func preferred(_ s: Server) -> String {
        for k in ["qwen3", "qwen2.5", "mistral", "llama", "gemma"] {
            let c = s.models.filter { $0.lowercased().contains(k) }
            if let m = c.first(where: { $0.lowercased().contains("instruct") }) ?? c.first { return m }
        }
        return s.models[0]
    }

    public struct Result: Decodable { public var id: String; public var gender: String?; public var age: String?; public var kind: String?; public var voice: String? }

    /// Analyse les personnages par lots ; renvoie, pour chacun, genre, âge, type et une description de voix en anglais.
    public static func analyze(_ chars: [Character], server: Server, model: String, progress: (Int, Int) -> Void) throws -> [Result] {
        var all: [Result] = []
        let batches = stride(from: 0, to: chars.count, by: 12).map { Array(chars[$0..<min($0 + 12, chars.count)]) }
        for (n, b) in batches.enumerated() {
            progress(n, batches.count)
            let items = b.map { c -> [String: Any] in ["id": c.id, "name": c.name, "role": c.role, "notes": c.notes ?? "", "lines": Array(c.lines.prefix(4))] }
            let input = String(data: (try? JSONSerialization.data(withJSONObject: items)) ?? Data(), encoding: .utf8) ?? "[]"
            let prompt = """
            You cast voices for characters of a game or video. For each character below, infer from name, role, notes and lines:
            gender (man, woman, child, none), age (child, young, adult, senior), kind (human, creature, animal),
            voice (one short English sentence describing how the voice should sound: timbre, pitch, pace, attitude).
            Answer ONLY with JSON: {"characters":[{"id":"...","gender":"...","age":"...","kind":"...","voice":"..."}]}
            Characters: \(input)
            """
            let body: [String: Any] = ["model": model, "temperature": 0.2, "stream": false,
                                       "messages": [["role": "user", "content": prompt]]]
            guard let d = request(server.base + "/v1/chat/completions", body: body, timeout: 300),
                  let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
                  let text = ((o["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String
            else { throw EngineError.failed("No answer from \(server.name) (\(model))") }
            // Retire un éventuel raisonnement <think>…</think> et prend le premier objet JSON.
            var t = text
            if let r = t.range(of: "</think>") { t = String(t[r.upperBound...]) }
            // Chaque personnage est lu à part : un petit modèle ferme parfois mal le JSON global.
            let re = try NSRegularExpression(pattern: #"\{[^{}]*"id"[^{}]*\}"#)
            let rs = re.matches(in: t, range: NSRange(t.startIndex..., in: t)).compactMap { m -> Result? in
                guard let r = Range(m.range, in: t) else { return nil }
                return try? JSONDecoder().decode(Result.self, from: Data(t[r].utf8))
            }
            if rs.isEmpty { throw EngineError.failed("Unreadable answer from \(model)") }
            all += rs
        }
        progress(batches.count, batches.count)
        return all
    }

    /// Applique l'analyse : type, et description de voix dans le rôle s'il est vide, sinon dans les notes. Le casting n'est pas touché.
    public static func apply(_ rs: [Result], to c: inout Character) {
        guard let r = rs.first(where: { $0.id == c.id }) else { return }
        if let k = r.kind?.lowercased(), ["human", "creature", "animal"].contains(k) { c.kind = k }
        let hint = [r.gender == "none" ? nil : r.gender, r.age].compactMap { $0 }.joined(separator: ", ")
        let voice = [hint, r.voice ?? ""].filter { !$0.isEmpty }.joined(separator: " — ")
        guard !voice.isEmpty else { return }
        if c.role.trimmingCharacters(in: .whitespaces).isEmpty { c.role = voice }
        else if !(c.notes ?? "").contains(voice) { c.notes = ((c.notes ?? "").isEmpty ? "" : (c.notes ?? "") + "\n") + "Voice: " + voice }
    }

    // MARK: CSV et texte
    /// Convertit un CSV (personnage ; réplique ; langue facultative) ou un texte « NOM : réplique » au format d'import mCASTING.
    public static func convert(_ text: String, ext: String) -> Data? {
        var order: [String] = [], lines: [String: [String: [String]]] = [:]
        func add(_ name: String, _ line: String, _ lang: String) {
            let n0 = name.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\""))),
                l = line.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"")))
            guard !n0.isEmpty, !l.isEmpty, n0.count < 60 else { return }
            let n = n0 == n0.uppercased() ? n0.capitalized : n0          // « LINA » → « Lina »
            if lines[n] == nil { order.append(n); lines[n] = [:] }
            lines[n]![lang, default: []].append(l)
        }
        let rows = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if ext == "csv" || ext == "tsv" {
            let sep: Swift.Character = rows.first.map { r in r.contains(";") ? ";" : (r.contains("\t") ? "\t" : ",") } ?? ";"
            for (i, r) in rows.enumerated() {
                let f = r.split(separator: sep, maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
                guard f.count >= 2 else { continue }
                if i == 0, ["personnage", "character", "name", "nom", "personaje", "personaggio"].contains(f[0].lowercased().trimmingCharacters(in: .whitespaces)) { continue }
                let lang = f.count > 2 ? f[2].lowercased().trimmingCharacters(in: .whitespaces) : "default"
                add(f[0], f[1], Lang(rawValue: lang)?.rawValue ?? "default")
            }
        } else {
            for r in rows { if let c = r.firstIndex(of: ":") { add(String(r[..<c]), String(r[r.index(after: c)...]), "default") } }
        }
        guard !order.isEmpty else { return nil }
        let chars: [[String: Any]] = order.map { n in
            let m = lines[n]!
            let ls: Any = m.keys.contains("default") || m.count == 1 ? (m["default"] ?? m.values.first!) : m
            return ["id": n.lowercased(), "name": n, "lines": ls]
        }
        return try? JSONSerialization.data(withJSONObject: ["format": "mcasting-project/1", "characters": chars])
    }
}
