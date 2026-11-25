// mCASTING — boîte de réception : import des paquets déposés par d'autres outils (mTALKIE…) dans
// ~/Library/Application Support/mCASTING/Inbox/<paquet>/ (manifest.json + fichiers audio). Format : docs/inbox-format.md.
// Un paquet est écrit sous un nom commençant par « . » puis renommé : il n'est jamais lu à moitié.
import Foundation

public enum InboxImporter {
    // MARK: format mcasting-inbox/1
    public struct Source: Codable { public var kind: String?; public var title: String; public var id: String? }
    public struct VoicePart: Codable {
        public var name: String, lang: String, audio: String, text: String
        public var gender: String?, description: String?, character: String?, tags: [String]?
    }
    public struct LinePart: Codable {
        public var key: String?, text: String?, character: String?, lang: String?
        public var duration: Double?, tags: [String]?, audio: String?
    }
    public struct Manifest: Codable {
        public var format: String
        public var kind: String                 // voice / lines
        public var origin: [String: String]?    // { "app": "mTALKIE", "version": "1.6.0" }
        public var source: Source?
        public var voice: VoicePart?
        public var lines: [LinePart]?
    }

    /// Ce qui a été importé (pour la notification de l'appli).
    public struct Imported: Codable {
        public var kind: String, title: String, count: Int, voiceName: String?, app: String?
    }

    /// Importe tous les paquets prêts ; les paquets invalides vont dans Inbox/failed avec un fichier error.txt.
    @discardableResult
    public static func processAll() -> [Imported] {
        Paths.prepare()
        let fm = FileManager.default
        let fd = open(Paths.home.appendingPathComponent("inbox.lock").path, O_CREAT | O_RDWR, 0o600)
        defer { if fd >= 0 { flock(fd, LOCK_UN); close(fd) } }
        if fd >= 0, flock(fd, LOCK_EX | LOCK_NB) != 0 { return [] }      // un autre processus importe déjà
        let items = ((try? fm.contentsOfDirectory(atPath: Paths.inbox.path)) ?? []).filter { !$0.hasPrefix(".") && $0 != "failed" }.sorted()
        var out: [Imported] = []
        for name in items {
            let dir = Paths.inbox.appendingPathComponent(name)
            guard fm.fileExists(atPath: dir.appendingPathComponent("manifest.json").path) else { continue }
            do { out.append(try importPackage(dir)); try? fm.removeItem(at: dir) }
            catch {
                let failed = Paths.inbox.appendingPathComponent("failed")
                try? fm.createDirectory(at: failed, withIntermediateDirectories: true)
                let dest = failed.appendingPathComponent(name); try? fm.removeItem(at: dest)
                try? fm.moveItem(at: dir, to: dest)
                try? error.localizedDescription.write(to: dest.appendingPathComponent("error.txt"), atomically: true, encoding: .utf8)
            }
        }
        return out
    }

    static func fail(_ s: String) -> NSError { NSError(domain: "mCASTING.inbox", code: 1, userInfo: [NSLocalizedDescriptionKey: s]) }

    /// Fichier du paquet, sans sortir de son dossier.
    static func file(_ rel: String, in dir: URL) throws -> URL {
        guard !rel.isEmpty, !rel.hasPrefix("/"), !rel.split(separator: "/").contains("..") else { throw fail("Invalid path: \(rel)") }
        let u = dir.appendingPathComponent(rel)
        guard FileManager.default.fileExists(atPath: u.path) else { throw fail("Missing file: \(rel)") }
        return u
    }

    public static func importPackage(_ dir: URL) throws -> Imported {
        let m = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: dir.appendingPathComponent("manifest.json")))
        guard m.format.hasPrefix("mcasting-inbox/") else { throw fail("Unknown format \(m.format)") }
        let title = m.source?.title ?? dir.lastPathComponent
        switch m.kind {
        case "voice":
            guard let v = m.voice, !v.name.isEmpty, !v.text.isEmpty else { throw fail("voice: name, audio and text are required") }
            let src = try file(v.audio, in: dir)
            let lang = Lang(rawValue: v.lang.lowercased()) ?? .en
            let id = "clone-" + UUID().uuidString.prefix(8).lowercased()
            let rel = "clones/\(id).wav", dest = Paths.audio.appendingPathComponent(rel)
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Même préparation que le panneau « Cloner une voix » : WAV mono 24 kHz 16 bits.
            try Engine.run(URL(fileURLWithPath: "/usr/bin/afconvert"), ["-f", "WAVE", "-d", "LEI16@24000", "-c", "1", src.path, dest.path])
            let origin = [m.origin?["app"], title].compactMap { $0 }.joined(separator: " · ")
            var voice = Voice(id: id, name: v.name, gender: Gender(rawValue: v.gender ?? "") ?? .man, age: "n/a", pitch: "n/a", tone: "cloned",
                              recipe: v.description.map { "Cloned voice: \($0)" } ?? "Cloned voice from a reference sample.", engine: "qwen3-base",
                              samples: [lang.rawValue: rel], custom: true, refAudio: rel, refText: v.text, source: origin)
            voice.character = v.character; voice.sourceKind = m.source?.kind ?? "other"; voice.sourceTitle = m.source?.title
            voice.tags = v.tags; voice.added = Date()
            var all = DataStore.voices()
            if let i = all.firstIndex(where: { $0.custom && $0.name == v.name && $0.source == origin }) {   // même voix renvoyée : on la remplace
                voice.id = all[i].id
                let old = all[i].refAudio; voice.tags = voice.tags ?? all[i].tags; all[i] = voice
                all[i].samples = [lang.rawValue: rel]
                if let old, old != rel { try? FileManager.default.removeItem(at: Paths.audio.appendingPathComponent(old)) }
            } else { all.append(voice) }
            try DataStore.saveVoices(all)
            return Imported(kind: "voice", title: title, count: 1, voiceName: v.name, app: m.origin?["app"])
        case "lines":
            let ls = m.lines ?? []
            guard !ls.isEmpty else { throw fail("lines: empty") }
            let sid = LinesStore.safe(m.source?.id ?? title)
            let destDir = Paths.lines.appendingPathComponent(sid)
            let fm = FileManager.default
            try? fm.removeItem(at: destDir)
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            var rows: [LinesStore.NewLine] = []
            rows.reserveCapacity(ls.count)
            for (i, l) in ls.enumerated() {
                var audio: String?
                if let a = l.audio, let src = try? file(a, in: dir) {
                    let rel = sid + "/" + a.replacingOccurrences(of: "/", with: "_")
                    try? fm.moveItem(at: src, to: Paths.lines.appendingPathComponent(rel))
                    audio = rel
                }
                rows.append(.init(key: l.key ?? String(format: "%05d", i + 1), text: l.text ?? "", character: l.character ?? "",
                                  lang: (l.lang ?? "").lowercased(), duration: l.duration ?? 0, tags: l.tags ?? [], audio: audio))
            }
            try LinesStore.replace(source: sid, title: title, kind: m.source?.kind ?? "other", lines: rows)
            return Imported(kind: "lines", title: title, count: rows.count, voiceName: nil, app: m.origin?["app"])
        default: throw fail("Unknown kind \(m.kind)")
        }
    }
}
