// mCASTING — génération de la bibliothèque (reprenable) et des essais de répliques.
import Foundation

public enum LibraryGenerator {
    public static func ensureCatalog() throws -> [Voice] {
        var v = DataStore.voices()
        if v.isEmpty { v = Catalog.recipes(); try DataStore.saveVoices(v) }
        return v
    }

    /// Langues à calculer pour la bibliothèque : celles des projets, plus celles demandées pour toute la bibliothèque,
    /// limitées aux langues du modèle créateur. Une langue déjà calculée n'est jamais refaite.
    public static func targetLangs(projects: [Project] = DataStore.projects(), setup: SetupState = SetupState.load()) -> [Lang] {
        var set = Set(projects.flatMap(\.languages)).union(setup.extraLangs.compactMap(Lang.init(rawValue:)))
        if set.isEmpty { set = [Lang.system] }
        return set.intersection(Languages.library).sorted()
    }
    /// Langues à calculer maintenant (hors pause).
    public static func activeLangs() -> [Lang] {
        let st = SetupState.load()
        return targetLangs(setup: st).filter { !st.pausedLangs.contains($0.rawValue) }
    }
    /// Nombre d'échantillons restants (voix × langue sans fichier) pour `langs`.
    public static func remaining(_ voices: [Voice], langs: [Lang] = activeLangs()) -> Int {
        voices.filter { !$0.custom }.reduce(0) { n, v in n + langs.filter { l in !hasSample(v, l) }.count }
    }
    /// Extraits prêts dans une langue.
    public static func ready(_ voices: [Voice], _ l: Lang) -> Int { voices.filter { !$0.custom && hasSample($0, l) }.count }
    public static func hasSample(_ v: Voice, _ l: Lang) -> Bool {
        guard let rel = v.samples[l.rawValue] else { return false }
        return FileManager.default.fileExists(atPath: Paths.audio.appendingPathComponent(rel).path)
    }

    /// Génère tous les échantillons manquants ; `progress(fait, total, voix, durée)`. Annulable via `cancel()`.
    public static func run(progress: @escaping (Int, Int, String, TimeInterval) -> Void, cancel: @escaping () -> Bool) throws {
        guard let model = TTSModel.find("qwen3-voicedesign") else { return }
        let st = SetupState.load()
        // Bibliothèque fabriquée sur un serveur du réseau, si choisi et si ce serveur sait créer une voix d'après sa description.
        let remote: (String, String)? = st.voiceMode == "server" && st.serverLibrary ? st.serverURL.flatMap { u in (try? VoiceServer.models(u)).flatMap(VoiceServer.designModel).map { (u, $0) } } : nil
        var voices = try ensureCatalog()
        let langs = activeLangs()
        let total = remaining(voices, langs: langs)
        var done = 0
        for l in langs {                       // langue par langue : une langue est vite complète et utilisable
          for i in voices.indices where !voices[i].custom && !hasSample(voices[i], l) {
                if SetupState.load().pausedLangs.contains(l.rawValue) { break }
                if cancel() { return }
                let rel = "lib/\(voices[i].id).\(l.rawValue).m4a"
                let out = Paths.audio.appendingPathComponent(rel), text = Catalog.sample(for: voices[i], lang: l)
                let recipe = voices[i].recipe(for: l)
                let dur = try remote.map { try VoiceServer.speak($0.0, model: $0.1, text: text, lang: l, instruct: recipe, to: out) }
                    ?? Engine.generate(model: model, text: text, lang: l, instruct: recipe, to: out)
                voices[i].samples[l.rawValue] = rel
                done += 1
                progress(done, total, voices[i].name, dur)
                if done % 5 == 0 { try save(voices) }
          }
        }
        try save(voices)
    }
    /// Enregistre les extraits calculés sans écraser une voix ajoutée entre-temps (clonage, MCP).
    static func save(_ mine: [Voice]) throws {
        var cur = DataStore.voices()
        let byID = Dictionary(mine.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for j in cur.indices { if let m = byID[cur[j].id] { cur[j].samples.merge(m.samples) { a, _ in a } } }
        if cur.isEmpty { cur = mine }
        try DataStore.saveVoices(cur)
    }

    /// Fichier d'écoute à la demande (même voix, même langue, même texte → même fichier, gardé en cache).
    public static func cacheURL(voice: Voice, lang: Lang, text: String, style: String, expressive: Bool, model: String) -> URL {
        var h: UInt64 = 0xcbf29ce484222325                     // FNV-1a : stable d'un lancement à l'autre
        for b in "\(text)|\(style)|\(expressive)|\(model)".utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return Paths.audio.appendingPathComponent("cache/\(voice.id).\(lang.rawValue).\(String(h, radix: 36)).m4a")
    }
    /// Écoutes à la demande gardées en cache, par langue (nombre de fichiers, octets).
    public static func cacheStats() -> [String: (count: Int, bytes: Int)] {
        let dir = Paths.audio.appendingPathComponent("cache")
        var out: [String: (Int, Int)] = [:]
        for f in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey])) ?? [] {
            let parts = f.deletingPathExtension().lastPathComponent.split(separator: ".")
            guard parts.count >= 3 else { continue }
            let l = String(parts[parts.count - 2]), sz = (try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            out[l, default: (0, 0)].0 += 1; out[l, default: (0, 0)].1 += sz
        }
        return out.mapValues { (count: $0.0, bytes: $0.1) }
    }
    /// Libère une langue : extraits de bibliothèque et écoutes en cache de cette langue (jamais celles d'un projet).
    public static func purge(_ l: Lang) throws {
        guard !DataStore.projects().flatMap(\.languages).contains(l) else { return }
        var voices = DataStore.voices()
        for i in voices.indices where !voices[i].custom {
            if let rel = voices[i].samples[l.rawValue] { try? FileManager.default.removeItem(at: Paths.audio.appendingPathComponent(rel)); voices[i].samples[l.rawValue] = nil }
        }
        try DataStore.saveVoices(voices)
        let dir = Paths.audio.appendingPathComponent("cache")
        for f in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] where f.lastPathComponent.contains(".\(l.rawValue).") {
            try? FileManager.default.removeItem(at: f)
        }
        var st = SetupState.load(); st.extraLangs.removeAll { $0 == l.rawValue }; st.pausedLangs.removeAll { $0 == l.rawValue }; st.save()
    }

    /// Écoute d'une voix dans n'importe quelle langue : extrait de la langue s'il existe (timbre exact), sinon clonage du
    /// timbre d'un extrait existant par un modèle installé qui parle cette langue. Résultat gardé en cache.
    public static func listen(voice: Voice, text: String, lang: Lang, style: String = "", expressive: Bool = false, prefer: Lang? = nil,
                              actingModel: String? = SetupState.load().actingModel) throws -> URL {
        let designer = Languages.library.contains(lang)
        let m = Languages.actingModel(for: lang, preferred: actingModel)
        let key = (expressive && designer) ? "design" : (m?.id ?? "none")
        // Mode Expressive : une nouvelle prise à chaque écoute (pas de cache) ; Fidèle : même résultat, gardé en cache.
        let out = expressive ? Paths.audio.appendingPathComponent("preview/\(UUID().uuidString).m4a")
                             : cacheURL(voice: voice, lang: lang, text: text, style: style, expressive: false, model: key)
        if !expressive, FileManager.default.fileExists(atPath: out.path) { return out }
        if voice.engine == "server" || voice.engine == "elevenlabs" || voice.refAudio != nil || (expressive && designer) {
            let u = try preview(voice: voice, text: text, lang: lang, style: style, expressive: expressive, timbreFrom: voice.timbre(for: lang, prefer: prefer), actingModel: actingModel)
            try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: out); try FileManager.default.moveItem(at: u, to: out)
            return out
        }
        guard let m else { throw EngineError.failed("No installed voice model speaks \(lang.english)") }
        guard !voice.samples.isEmpty else { throw EngineError.failed("No sample for \(voice.id)") }
        try speak(voice: voice, text: text, lang: lang, refLang: voice.timbre(for: lang, prefer: prefer), style: style, model: m, to: out)
        return out
    }

    /// Essai d'une réplique de personnage avec une voix et une consigne d'émotion.
    public static func preview(voice: Voice, text: String, lang: Lang, style: String, expressive: Bool = false, timbreFrom: Lang? = nil,
                               actingModel: String? = SetupState.load().actingModel) throws -> URL {
        let rel = "preview/\(UUID().uuidString).m4a"
        let out = Paths.audio.appendingPathComponent(rel)
        if voice.engine == "server", let m = voice.remoteModel, let u = voice.source {      // voix toute prête d'un serveur du réseau
            try VoiceServer.speak(u, model: m, text: text, lang: lang, voice: voice.remoteVoice, to: out); return out
        }
        if voice.engine == "elevenlabs" { throw EngineError.failed("ElevenLabs: confirm the cost first") }
        if let ref = voice.refAudio {      // voix clonée : modèle Base, extrait de référence
            guard let base = TTSModel.find("qwen3-base") else { throw EngineError.notInstalled }
            try Engine.generate(model: base, text: text, lang: lang, instruct: "", refAudio: Paths.audio.appendingPathComponent(ref), refText: voice.refText, to: out)
            return out
        }
        // Voix de la bibliothèque : VoiceDesign retire un timbre différent à chaque génération. Pour garder LA voix écoutée,
        // on clone son échantillon (même langue) avec le modèle choisi pour dire les répliques (guide « Premiers pas »).
        let refLang = timbreFrom ?? lang
        if !expressive || !Languages.library.contains(lang), voice.samples[refLang.rawValue] != nil {
            guard let m = Languages.actingModel(for: lang, preferred: actingModel) else { throw EngineError.failed("No installed voice model speaks \(lang.english)") }
            try speak(voice: voice, text: text, lang: lang, refLang: refLang, style: style, model: m, to: out)
            return out
        }
        guard let model = TTSModel.find("qwen3-voicedesign") else { throw EngineError.notInstalled }
        let instruct = style.isEmpty ? voice.recipe(for: lang) : voice.recipe(for: lang) + " Emotion and delivery for this line: " + style + "."
        try Engine.generate(model: model, text: text, lang: lang, instruct: instruct, to: out)
        return out
    }

    /// Dit `text` avec la voix `voice` en clonant son extrait (langue `refLang`) par le modèle `model`.
    /// L'émotion passe selon le modèle : balise dans le texte (Fish), exagération (Chatterbox), aucune (Qwen3 Base, OmniVoice).
    @discardableResult
    public static func speak(voice: Voice, text: String, lang: Lang, refLang: Lang, style: String, model: TTSModel, to out: URL) throws -> TimeInterval {
        guard let sample = voice.samples[refLang.rawValue] else { throw EngineError.failed("No sample for \(voice.id)") }
        let wav = FileManager.default.temporaryDirectory.appendingPathComponent("mcasting-ref-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: wav) }
        try Engine.run(URL(fileURLWithPath: "/usr/bin/afconvert"), ["-f", "WAVE", "-d", "LEI16@24000", "-c", "1", Paths.audio.appendingPathComponent(sample).path, wav.path])
        let refText = Catalog.sample(for: voice, lang: refLang)
        let mood = style.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        switch model.family {
        case "fish":
            return try Engine.generate(model: model, text: mood.isEmpty ? text : "[\(mood)] " + text, lang: lang, instruct: "", refAudio: wav, refText: refText, to: out)
        case "chatterbox":
            return try Engine.generate(model: model, text: text, lang: lang, instruct: "", refAudio: wav, extra: ["--exaggeration", style.isEmpty ? "0.5" : "0.8"], to: out)
        default:
            return try Engine.generate(model: model, text: text, lang: lang, instruct: "", refAudio: wav, refText: refText, to: out)
        }
    }

    /// Garantit l'extrait d'une voix dans une langue (généré par VoiceDesign s'il manque) ; sert à l'écoute comparée.
    public static func ensureSample(_ id: String, lang: Lang) throws -> Voice {
        var voices = try ensureCatalog()
        guard let i = voices.firstIndex(where: { $0.id == id }) else { throw EngineError.failed("Unknown voice \(id)") }
        if hasSample(voices[i], lang) { return voices[i] }
        guard let model = TTSModel.find("qwen3-voicedesign") else { throw EngineError.notInstalled }
        let rel = "lib/\(voices[i].id).\(lang.rawValue).m4a"
        guard Languages.library.contains(lang) else { throw EngineError.failed("The voice designer does not speak \(lang.english)") }
        try Engine.generate(model: model, text: Catalog.sample(for: voices[i], lang: lang), lang: lang, instruct: voices[i].recipe(for: lang), to: Paths.audio.appendingPathComponent(rel))
        voices[i].samples[lang.rawValue] = rel
        try save(voices)
        return voices[i]
    }
}
