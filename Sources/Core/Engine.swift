// mCASTING — moteur TTS autonome : uv + Python privé + mlx-audio dans Application Support, modèles Hugging Face.
// Rien ne dépend d'outils extérieurs à l'appli (hors macOS lui-même et le réseau pour l'installation).
import Foundation

public struct TTSModel: Identifiable, Hashable {
    public let id: String            // identifiant interne
    public let repo: String          // dépôt Hugging Face
    public let title: String
    public let notes: String
    public let sizeGB: Double
    public let reference: Bool
    /// Famille d'arguments mlx-audio : qwen3 · chatterbox · omnivoice · fish.
    public var family = "qwen3"
    /// Peut « dire les répliques » en clonant l'extrait d'une voix de la bibliothèque (choix du guide).
    public var acting = false
    /// Clé du nom simple affiché dans le guide (« Voix naturelle »…), mémoire estimée pendant la génération.
    public var nameKey = ""
    public var ramGB: Double = 0
    public var license = "Apache-2.0"
    public static let catalog: [TTSModel] = [
        .init(id: "qwen3-voicedesign", repo: "mlx-community/Qwen3-TTS-12Hz-1.7B-VoiceDesign-8bit", title: "Qwen3-TTS VoiceDesign (1.7B, 8 bits)", notes: "voice_design", sizeGB: 3.1, reference: true),
        .init(id: "qwen3-customvoice", repo: "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-8bit", title: "Qwen3-TTS CustomVoice (1.7B, 8 bits)", notes: "custom_voice", sizeGB: 3.1, reference: true),
        .init(id: "qwen3-base", repo: "mlx-community/Qwen3-TTS-12Hz-1.7B-Base-8bit", title: "Qwen3-TTS Base (1.7B, 8 bits)", notes: "cloning", sizeGB: 3.1, reference: false,
              family: "qwen3", acting: true, nameKey: "mdl.natural", ramGB: 5),
        .init(id: "fish-drama3", repo: "mlx-community/fish-audio-drama-3-4bit", title: "Fish Audio Drama 3 (4 bits)", notes: "cloning_acting", sizeGB: 22, reference: false,
              family: "fish", acting: true, nameKey: "mdl.actor", ramGB: 26, license: "Fish Audio Community"),
        .init(id: "chatterbox-ml", repo: "mlx-community/chatterbox-multilingual-v3", title: "Chatterbox multilingue v3", notes: "cloning_expressive", sizeGB: 2.7, reference: false,
              family: "chatterbox", acting: true, nameKey: "mdl.expressive", ramGB: 4, license: "MIT"),
        .init(id: "omnivoice", repo: "mlx-community/OmniVoice-bfloat16", title: "OmniVoice (0.6B)", notes: "cloning_light", sizeGB: 1.3, reference: false,
              family: "omnivoice", acting: true, nameKey: "mdl.fast", ramGB: 2),
        .init(id: "sfx-stable-audio", repo: "mlx-community/stable-audio-3-small-sfx", title: "Stable Audio 3 Small SFX", notes: "sound_effects", sizeGB: 3.5, reference: false,
              family: "sfx", nameKey: "mdl.sfx", ramGB: 5, license: "Stability AI Community"),
        .init(id: "chatterbox", repo: "mlx-community/chatterbox-fp16", title: "Chatterbox (anglais, fp16)", notes: "cloning_expressive", sizeGB: 3.1, reference: false, family: "chatterbox", license: "MIT"),
    ]
    public static var acting: [TTSModel] { catalog.filter(\.acting) }
    public static func find(_ id: String) -> TTSModel? { catalog.first { $0.id == id } }

    /// Dossier du cache Hugging Face (même règle que huggingface_hub).
    public var cacheDir: URL {
        let env = ProcessInfo.processInfo.environment
        let root = env["HF_HUB_CACHE"].map { URL(fileURLWithPath: $0) }
            ?? env["HF_HOME"].map { URL(fileURLWithPath: $0).appendingPathComponent("hub") }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cache/huggingface/hub")
        return root.appendingPathComponent("models--" + repo.replacingOccurrences(of: "/", with: "--"))
    }
    public var installed: Bool {
        let snaps = cacheDir.appendingPathComponent("snapshots")
        guard let s = try? FileManager.default.contentsOfDirectory(atPath: snaps.path), let first = s.first else { return false }
        let files = (try? FileManager.default.contentsOfDirectory(atPath: snaps.appendingPathComponent(first).path)) ?? []
        return files.contains { $0.hasSuffix(".safetensors") } && files.contains("config.json")
    }
}

public enum EngineError: LocalizedError {
    case notInstalled, failed(String)
    public var errorDescription: String? {
        switch self { case .notInstalled: return "TTS engine not installed"; case .failed(let s): return s }
    }
}

public enum Engine {
    static var uv: URL { Paths.engine.appendingPathComponent("uv") }
    static var venv: URL { Paths.engine.appendingPathComponent("venv") }
    static var python: URL { venv.appendingPathComponent("bin/python") }
    public static var installed: Bool {
        FileManager.default.isExecutableFile(atPath: python.path) &&
        FileManager.default.fileExists(atPath: venv.appendingPathComponent("lib").path) &&
        FileManager.default.fileExists(atPath: Paths.engine.appendingPathComponent(".ok").path)
    }

    @discardableResult
    static func run(_ exe: URL, _ args: [String], env: [String: String] = [:], log: ((String) -> Void)? = nil) throws -> String {
        let p = Process(), pipe = Pipe()
        p.executableURL = exe; p.arguments = args
        var e = ProcessInfo.processInfo.environment; env.forEach { e[$0] = $1 }; p.environment = e
        p.standardOutput = pipe; p.standardError = pipe
        try p.run()
        var all = Data()
        while true {
            let d = pipe.fileHandleForReading.availableData
            if d.isEmpty { break }
            all.append(d); if let log, let s = String(data: d, encoding: .utf8) { log(s) }
        }
        p.waitUntilExit()
        let out = String(decoding: all, as: UTF8.self)
        guard p.terminationStatus == 0 else { throw EngineError.failed(String(out.suffix(600))) }
        return out
    }

    /// Installe uv, un Python 3.12 isolé et mlx-audio. Étapes courtes, journal en direct.
    public static func install(log: @escaping (String) -> Void) throws {
        Paths.prepare()
        if !FileManager.default.isExecutableFile(atPath: uv.path) {
            log("Downloading uv…")
            let tgz = Paths.engine.appendingPathComponent("uv.tar.gz")
            let url = URL(string: "https://github.com/astral-sh/uv/releases/latest/download/uv-aarch64-apple-darwin.tar.gz")!
            let data = try Data(contentsOf: url)
            try data.write(to: tgz)
            try run(URL(fileURLWithPath: "/usr/bin/tar"), ["-xzf", tgz.path, "-C", Paths.engine.path, "--strip-components=1"])
            try? FileManager.default.removeItem(at: tgz)
        }
        log("Creating Python environment…")
        try run(uv, ["venv", "--python", "3.12", "--clear", venv.path], env: ["UV_PYTHON_INSTALL_DIR": Paths.engine.appendingPathComponent("python").path], log: log)
        log("Installing mlx-audio…")
        try run(uv, ["pip", "install", "--python", python.path, "mlx-audio", "huggingface_hub", "yt-dlp"], log: log)
        FileManager.default.createFile(atPath: Paths.engine.appendingPathComponent(".ok").path, contents: Data("1".utf8))
    }

    /// Télécharge un modèle (reprise automatique par huggingface_hub) et vérifie sa présence.
    public static func download(_ m: TTSModel, log: @escaping (String) -> Void) throws {
        guard installed else { throw EngineError.notInstalled }
        log("Downloading \(m.title)…")
        try run(python, ["-c", "from huggingface_hub import snapshot_download as s; s('\(m.repo)')"], log: log)
        guard m.installed else { throw EngineError.failed("Verification failed for \(m.repo)") }
    }

    /// Ajoute yt-dlp à un moteur déjà installé (liens web).
    public static func ensureDownloader(log: @escaping (String) -> Void) throws {
        guard installed else { throw EngineError.notInstalled }
        if FileManager.default.isExecutableFile(atPath: venv.appendingPathComponent("bin/yt-dlp").path) { return }
        try run(uv, ["pip", "install", "--python", python.path, "yt-dlp"], log: log)
    }

    // MARK: Calcul — une seule génération à la fois (verrou partagé entre l'appli et le serveur MCP)
    static func withComputeLock<T>(_ body: () throws -> T) rethrows -> T {
        Paths.prepare()
        let fd = open(Paths.lock.path, O_CREAT | O_RDWR, 0o600)
        if fd >= 0 { flock(fd, LOCK_EX) }
        defer { if fd >= 0 { flock(fd, LOCK_UN); close(fd) } }
        return try body()
    }

    /// Génère `text` ; `instruct` = description de la voix (VoiceDesign) ou consigne d'émotion (CustomVoice).
    /// Sortie en .m4a (AAC, `afconvert` de macOS). Renvoie la durée de calcul.
    @discardableResult
    public static func generate(model: TTSModel, text: String, lang: Lang, instruct: String, voice: String? = nil,
                                refAudio: URL? = nil, refText: String? = nil, extra: [String] = [], to out: URL) throws -> TimeInterval {
        guard installed else { throw EngineError.notInstalled }
        return try withComputeLock {
            let t0 = Date()
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("mcasting-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tmp) }
            var args = ["-m", "mlx_audio.tts.generate", "--model", model.repo, "--text", text, "--lang_code", model.family == "qwen3" ? lang.qwen : lang.rawValue,
                        "--output_path", tmp.path, "--file_prefix", "v", "--join_audio"]
            if !instruct.isEmpty { args += ["--instruct", instruct] }
            if let voice { args += ["--voice", voice] }
            if let refAudio { args += ["--ref_audio", refAudio.path] }
            if let refText, !refText.isEmpty { args += ["--ref_text", refText] }
            args += extra
            try run(python, args)
            let files = (try? FileManager.default.contentsOfDirectory(atPath: tmp.path))?.filter { $0.hasSuffix(".wav") }.sorted() ?? []
            guard let wav = files.first else { throw EngineError.failed("No audio produced") }
            try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: out)
            try run(URL(fileURLWithPath: "/usr/bin/afconvert"), ["-f", "m4af", "-d", "aac", tmp.appendingPathComponent(wav).path, out.path])
            return Date().timeIntervalSince(t0)
        }
    }

    /// Bruitage d'après une description en anglais (modèle Stable Audio 3, sans paroles). Sortie .m4a.
    @discardableResult
    public static func generateSFX(model: TTSModel, caption: String, seconds: Int, seed: Int, to out: URL) throws -> TimeInterval {
        guard installed else { throw EngineError.notInstalled }
        return try withComputeLock {
            let t0 = Date()
            let wav = FileManager.default.temporaryDirectory.appendingPathComponent("mcasting-sfx-\(UUID().uuidString).wav")
            defer { try? FileManager.default.removeItem(at: wav) }
            try run(python, ["-m", "mlx_audio.music.generate", "--model", model.repo, "--caption", caption, "--duration", String(seconds), "--seed", String(seed), "--output", wav.path])
            try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: out)
            try run(URL(fileURLWithPath: "/usr/bin/afconvert"), ["-f", "m4af", "-d", "aac", wav.path, out.path])
            return Date().timeIntervalSince(t0)
        }
    }
}
