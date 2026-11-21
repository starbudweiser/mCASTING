// mCASTING — modèles de données.
import Foundation

public enum Gender: String, Codable, CaseIterable { case man, woman, child, animal, creature }
public enum Lang: String, Codable, CaseIterable {
    case fr, en
    public var qwen: String { self == .fr ? "french" : "english" }
}

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
    public var source: String?      // origine : nom de fichier ou lien
    /// Langue de référence du timbre : le français d'abord (casting rédigé en français), sinon la première langue disponible.
    public var timbreLang: Lang { samples["fr"] != nil ? .fr : (samples.keys.compactMap { Lang(rawValue: $0) }.first ?? .fr) }
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
    public var lines: [String]      // répliques d'exemple (langue du projet)
    public var altLines: [String: [String]]?   // répliques par langue fournies par le projet source (« fr » / « en » → [...])
    /// Répliques à afficher et à dire dans une langue : celles de cette langue si le projet source les fournit, sinon `lines`.
    public func lines(in lang: Lang) -> [String]? { altLines?[lang.rawValue].flatMap { $0.isEmpty ? nil : $0 } }
    public var lineCount: Int?      // nombre total de répliques du personnage dans le projet source
    public var notes: String?
    public var current: CurrentVoice?
    public var voiceID: String?
    public var style: String        // consigne d'émotion par défaut
    public init(id: String = UUID().uuidString, key: String? = nil, name: String, role: String = "", lines: [String] = [], lineCount: Int? = nil,
                notes: String? = nil, current: CurrentVoice? = nil, voiceID: String? = nil, style: String = "") {
        self.id = id; self.key = key; self.name = name; self.role = role; self.lines = lines; self.lineCount = lineCount
        self.notes = notes; self.current = current; self.voiceID = voiceID; self.style = style
    }
}

public struct Project: Codable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var lang: Lang
    public var folder: String?      // dossier où écrire casting.json
    public var characters: [Character]
    public init(id: String = UUID().uuidString, name: String, lang: Lang = .fr, folder: String? = nil, characters: [Character] = []) {
        self.id = id; self.name = name; self.lang = lang; self.folder = folder; self.characters = characters
    }
    public var castCount: Int { characters.filter { $0.voiceID != nil }.count }
}
