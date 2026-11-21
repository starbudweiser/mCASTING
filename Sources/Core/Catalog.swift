// mCASTING — recettes de la bibliothèque (600) générées par combinaison, et textes d'échantillon (voir Languages).
import Foundation

public enum Catalog {
    // Prénoms de recette par langue d'origine neutre (pour reconnaître les voix à l'écoute).
    static let manNames = ["Theo","Lucien","Gaspard","Marcus","Silas","Adrien","Hugo","Noah","Victor","Elias","Roman","Felix","Oscar","Louis","Axel","Bastien","Cyril","Dorian","Etienne","Gabriel"]
    static let womanNames = ["Margaux","Elise","Camille","Nora","Iris","Salome","Juliette","Maya","Lea","Ines","Clara","Alba","Rose","Mila","Zoe","Anna","Sybil","Louise","Thais","Vera"]
    static let childNames = ["Pablo","Lila","Tom","Emma","Jules","Nina","Leo","Eva"]

    struct Axis { let age: String; let desc: String }
    static let ages: [Axis] = [.init(age: "young", desc: "in their early twenties"), .init(age: "adult", desc: "around 35 years old"),
                               .init(age: "mature", desc: "around 50 years old"), .init(age: "senior", desc: "over 65 years old")]
    static let pitches = ["low", "medium", "high"]
    static let tones = ["dry and deadpan", "warm and friendly", "gruff and tired", "cheerful and bright", "calm and soothing",
                        "authoritative", "mischievous", "melancholic", "nervous and fast-talking", "pompous and theatrical"]
    static let animals = ["fox","cat","dog","owl","crow","bear","wolf","rabbit","mouse","frog","horse","pig","parrot","bat","turtle","raccoon","goat","hedgehog","duck","rat"]
    static let creatures = ["dragon","ghost","goblin","troll","robot","vampire","witch","giant","fairy","demon","skeleton","golem","elf","orc","alien","mermaid","imp","wraith","sphinx","gargoyle"]
    static let critterTones = ["gentle and curious", "grumpy and sarcastic", "wise and slow", "shrill and excitable", "sly and whispering", "booming and proud"]

    /// 600 recettes : 150 hommes, 150 femmes, 60 enfants, 120 animaux, 120 créatures.
    public static func recipes() -> [Voice] {
        var v: [Voice] = []
        func pitchWord(_ p: String, _ g: Gender) -> String {
            switch (p, g) { case ("low", .man): return "deep, low-pitched male voice"; case ("medium", .man): return "medium-pitched male voice"; case ("high", .man): return "light, higher-pitched male voice"
            case ("low", _): return "low, husky female voice"; case ("medium", _): return "medium-pitched female voice"; default: return "bright, high-pitched female voice" } }
        var n = 0
        for g in [Gender.man, .woman] {
            let names = g == .man ? manNames : womanNames
            for a in ages { for p in pitches { for (ti, t) in tones.enumerated() {
                // 4 âges × 3 hauteurs × 10 tons = 120 → on garde 150 en ajoutant une variante de débit sur les 30 premières
                n += 1
                let id = "\(g.rawValue)-\(a.age)-\(p)-\(ti)"
                let name = names[n % names.count] + " \(n)"
                v.append(Voice(id: id, name: name, gender: g, age: a.age, pitch: p, tone: t,
                               recipe: "A French-speaking person, \(a.desc), \(pitchWord(p, g)), \(t) delivery, natural conversational pace, clear diction."))
            } } }
            // 30 variantes lentes/rapides
            for i in 0..<30 {
                let a = ages[i % 4], p = pitches[(i / 4) % 3], t = tones[i % tones.count]
                let slow = i % 2 == 0
                n += 1
                v.append(Voice(id: "\(g.rawValue)-x\(i)", name: names[n % names.count] + " \(n)", gender: g, age: a.age, pitch: p, tone: t,
                               recipe: "A person, \(a.desc), \(pitchWord(p, g)), \(t) delivery, \(slow ? "slow, deliberate pace with long pauses" : "quick, energetic pace"), expressive."))
            }
        }
        for (i, k) in (0..<60).enumerated() {
            let boy = k % 2 == 0, p = ["medium", "high"][k % 2]
            let t = tones[k % tones.count]
            v.append(Voice(id: "child-\(i)", name: childNames[k % childNames.count] + " \(k + 1)", gender: .child, age: "kid", pitch: p, tone: t,
                           recipe: "A \(boy ? "boy" : "girl") aged \(5 + k % 8), \(t) delivery, playful, natural child voice."))
        }
        for (i, a) in animals.enumerated() { for (j, t) in critterTones.enumerated() where (i * 6 + j) < 120 {
            v.append(Voice(id: "animal-\(a)-\(j)", name: "\(a.capitalized) \(j + 1)", gender: .animal, age: "n/a", pitch: ["medium","high","low"][j % 3], tone: t, species: a,
                           recipe: "A talking \(a) character voice, \(t), cartoon-like but believable, expressive, clear speech."))
        } }
        for (i, a) in creatures.enumerated() { for (j, t) in critterTones.enumerated() where (i * 6 + j) < 120 {
            v.append(Voice(id: "creature-\(a)-\(j)", name: "\(a.capitalized) \(j + 1)", gender: .creature, age: "n/a", pitch: ["low","medium","high"][j % 3], tone: t, species: a,
                           recipe: "The voice of a \(a): \(t), otherworldly character voice with distinctive texture, clear speech."))
        } }
        return v
    }

    /// Texte d'échantillon (8 à 10 s) dans `lang`, choisi selon le registre de la voix.
    public static func sample(for v: Voice, lang: Lang) -> String {
        let table = lang.samples
        let first = v.name.split(separator: " ").first.map(String.init) ?? v.name
        let idx = (v.tone.contains("nervous") || v.tone.contains("mischievous") || v.tone.contains("melancholic")) ? 1 : 0
        return idx == 0 ? String(format: table[0], first) : table[1]
    }
}
