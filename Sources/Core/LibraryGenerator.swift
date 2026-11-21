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
        var voices = try ensureCatalog()
        let total = remaining(voices)
        var done = 0
        for i in voices.indices {
            for l in Lang.allCases where !hasSample(voices[i], l) {
                if cancel() { return }
                let rel = "lib/\(voices[i].id).\(l.rawValue).m4a"
                let dur = try Engine.generate(model: model, text: Catalog.sample(for: voices[i], lang: l), lang: l,
                                              instruct: voices[i].recipe, to: Paths.audio.appendingPathComponent(rel))
                voices[i].samples[l.rawValue] = rel
                done += 1
                progress(done, total, voices[i].name, dur)
                if done % 5 == 0 { try DataStore.saveVoices(voices) }
            }
        }
        try DataStore.saveVoices(voices)
    }

    /// Essai d'une réplique de personnage avec une voix et une consigne d'émotion.
    public static func preview(voice: Voice, text: String, lang: Lang, style: String, expressive: Bool = false, timbreFrom: Lang? = nil) throws -> URL {
        let rel = "preview/\(UUID().uuidString).m4a"
        let out = Paths.audio.appendingPathComponent(rel)
        if let ref = voice.refAudio {      // voix clonée : modèle Base, extrait de référence
            guard let base = TTSModel.find("qwen3-base") else { throw EngineError.notInstalled }
            try Engine.generate(model: base, text: text, lang: lang, instruct: "", refAudio: Paths.audio.appendingPathComponent(ref), refText: voice.refText, to: out)
            return out
        }
        // Voix de la bibliothèque : VoiceDesign retire un timbre différent à chaque génération. Pour garder LA voix écoutée,
        // on clone son échantillon (même langue) avec le modèle Base ; la consigne d'émotion n'y est pas applicable.
        let refLang = timbreFrom ?? lang
        if !expressive, let sample = voice.samples[refLang.rawValue], let base = TTSModel.find("qwen3-base") {
            let wav = FileManager.default.temporaryDirectory.appendingPathComponent("mcasting-ref-\(UUID().uuidString).wav")
            defer { try? FileManager.default.removeItem(at: wav) }
            try Engine.run(URL(fileURLWithPath: "/usr/bin/afconvert"), ["-f", "WAVE", "-d", "LEI16@24000", "-c", "1", Paths.audio.appendingPathComponent(sample).path, wav.path])
            try Engine.generate(model: base, text: text, lang: lang, instruct: "", refAudio: wav, refText: Catalog.sample(for: voice, lang: refLang), to: out)
            return out
        }
        guard let model = TTSModel.find("qwen3-voicedesign") else { throw EngineError.notInstalled }
        let instruct = style.isEmpty ? voice.recipe : voice.recipe + " Emotion and delivery for this line: " + style + "."
        try Engine.generate(model: model, text: text, lang: lang, instruct: instruct, to: out)
        return out
    }
}
