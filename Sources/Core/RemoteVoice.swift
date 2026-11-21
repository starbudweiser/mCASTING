// mCASTING — voix fabriquées ailleurs que sur ce Mac :
// • un serveur du réseau compatible OpenAI (mlx-audio server, LocalAI, Kokoro-FastAPI…) ;
// • un service en ligne payant (ElevenLabs), avec coût annoncé avant chaque génération.
import Foundation
import Security

// MARK: Trousseau
public enum Keychain {
    public static func get(_ account: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "mCASTING",
                                kSecAttrAccount as String: account, kSecReturnData as String: true]
        var r: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess, let d = r as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    public static func set(_ account: String, _ value: String?) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "mCASTING", kSecAttrAccount as String: account]
        SecItemDelete(q as CFDictionary)
        guard let v = value, !v.isEmpty else { return }
        var a = q; a[kSecValueData as String] = Data(v.utf8)
        SecItemAdd(a as CFDictionary, nil)
    }
}

enum HTTP {
    static func call(_ url: String, method: String = "GET", headers: [String: String] = [:], json: [String: Any]? = nil, timeout: TimeInterval = 30) throws -> Data {
        guard let u = URL(string: url) else { throw EngineError.failed("Invalid address: \(url)") }
        var r = URLRequest(url: u); r.httpMethod = method; r.timeoutInterval = timeout
        headers.forEach { r.setValue($1, forHTTPHeaderField: $0) }
        if let json { r.setValue("application/json", forHTTPHeaderField: "Content-Type"); r.httpBody = try JSONSerialization.data(withJSONObject: json) }
        let sem = DispatchSemaphore(value: 0); var out: Data?, err: String?
        URLSession.shared.dataTask(with: r) { d, resp, e in
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if let e { err = e.localizedDescription } else if code != 200 { err = "HTTP \(code): " + String(decoding: (d ?? Data()).prefix(300), as: UTF8.self) } else { out = d }
            sem.signal()
        }.resume()
        sem.wait()
        if let out { return out }
        throw EngineError.failed(err ?? "No answer")
    }
    static func object(_ d: Data) -> [String: Any] { (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] ?? [:] }
    /// Audio reçu (mp3, wav…) → .m4a dans `out`.
    static func saveAudio(_ d: Data, ext: String, to out: URL) throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("mcasting-dl-\(UUID().uuidString).\(ext)")
        try d.write(to: tmp); defer { try? FileManager.default.removeItem(at: tmp) }
        try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: out)
        try Engine.run(URL(fileURLWithPath: "/usr/bin/afconvert"), ["-f", "m4af", "-d", "aac", tmp.path, out.path])
    }
}

// MARK: Serveur du réseau (API OpenAI de synthèse vocale)
public enum VoiceServer {
    public static var url: String? { SetupState.load().serverURL }
    static var headers: [String: String] { Keychain.get("server").map { ["Authorization": "Bearer " + $0] } ?? [:] }
    static func base(_ u: String) -> String { var b = u.trimmingCharacters(in: .whitespaces); while b.hasSuffix("/") { b.removeLast() }; return b.hasSuffix("/v1") ? b : b + "/v1" }

    /// Modèles que mlx-audio server charge à la demande (il ne liste que ceux déjà chargés).
    public static let suggested = ["mlx-community/Qwen3-TTS-12Hz-1.7B-VoiceDesign-8bit", "mlx-community/Kokoro-82M-bf16"]
    public static func models(_ u: String) throws -> [String] {
        let o = HTTP.object(try HTTP.call(base(u) + "/models", headers: headers, timeout: 5))
        let listed = (o["data"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
        return listed.isEmpty ? suggested : listed
    }
    /// Voix toutes prêtes d'un modèle (Kokoro et autres) ; liste vide pour les modèles sans voix fixes.
    public static func voices(_ u: String, model: String) -> [String] {
        let q = model.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? model
        guard let d = try? HTTP.call(base(u) + "/audio/voices?model=" + q, headers: headers, timeout: 20) else { return [] }
        let o = HTTP.object(d)
        let arr = (o["data"] as? [Any]) ?? (o["voices"] as? [Any]) ?? []
        return arr.compactMap { ($0 as? String) ?? (($0 as? [String: Any])?["id"] as? String) ?? (($0 as? [String: Any])?["name"] as? String) }
    }
    /// Le modèle qui sait créer une voix d'après sa description (bibliothèque fabriquée sur le serveur).
    public static func designModel(in models: [String]) -> String? { models.first { $0.lowercased().contains("voicedesign") } }

    @discardableResult
    public static func speak(_ u: String, model: String, text: String, lang: Lang, voice: String? = nil, instruct: String? = nil, to out: URL) throws -> TimeInterval {
        let t0 = Date()
        var body: [String: Any] = ["model": model, "input": text, "response_format": "wav",
                                   "lang_code": model.lowercased().contains("qwen3") ? lang.qwen : (model.lowercased().contains("kokoro") ? (lang.kokoro ?? "a") : lang.rawValue)]
        if let voice { body["voice"] = voice }
        if let instruct { body["instruct"] = instruct; body["instructions"] = instruct }
        let d = try HTTP.call(base(u) + "/audio/speech", method: "POST", headers: headers, json: body, timeout: 600)
        try HTTP.saveAudio(d, ext: "wav", to: out)
        return Date().timeIntervalSince(t0)
    }

    /// Ajoute les voix toutes prêtes d'un modèle du serveur à la bibliothèque, avec un extrait dans chaque langue des projets, fabriqué sur le serveur.
    public static func importVoices(_ u: String, model: String, progress: (Int, Int) -> Void) throws -> Int {
        var lib = try LibraryGenerator.ensureCatalog()
        let names = voices(u, model: model)
        let host = URL(string: u)?.host ?? "server"
        for (i, n) in names.enumerated() {
            progress(i, names.count)
            let id = "srv-\(host)-\(n)".replacingOccurrences(of: " ", with: "-")
            var v = lib.first { $0.id == id } ?? Voice(id: id, name: n, gender: guessGender(n), age: "adult", pitch: "medium", tone: "server voice",
                                                       recipe: "\(model) · \(n)", engine: "server", custom: true, source: u)
            v.remoteModel = model; v.remoteVoice = n
            for l in LibraryGenerator.targetLangs() where v.samples[l.rawValue] == nil {
                let rel = "srv/\(id).\(l.rawValue).m4a"
                try speak(u, model: model, text: Catalog.sample(for: v, lang: l), lang: l, voice: n, to: Paths.audio.appendingPathComponent(rel))
                v.samples[l.rawValue] = rel
            }
            if let k = lib.firstIndex(where: { $0.id == id }) { lib[k] = v } else { lib.append(v) }
            try DataStore.saveVoices(lib)
        }
        progress(names.count, names.count)
        return names.count
    }
    /// Kokoro et d'autres préfixent le nom de la voix par son genre : af_ (femme), am_ (homme)…
    static func guessGender(_ n: String) -> Gender {
        let p = n.lowercased()
        if p.count > 2, p.dropFirst().hasPrefix("f_") { return .woman }
        if p.count > 2, p.dropFirst().hasPrefix("m_") { return .man }
        return .man
    }
}

// MARK: ElevenLabs (payant)
public enum ElevenLabs {
    public static let model = "eleven_multilingual_v2"
    /// Crédits estimés par caractère (Multilingual v2, mesuré).
    public static let creditsPerChar = 0.4
    public static var key: String? { ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"] ?? Keychain.get("elevenlabs") }
    static func h(_ k: String) -> [String: String] { ["xi-api-key": k] }

    /// Crédits restants et quota du mois (appel gratuit).
    public static func balance() throws -> (left: Int, limit: Int) {
        guard let k = key else { throw EngineError.failed("No ElevenLabs key") }
        let o = HTTP.object(try HTTP.call("https://api.elevenlabs.io/v1/user/subscription", headers: h(k), timeout: 15))
        let used = o["character_count"] as? Int ?? 0, lim = o["character_limit"] as? Int ?? 0
        return (max(0, lim - used), lim)
    }
    public static func cost(_ text: String) -> Int { Int((Double(text.count) * creditsPerChar).rounded(.up)) }

    /// Ajoute les voix du compte (y compris les voix prêtes d'ElevenLabs) à la bibliothèque ; leurs extraits sont gratuits.
    public static func importVoices(progress: (Int, Int) -> Void) throws -> Int {
        guard let k = key else { throw EngineError.failed("No ElevenLabs key") }
        let o = HTTP.object(try HTTP.call("https://api.elevenlabs.io/v1/voices", headers: h(k), timeout: 30))
        let list = o["voices"] as? [[String: Any]] ?? []
        var lib = try LibraryGenerator.ensureCatalog()
        for (i, e) in list.enumerated() {
            progress(i, list.count)
            guard let vid = e["voice_id"] as? String, let name = e["name"] as? String else { continue }
            let labels = e["labels"] as? [String: String] ?? [:]
            let g: Gender = labels["gender"] == "female" ? .woman : (labels["age"] == "child" ? .child : .man)
            let age = ["young": "young", "middle aged": "adult", "middle-aged": "adult", "old": "senior"][labels["age"] ?? ""] ?? "adult"
            let id = "el-" + vid
            var v = lib.first { $0.id == id } ?? Voice(id: id, name: name, gender: g, age: age, pitch: "medium",
                                                       tone: [labels["description"], labels["descriptive"], labels["use_case"]].compactMap { $0 }.joined(separator: ", "),
                                                       recipe: (e["description"] as? String) ?? labels.values.joined(separator: ", "), engine: "elevenlabs", custom: true, source: "ElevenLabs")
            v.remoteVoice = vid; v.remoteModel = model
            if v.samples["en"] == nil, let p = e["preview_url"] as? String, let d = try? HTTP.call(p, timeout: 30) {
                let rel = "el/\(vid).en.m4a"
                try HTTP.saveAudio(d, ext: "mp3", to: Paths.audio.appendingPathComponent(rel))
                v.samples["en"] = rel
            }
            if let x = lib.firstIndex(where: { $0.id == id }) { lib[x] = v } else { lib.append(v) }
        }
        try DataStore.saveVoices(lib)
        progress(list.count, list.count)
        return list.count
    }

    /// Génération payante : à n'appeler qu'après confirmation du coût par l'utilisateur.
    public static func speak(voiceID: String, text: String, to out: URL) throws {
        guard let k = key else { throw EngineError.failed("No ElevenLabs key") }
        let d = try HTTP.call("https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)?output_format=mp3_44100_128", method: "POST", headers: h(k),
                              json: ["text": text, "model_id": model], timeout: 120)
        try HTTP.saveAudio(d, ext: "mp3", to: out)
    }
}
