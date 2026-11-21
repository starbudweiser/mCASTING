// mCASTING — écriture du casting validé dans le dossier du projet (casting.json), consommé par le projet cible.
import Foundation

public enum CastingExport {
    public struct Entry: Codable {
        public var voice_id: String, engine: String, recipe: String, style: String, sample: String?
        public var name: String, role: String
        public var ref_audio: String?, ref_text: String?
        public var samples: [String: String]?          // échantillon de la voix de bibliothèque, par langue
        public var timbre_ref_audio: String?           // échantillon de la langue du projet : référence de timbre pour les autres langues
        public var timbre_ref_text: String?
        public var lines_alt: [String: [String]]?      // répliques dans les autres langues, si le projet source les fournit
        public var acting_model: String?               // modèle qui dit les répliques en clonant l'échantillon (dépôt Hugging Face)
        public var sfx: String?                        // cri de créature généré (sans paroles), à mixer ou à jouer seul
    }
    public struct File: Codable {
        public var format = "mcasting/1"
        public var project: String, lang: String
        public var languages = ["fr", "en"]            // langues pour lesquelles ce casting est utilisable (clonage du timbre entre langues)
        public var characters: [String: Entry]
    }

    public static func build(_ p: Project, voices: [Voice]) -> File {
        var out: [String: Entry] = [:]
        for c in p.characters {
            guard let vid = c.voiceID, let v = voices.first(where: { $0.id == vid }) else { continue }
            out[c.id] = Entry(voice_id: v.id, engine: v.engine, recipe: v.recipe, style: c.style,
                              sample: v.samples[p.lang.rawValue].map { Paths.audio.appendingPathComponent($0).path },
                              name: c.name, role: c.role,
                              ref_audio: v.refAudio.map { Paths.audio.appendingPathComponent($0).path }, ref_text: v.refText,
                              samples: v.samples.mapValues { Paths.audio.appendingPathComponent($0).path },
                              timbre_ref_audio: v.refAudio == nil ? v.samples[v.timbreLang.rawValue].map { Paths.audio.appendingPathComponent($0).path } : nil,
                              timbre_ref_text: v.refAudio == nil ? Catalog.sample(for: v, lang: v.timbreLang) : nil,
                              lines_alt: c.altLines,
                              acting_model: SetupState.load().actingModel.flatMap { TTSModel.find($0)?.repo },
                              sfx: c.sfx.map { Paths.audio.appendingPathComponent($0).path })
        }
        return File(project: p.name, lang: p.lang.rawValue, characters: out)
    }

    /// Écrit `<dossier du projet>/casting.json` ; renvoie le chemin.
    @discardableResult
    public static func write(_ p: Project, voices: [Voice]) throws -> URL {
        guard let folder = p.folder, !folder.isEmpty else { throw NSError(domain: "mCASTING", code: 1, userInfo: [NSLocalizedDescriptionKey: "Project has no target folder"]) }
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = URL(fileURLWithPath: folder).appendingPathComponent("casting.json")
        try e.encode(build(p, voices: voices)).write(to: url, options: .atomic)
        return url
    }
}
