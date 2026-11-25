// mCASTING — modèles de données.
import Foundation

public enum Gender: String, Codable, CaseIterable { case man, woman, child, animal, creature }

/// Une « voix » de la bibliothèque = une recette (description VoiceDesign) + un échantillon par langue.
public struct Voice: Codable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var gender: Gender
    public var age: String          // young / adult / senior / kid
    public var pitch: String        // low / medium / high
    public var tone: String         // dry, warm, gruff…
    public var species: String?     // animaux et créatures
    public var recipe: String       // description complète en anglais (VoiceDesign)
    public var engine: String       // "qwen3-voicedesign"
    public var samples: [String: String]   // "fr" / "en" → chemin relatif dans audio/
    public var custom: Bool
    public var refAudio: String?    // voix clonée : extrait de référence (relatif à audio/)
    public var refText: String?     // transcription exacte de l'extrait
    public var source: String?      // origine : nom de fichier ou lien (adresse du serveur pour une voix de serveur)
    public var remoteModel: String? // voix d'un serveur ou d'ElevenLabs : modèle à utiliser
    public var remoteVoice: String? // nom de la voix sur le serveur, ou identifiant de voix ElevenLabs
    // Voix clonées : fiche de classement (bibliothèque « Voix clonées »)
    public var character: String?   // personnage d'origine (« Guybrush Threepwood »)
    public var sourceKind: String?  // game / film / series / other
    public var sourceTitle: String? // « Escape from Monkey Island »
    public var tags: [String]?      // étiquettes libres (Héros, Pirate…)
    public var added: Date?         // date d'ajout
    /// Titre de la source : champ dédié, sinon déduit de l'ancien champ `source` (« mTALKIE · Escape from Monkey Island »).
    public var originTitle: String? {
        if let t = sourceTitle, !t.isEmpty { return t }
        guard custom, refAudio != nil, let s = source, !s.isEmpty, !s.hasPrefix("http") else { return nil }
        if let r = s.range(of: " · ") { return String(s[r.upperBound...]) }
        return s.contains(".") ? nil : s          // un nom de fichier n'est pas une source
    }
    /// Type de source : champ dédié, sinon « game » pour les voix reçues de mTALKIE, « other » sinon.
    public var originKind: String { sourceKind ?? (source?.hasPrefix("mTALKIE") == true ? "game" : (originTitle == nil ? "none" : "other")) }
    public var isClone: Bool { custom && refAudio != nil }
    /// Langue de référence du timbre : le français d'abord (casting rédigé en français), sinon la première langue disponible.
    public var timbreLang: Lang { samples["fr"] != nil ? .fr : (samples.keys.compactMap { Lang(rawValue: $0) }.sorted().first ?? .fr) }
    /// Langue de référence du timbre pour parler `lang` : l'extrait de cette langue s'il existe, sinon celui de `prefer`, sinon `timbreLang`.
    public func timbre(for lang: Lang, prefer: Lang? = nil) -> Lang {
        if samples[lang.rawValue] != nil { return lang }
        if let p = prefer, samples[p.rawValue] != nil { return p }
        return timbreLang
    }
    /// Recette VoiceDesign pour créer l'extrait dans `lang` : la mention « French-speaking » des recettes suit la langue.
    public func recipe(for lang: Lang) -> String {
        lang == .fr ? recipe : recipe.replacingOccurrences(of: "A French-speaking person", with: "A \(lang.english)-speaking person")
    }
    public init(id: String, name: String, gender: Gender, age: String, pitch: String, tone: String, species: String? = nil,
                recipe: String, engine: String = "qwen3-voicedesign", samples: [String: String] = [:], custom: Bool = false,
                refAudio: String? = nil, refText: String? = nil, source: String? = nil) {
        self.refAudio = refAudio; self.refText = refText; self.source = source
        self.id = id; self.name = name; self.gender = gender; self.age = age; self.pitch = pitch; self.tone = tone
        self.species = species; self.recipe = recipe; self.engine = engine; self.samples = samples; self.custom = custom
    }
}

/// Voix déjà utilisée par un projet en cours (information + extraits à écouter pour comparer avec la bibliothèque).
public struct CurrentVoice: Codable, Hashable {
    public struct Sample: Codable, Hashable { public var file: String; public var text: String? }
    public var description: String?
    public var engine: String?
    public var samples: [Sample]
    public init(description: String? = nil, engine: String? = nil, samples: [Sample] = []) { self.description = description; self.engine = engine; self.samples = samples }
}

public struct Character: Codable, Identifiable, Hashable {
    public var id: String
    public var key: String?         // identifiant stable côté projet source (sert à fusionner les imports successifs)
    public var name: String
    public var role: String
    public var lines: [String]      // répliques d'exemple (langue principale du projet)
    public var altLines: [String: [String]]?   // répliques par langue fournies par le projet source (« fr » / « en » → [...])
    /// Répliques fournies dans une langue par le projet source (nil si aucune).
    public func lines(in lang: Lang) -> [String]? { altLines?[lang.rawValue].flatMap { $0.isEmpty ? nil : $0 } }
    /// Répliques à dire dans `lang` pour un projet de langue principale `main` : celles de cette langue, ou `lines` si `lang`
    /// est la principale et qu'aucune autre langue ne les revendique ; nil sinon (on dira alors la phrase type de la voix).
    public func lines(in lang: Lang, main: Lang) -> [String]? {
        if let l = lines(in: lang) { return l }
        guard lang == main, !lines.isEmpty else { return nil }
        if let a = altLines, a.contains(where: { $0.key != lang.rawValue && $0.value == lines }) { return nil }
        return lines
    }
    public var lineCount: Int?      // nombre total de répliques du personnage dans le projet source
    public var notes: String?
    public var current: CurrentVoice?
    public var voiceID: String?
    public var style: String        // consigne d'émotion par défaut
    public var kind: String?        // human / creature / animal (fourni par l'import ou l'analyse des dialogues)
    public var fx: String?          // effet de voix (CreatureFX) appliqué aux répliques, pour les créatures et animaux
    public var sfx: String?         // cri de créature généré (relatif à audio/), pour les personnages non humains
    public var assigned: [AssignedLine]?   // répliques piochées dans la base de répliques et attribuées au personnage
    public init(id: String = UUID().uuidString, key: String? = nil, name: String, role: String = "", lines: [String] = [], lineCount: Int? = nil,
                notes: String? = nil, current: CurrentVoice? = nil, voiceID: String? = nil, style: String = "") {
        self.id = id; self.key = key; self.name = name; self.role = role; self.lines = lines; self.lineCount = lineCount
        self.notes = notes; self.current = current; self.voiceID = voiceID; self.style = style
    }
}

/// Réplique de la base attribuée à un personnage : texte à dire, réplique d'origine et mode d'usage.
public struct AssignedLine: Codable, Hashable, Identifiable {
    public var id: String
    public var text: String          // texte que le personnage dira (réécrit en mode inspiration)
    public var original: String?     // réplique d'origine
    public var source: String?       // titre de la source (jeu, film, série)
    public var key: String?          // nom de la réplique dans la source
    public var speaker: String?      // personnage d'origine
    public var audio: String?        // audio d'origine (chemin absolu), pour réécouter
    public var mode: String          // "inspiration" (réécrite) ou "original" (texte d'origine, essais privés)
    public var emotion: String?
    public init(id: String = UUID().uuidString, text: String, original: String? = nil, source: String? = nil, key: String? = nil,
                speaker: String? = nil, audio: String? = nil, mode: String = "inspiration", emotion: String? = nil) {
        self.id = id; self.text = text; self.original = original; self.source = source; self.key = key
        self.speaker = speaker; self.audio = audio; self.mode = mode; self.emotion = emotion
    }
    public init(record r: LineRecord, mode: String, text: String? = nil, emotion: String? = nil) {
        self.init(text: (text?.isEmpty == false ? text! : r.text), original: r.text, source: r.sourceTitle, key: r.key,
                  speaker: r.character.isEmpty ? nil : r.character, audio: r.audio, mode: mode, emotion: emotion)
    }
}

public struct Project: Codable, Identifiable, Hashable {
    public var id: String
    public var name: String
    /// Langue principale : celle des répliques (`lines`) et du casting.
    public var lang: Lang
    /// Langues du projet (principale en premier, secondaire facultative). nil = projet 1.x (français + anglais).
    public var langs: [Lang]?
    /// Langue d'écoute choisie dans la barre latérale (une des langues du projet).
    public var active: Lang?
    public var folder: String?      // dossier où écrire casting.json
    public var characters: [Character]
    public init(id: String = UUID().uuidString, name: String, lang: Lang = .fr, second: Lang? = nil, folder: String? = nil, characters: [Character] = []) {
        self.id = id; self.name = name; self.lang = lang; self.folder = folder; self.characters = characters
        self.langs = [lang] + (second.map { $0 == lang ? [] : [$0] } ?? [])
    }
    public var castCount: Int { characters.filter { $0.voiceID != nil }.count }
    /// Langues du projet, principale en premier.
    public var languages: [Lang] { langs.map { $0.isEmpty ? [lang] : $0 } ?? [lang] }
    /// Langue écoutée en ce moment.
    public var activeLang: Lang { active.flatMap { languages.contains($0) ? $0 : nil } ?? lang }
    /// Change les langues : la première devient la principale.
    public mutating func setLanguages(_ l: [Lang]) {
        var seen = Set<Lang>(); let u = l.filter { seen.insert($0).inserted }
        guard let first = u.first else { return }
        if first != lang {                     // les répliques restent attachées à leur langue d'origine
            let old = lang.rawValue
            for i in characters.indices where !characters[i].lines.isEmpty {
                var a = characters[i].altLines ?? [:]
                if a[old] == nil { a[old] = characters[i].lines }
                characters[i].altLines = a
                if let n = a[first.rawValue], !n.isEmpty { characters[i].lines = n }
            }
        }
        lang = first; langs = Array(u.prefix(2))
        if let a = active, !languages.contains(a) { active = nil }
    }

    enum CodingKeys: String, CodingKey { case id, name, lang, langs, active, folder, characters }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); name = try c.decode(String.self, forKey: .name)
        folder = try c.decodeIfPresent(String.self, forKey: .folder)
        characters = try c.decodeIfPresent([Character].self, forKey: .characters) ?? []
        let l = try c.decodeIfPresent(Lang.self, forKey: .lang) ?? .fr
        if let ls = try c.decodeIfPresent([Lang].self, forKey: .langs) {
            lang = l; langs = ls; active = try c.decodeIfPresent(Lang.self, forKey: .active)
        } else {
            // Projet 1.x : répliques en français, bibliothèque en français et en anglais, langue écoutée = ancienne « langue du projet ».
            lang = .fr; langs = [.fr, .en]; active = l
        }
    }
}
