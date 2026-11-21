// mCASTING — génération de la bibliothèque (reprenable) et des essais de répliques.
import Foundation

public enum LibraryGenerator {
    public static func ensureCatalog() throws -> [Voice] {
        var v = DataStore.voices()
        if v.isEmpty { v = Catalog.recipes(); try DataStore.saveVoices(v) }
        return v
    }

    /// Nombre d'échantillons restants (voix × langue sans fichier).
    public static func remaining(_ voices: [Voice]) -> Int {
        voices.reduce(0) { n, v in n + Lang.allCases.filter { l in !hasSample(v, l) }.count }
    }
    static func hasSample(_ v: Voice, _ l: Lang) -> Bool {
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
        let total = remaining(voices)
        var done = 0
        for i in voices.indices {
            for l in Lang.allCases where !hasSample(voices[i], l) {
                if cancel() { return }
                let rel = "lib/\(voices[i].id).\(l.rawValue).m4a"
                let out = Paths.audio.appendingPathComponent(rel), text = Catalog.sample(for: voices[i], lang: l)
                let dur = try remote.map { try VoiceServer.speak($0.0, model: $0.1, text: text, lang: l, instruct: voices[i].recipe, to: out) }
                    ?? Engine.generate(model: model, text: text, lang: l, instruct: voices[i].recipe, to: out)
                voices[i].samples[l.rawValue] = rel
                done += 1
                progress(done, total, voices[i].name, dur)
                if done % 5 == 0 { try DataStore.saveVoices(voices) }
            }
        }
        try DataStore.saveVoices(voices)
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
        if !expressive, voice.samples[refLang.rawValue] != nil {
            let m = actingModel.flatMap { TTSModel.find($0) }.flatMap { $0.installed ? $0 : nil } ?? TTSModel.find("qwen3-base")!
            try speak(voice: voice, text: text, lang: lang, refLang: refLang, style: style, model: m, to: out)
            return out
        }
        guard let model = TTSModel.find("qwen3-voicedesign") else { throw EngineError.notInstalled }
        let instruct = style.isEmpty ? voice.recipe : voice.recipe + " Emotion and delivery for this line: " + style + "."
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
        try Engine.generate(model: model, text: Catalog.sample(for: voices[i], lang: lang), lang: lang, instruct: voices[i].recipe, to: Paths.audio.appendingPathComponent(rel))
        voices[i].samples[lang.rawValue] = rel
        try DataStore.saveVoices(voices)
        return voices[i]
    }
}
