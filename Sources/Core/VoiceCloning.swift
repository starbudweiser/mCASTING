// mCASTING — clonage de voix : import d'un fichier audio ou d'un lien web (extraction de la piste audio), découpe de
// l'extrait de référence, transcription automatique, création d'une voix « clonée » dans la bibliothèque.
import Foundation
import AVFoundation

public enum VoiceCloning {
    public struct Prepared { public var wav: URL; public var duration: Double; public var source: String }

    /// Télécharge la piste audio d'un lien (YouTube et autres sites pris en charge par yt-dlp) dans `dir`.
    public static func fetch(link: String, into dir: URL, log: @escaping (String) -> Void) throws -> URL {
        try Engine.ensureDownloader(log: log)
        guard let u = URL(string: link), ["http", "https"].contains(u.scheme?.lowercased() ?? "") else {
            throw EngineError.failed("Invalid link")
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let exe = Engine.venv.appendingPathComponent("bin/yt-dlp")
        try Engine.run(exe, ["--no-playlist", "-f", "bestaudio[ext=m4a]/bestaudio", "-o", dir.appendingPathComponent("src.%(ext)s").path, link], log: log)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        guard let f = files.first(where: { $0.hasPrefix("src.") }) else { throw EngineError.failed("No audio downloaded") }
        return dir.appendingPathComponent(f)
    }

    public static func duration(of url: URL) async -> Double {
        let d = try? await AVURLAsset(url: url).load(.duration)
        return d.map { CMTimeGetSeconds($0) } ?? 0
    }

    /// Découpe [start, start+length] (5 à 15 s recommandées), convertit en WAV mono 24 kHz pour le modèle.
    public static func prepare(source: URL, start: Double, length: Double, label: String, into dir: URL) async throws -> Prepared {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let asset = AVURLAsset(url: source)
        let total = CMTimeGetSeconds(try await asset.load(.duration))
        let len = min(max(length, 1), 30, max(total - start, 1))
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else { throw EngineError.failed("Unsupported audio format") }
        let m4a = dir.appendingPathComponent("clip.m4a"); try? FileManager.default.removeItem(at: m4a)
        export.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), duration: CMTime(seconds: len, preferredTimescale: 600))
        try await export.export(to: m4a, as: .m4a)
        let wav = dir.appendingPathComponent("ref.wav"); try? FileManager.default.removeItem(at: wav)
        try Engine.run(URL(fileURLWithPath: "/usr/bin/afconvert"), ["-f", "WAVE", "-d", "LEI16@24000", "-c", "1", m4a.path, wav.path])
        return Prepared(wav: wav, duration: len, source: label)
    }

    /// Transcription automatique de l'extrait (modèle de reconnaissance de mlx-audio, téléchargé au premier usage).
    public static func transcribe(_ wav: URL, lang: Lang) throws -> String {
        guard Engine.installed else { throw EngineError.notInstalled }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("mcasting-stt-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(atPath: out.path + ".txt") }
        _ = try Engine.withComputeLock {
            try Engine.run(Engine.python, ["-m", "mlx_audio.stt.generate", "--model", "mlx-community/whisper-large-v3-turbo-asr-fp16",
                                           "--audio", wav.path, "--output-path", out.path, "--format", "txt", "--language", lang.rawValue])
        }
        return ((try? String(contentsOfFile: out.path + ".txt", encoding: .utf8)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Enregistre la voix clonée : copie l'extrait dans la bibliothèque et ajoute la voix.
    @discardableResult
    public static func register(name: String, gender: Gender, prepared p: Prepared, refText: String, lang: Lang,
                                character: String? = nil, sourceKind: String? = nil, sourceTitle: String? = nil, tags: [String]? = nil) throws -> Voice {
        let id = "clone-" + UUID().uuidString.prefix(8).lowercased()
        let rel = "clones/\(id).wav"
        let dest = Paths.audio.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: p.wav, to: dest)
        let v = Voice(id: id, name: name, gender: gender, age: "n/a", pitch: "n/a", tone: "cloned",
                      recipe: "Cloned voice from a reference sample.", engine: "qwen3-base",
                      samples: [lang.rawValue: rel], custom: true, refAudio: rel, refText: refText, source: p.source)
        var voice = v
        voice.character = character.flatMap { $0.isEmpty ? nil : $0 }; voice.sourceKind = sourceKind
        voice.sourceTitle = sourceTitle.flatMap { $0.isEmpty ? nil : $0 }; voice.tags = tags.flatMap { $0.isEmpty ? nil : $0 }; voice.added = Date()
        var all = DataStore.voices(); all.append(voice); try DataStore.saveVoices(all)
        return voice
    }

    /// Met à jour la fiche de classement d'une voix clonée ou importée.
    public static func updateInfo(id: String, _ f: (inout Voice) -> Void) throws {
        var all = DataStore.voices()
        guard let i = all.firstIndex(where: { $0.id == id }), all[i].custom else { throw EngineError.failed("Only cloned or imported voices can be edited") }
        f(&all[i]); try DataStore.saveVoices(all)
    }

    /// Supprime une voix clonée ou importée (jamais une voix de la bibliothèque) : retirée de voices.json, ses fichiers audio
    /// et ses écoutes en cache effacés, et les personnages qui l'avaient choisie n'ont plus de voix.
    public static func remove(id: String) throws {
        var all = DataStore.voices()
        guard let v = all.first(where: { $0.id == id }), v.custom else { throw EngineError.failed("Only cloned or imported voices can be deleted") }
        all.removeAll { $0.id == id }
        let shared = Set(all.flatMap { Array($0.samples.values) + [$0.refAudio].compactMap { $0 } })
        try DataStore.saveVoices(all)
        let fm = FileManager.default
        for rel in Set(Array(v.samples.values) + [v.refAudio].compactMap { $0 }) where !shared.contains(rel) && !rel.contains("..") {
            try? fm.removeItem(at: Paths.audio.appendingPathComponent(rel))
        }
        let cache = Paths.audio.appendingPathComponent("cache")
        for f in (try? fm.contentsOfDirectory(atPath: cache.path)) ?? [] where f.hasPrefix(id + ".") {
            try? fm.removeItem(at: cache.appendingPathComponent(f))
        }
        _ = try DataStore.updateProjects { ps in
            for i in ps.indices { for j in ps[i].characters.indices where ps[i].characters[j].voiceID == id { ps[i].characters[j].voiceID = nil } }
        }
    }
}
