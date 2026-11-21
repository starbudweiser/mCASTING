// mCASTING — créatures et animaux : espèce devinée, voix de la bibliothèque suggérées, cris générés par un modèle de bruitage.
import Foundation

public enum Creatures {
    /// Mots (français et anglais) → espèce de la bibliothèque (Catalog.animals / Catalog.creatures).
    static let words: [(String, String)] = [
        ("dragon", "dragon"), ("fantôme", "ghost"), ("ghost", "ghost"), ("gobelin", "goblin"), ("goblin", "goblin"), ("troll", "troll"),
        ("robot", "robot"), ("vampire", "vampire"), ("sorcière", "witch"), ("witch", "witch"), ("géant", "giant"), ("giant", "giant"),
        ("fée", "fairy"), ("fairy", "fairy"), ("démon", "demon"), ("demon", "demon"), ("squelette", "skeleton"), ("skeleton", "skeleton"),
        ("golem", "golem"), ("elfe", "elf"), ("elf", "elf"), ("orque", "orc"), ("orc", "orc"), ("alien", "alien"), ("extraterrestre", "alien"),
        ("sirène", "mermaid"), ("mermaid", "mermaid"), ("lutin", "imp"), ("imp", "imp"), ("spectre", "wraith"), ("wraith", "wraith"),
        ("sphinx", "sphinx"), ("gargouille", "gargoyle"), ("gargoyle", "gargoyle"), ("ogre", "troll"),
        ("renard", "fox"), ("fox", "fox"), ("chat", "cat"), ("cat", "cat"), ("chien", "dog"), ("dog", "dog"), ("hibou", "owl"), ("chouette", "owl"),
        ("owl", "owl"), ("corbeau", "crow"), ("crow", "crow"), ("ours", "bear"), ("bear", "bear"), ("loup", "wolf"), ("wolf", "wolf"),
        ("lapin", "rabbit"), ("rabbit", "rabbit"), ("souris", "mouse"), ("mouse", "mouse"), ("grenouille", "frog"), ("frog", "frog"),
        ("cheval", "horse"), ("horse", "horse"), ("cochon", "pig"), ("pig", "pig"), ("perroquet", "parrot"), ("parrot", "parrot"),
        ("chauve-souris", "bat"), ("bat", "bat"), ("tortue", "turtle"), ("turtle", "turtle"), ("raton", "raccoon"), ("raccoon", "raccoon"),
        ("chèvre", "goat"), ("goat", "goat"), ("hérisson", "hedgehog"), ("hedgehog", "hedgehog"), ("canard", "duck"), ("duck", "duck"), ("rat", "rat"),
    ]
    /// Indices de caractère → ton des voix de créatures (Catalog.critterTones).
    static let moods: [(String, String)] = [
        ("moqueu", "sly"), ("rusé", "sly"), ("sly", "sly"), ("murmur", "whispering"), ("nerveu", "shrill"), ("farceu", "shrill"), ("excit", "shrill"),
        ("hautain", "grumpy"), ("grincheu", "grumpy"), ("bougon", "grumpy"), ("sarcas", "sarcastic"), ("sage", "wise"), ("ancien", "wise"), ("vieux", "wise"),
        ("grave", "booming"), ("immense", "booming"), ("fier", "proud"), ("doux", "gentle"), ("curieu", "curious"),
    ]

    static func text(_ c: Character) -> String { (c.name + " " + c.role + " " + (c.notes ?? "")).lowercased() }

    public static func species(_ c: Character) -> String? {
        let t = " " + text(c).replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "'", with: " ") + " "
        return words.first { t.contains(" " + $0.0 + " ") || t.contains(" " + $0.0 + "s ") }?.1
    }
    public static func isAnimal(_ c: Character) -> Bool { c.kind == "animal" || (species(c).map { Catalog.animals.contains($0) } ?? text(c).contains("animal")) }

    /// Les 3 voix de la bibliothèque les plus proches : même espèce et ton d'abord, puis même famille (animal / créature).
    public static func suggestions(for c: Character, in voices: [Voice], count: Int = 3) -> [Voice] {
        let sp = species(c), t = text(c), animal = isAnimal(c)
        let tones = moods.filter { t.contains($0.0) }.map(\.1)
        let pool = voices.filter { !$0.custom && ($0.gender == (animal ? .animal : .creature)) }
        func score(_ v: Voice) -> Int { (v.species == sp ? 10 : 0) + tones.filter { v.tone.contains($0) }.count * 3 }
        return pool.sorted { (score($0), $1.id) > (score($1), $0.id) }.prefix(count).map { $0 }
    }

    /// Description en anglais pour le modèle de bruitage (il ne comprend que l'anglais).
    public static func sfxCaption(for c: Character) -> String {
        let t = text(c), sp = species(c)
        let size = t.contains("immense") || t.contains("géant") || t.contains("grave") ? "huge, deep" : (t.contains("petit") || t.contains("small") ? "small, high pitched" : "")
        let what: String
        switch sp {
        case "dragon": what = "ancient dragon roar, rumbling growl"
        case "goblin", "imp": what = "mischievous goblin cackle, nasty little laugh"
        case "troll", "giant", "orc", "golem": what = "monster grunt and growl, heavy breathing"
        case "ghost", "wraith": what = "ghostly moan, eerie whisper, reverb"
        case "robot": what = "robot servo whirr and electronic beeps"
        case "demon", "vampire": what = "demonic hiss and snarl"
        case "cat": what = (t.contains("hautain") || t.contains("agac")) ? "annoyed house cat meow" : "house cat meow and purr"
        case "dog": what = "dog bark"
        case "wolf": what = "wolf howl"
        case "owl": what = "owl hoot at night"
        case "crow": what = "crow caw"
        case "bear": what = "bear growl"
        case .some(let s): what = "\(s) vocalization"
        case nil: what = "fantasy creature growl"
        }
        return [size, what, "close up, no music"].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// Génère un cri de 4 s pour le personnage (modèle de bruitage), en .m4a dans audio/sfx/.
    @discardableResult
    public static func generateSFX(for c: Character, projectID: String, seed: Int = 7) throws -> String {
        guard let m = TTSModel.find("sfx-stable-audio") else { throw EngineError.notInstalled }
        let rel = "sfx/\(projectID)-\(c.id)-\(seed).m4a"
        try Engine.generateSFX(model: m, caption: sfxCaption(for: c), seconds: 4, seed: seed, to: Paths.audio.appendingPathComponent(rel))
        return rel
    }
}
