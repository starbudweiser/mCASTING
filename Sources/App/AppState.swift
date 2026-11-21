// mCASTING — état partagé de l'interface ; surveille les fichiers pour voir les changements faits par un agent (MCP).
import SwiftUI
import AVFoundation

enum Screen: String, CaseIterable { case projects, casting, library, clone, models, settings, generation }

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var screen: Screen = .casting
    @Published var projects: [Project] = []
    @Published var voices: [Voice] = []
    @Published var projectID: String?
    @Published var characterID: String?
    @Published var abVoiceID: String?
    // filtres bibliothèque
    @Published var fGender: Gender? = nil
    @Published var fLang: Lang? = nil
    @Published var fText = ""
    @Published var fAge: String? = nil
    @Published var fTone: String? = nil
    @Published var fFav = false
    @Published var revealTick = 0
    @Published var multi: Set<String> = []        // personnages sélectionnés (⌘-clic, ⇧-clic) pour une action groupée
    @Published var expressive = UserDefaults.standard.bool(forKey: "expressive") { didSet { UserDefaults.standard.set(expressive, forKey: "expressive") } }
    @Published var favorites: Set<String> = DataStore.favorites()
    @Published var avg: Double = 5.6
    @Published var castTab = 0
    @Published var projectLang: Lang = .fr
    // moteur / calcul
    @Published var engineInstalled = Engine.installed
    @Published var log = ""
    @Published var task = ""              // description du calcul en cours
    @Published var progress: Double = 0
    @Published var busyFlag = false
    @Published var error: String?
    @Published var info: String?
    private var cancelRequested = false
    private var player: AVAudioPlayer?
    @Published var playingPath: String?
    private var stamp: (Date, Date) = (.distantPast, .distantPast)
    private var timer: Timer?

    var busy: Bool { busyFlag }
    var project: Project? { projects.first { $0.id == projectID } }
    var character: Character? { project?.characters.first { $0.id == characterID } }
    var filteredVoices: [Voice] {
        let q = fText.lowercased()
        return voices.filter { v in
            (!fFav || favorites.contains(v.id)) && (fGender == nil || v.gender == fGender) && (fLang == nil || v.samples[fLang!.rawValue] != nil) &&
            (fAge == nil || v.age == fAge || (fAge == "senior" && v.age == "mature")) &&
            (fTone == nil || (fTone == "low" && v.pitch == "low") || (fTone == "high" && v.pitch == "high") || (fTone != "low" && fTone != "high" && v.tone.contains(fTone!))) &&
            (q.isEmpty || (v.name + " " + v.recipe + " " + v.tone + " " + (v.species ?? "")).lowercased().contains(q))
        }
    }
    var remainingSamples: Int { LibraryGenerator.remaining(voices) }
    var libVoices: [Voice] { voices.filter { !$0.custom } }
    var doneSamples: Int { libVoices.reduce(0) { $0 + $1.samples.count } }
    var totalSamples: Int { libVoices.count * Lang.allCases.count }
    func mcpLog(_ n: Int = 6) -> String {
        guard let t = try? String(contentsOf: Paths.home.appendingPathComponent("mcp.log"), encoding: .utf8) else { return "" }
        return t.split(separator: "\n").suffix(n).joined(separator: "\n")
    }
    /// Importe un projet (format mcasting-project/1) ou, avec `intoCurrent`, des personnages dans le projet affiché.
    func importProject(from url: URL, intoCurrent: Bool = false) {
        guard let data = try? Data(contentsOf: url) else { error = "Cannot read " + url.lastPathComponent; return }
        var rep: ProjectImport.Report?
        do {
            projects = try DataStore.updateProjects { rep = try ProjectImport.apply(data, projectName: intoCurrent ? self.project?.name : nil, to: &$0) }
            stamp.0 = DataStore.modified(Paths.projects)
        } catch { self.error = error.localizedDescription; return }
        guard let rep else { return }
        if let p = projects.first(where: { $0.name == rep.project }) { projectID = p.id; characterID = p.characters.first?.id }
        info = L.t("imp.done", rep.created.count, rep.updated.count, rep.unchanged.count) + (rep.warnings.isEmpty ? "" : "\n" + L.t("imp.warn", rep.warnings.count))
        screen = .casting
    }
    func importCharacters(from url: URL) {
        struct C: Decodable { var name: String; var role: String?; var lines: [String]? }
        guard let pid = projectID, let data = try? Data(contentsOf: url), let cs = try? JSONDecoder().decode([C].self, from: data) else { error = "JSON: [{name, role, lines}]"; return }
        mutate { all in
            guard let i = all.firstIndex(where: { $0.id == pid }) else { return }
            for c in cs where !all[i].characters.contains(where: { $0.name.lowercased() == c.name.lowercased() }) { all[i].characters.append(Character(name: c.name, role: c.role ?? "", lines: c.lines ?? [])) }
        }
    }

    /// Clic sur le nom vert d'un personnage : l'affiche dans la liste des voix, filtres levés, voisines visibles.
    func showVoice(of c: Character) {
        characterID = c.id; castTab = 0
        fGender = nil; fLang = nil; fText = ""; fAge = nil; fTone = nil; fFav = false
        revealTick += 1
    }
    func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
        do { try DataStore.saveFavorites(favorites) } catch { self.error = error.localizedDescription }
    }

    func start() {
        Paths.prepare(); reload(force: true)
        if CommandLine.arguments.contains("--demo-busy") { busyFlag = true; task = "library" }      // essais d'interface : calcul simulé
        if voices.isEmpty { voices = (try? LibraryGenerator.ensureCatalog()) ?? [] }
        if CommandLine.arguments.contains("--demo-multi") { multi = Set((project?.characters ?? []).prefix(4).map(\.id)) }   // essais d'interface : sélection multiple
        let st = SetupState.load()
        if CommandLine.arguments.contains("--setup") || (!st.completed && (projects.isEmpty || doneSamples == 0)) { SetupModel.shared.start(quick: false) }
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in Task { @MainActor in AppState.shared.reload() } }
    }
    func reload(force: Bool = false) {
        let a = DataStore.modified(Paths.projects), b = DataStore.modified(Paths.voices)
        guard force || a != stamp.0 || b != stamp.1 else { return }
        stamp = (a, b)
        projects = DataStore.projects(); voices = DataStore.voices()
        if projectID == nil || project == nil { projectID = projects.first?.id }
        if character == nil { characterID = project?.characters.first?.id }
    }

    // MARK: projets
    func mutate(_ body: @escaping (inout [Project]) -> Void) {
        do { projects = try DataStore.updateProjects(body); stamp.0 = DataStore.modified(Paths.projects) } catch { self.error = error.localizedDescription }
    }
    func newProject(name: String, lang: Lang) {
        let p = Project(name: name, lang: lang); mutate { $0.append(p) }; projectID = p.id; screen = .casting
    }
    func addCharacter(name: String) {
        guard let pid = projectID else { return }
        let c = Character(name: name); mutate { all in if let i = all.firstIndex(where: { $0.id == pid }) { all[i].characters.append(c) } }
        characterID = c.id
    }
    func update(character id: String, _ f: @escaping (inout Character) -> Void) {
        guard let pid = projectID else { return }
        mutate { all in
            if let i = all.firstIndex(where: { $0.id == pid }), let j = all[i].characters.firstIndex(where: { $0.id == id }) { f(&all[i].characters[j]) }
        }
    }
    var filtersActive: Bool { fGender != nil || fLang != nil || fAge != nil || fTone != nil || fFav || !fText.isEmpty }
    /// Genre deviné d'après la description du personnage (« farm woman », « grumbling man »…) ; nil si rien d'évident.
    static func guessGender(_ c: Character) -> Gender? {
        let words = Set((c.role + " " + (c.notes ?? "")).lowercased().split { !$0.isLetter }.map(String.init))
        if !words.isDisjoint(with: ["woman", "women", "girl", "female", "lady", "mother", "queen", "witch", "she"]) { return .woman }
        if !words.isDisjoint(with: ["child", "kid", "children"]) { return .child }
        if !words.isDisjoint(with: ["man", "men", "boy", "male", "father", "king", "he", "guy"]) { return .man }
        return nil
    }
    /// Voix au hasard pour des personnages. Filtres posés : on tire parmi les voix filtrées ; sinon dans la bibliothèque, en
    /// respectant le genre deviné d'après la description (sans indice : voix d'hommes ou de femmes, jamais d'animaux ni de créatures). Les voix pas encore utilisées dans le projet passent en premier.
    func assignRandom(_ ids: [String]) {
        guard let p = project else { return }
        let filtered = filtersActive
        let base = filtered ? filteredVoices : voices.filter { !$0.custom }
        guard !base.isEmpty else { return }
        let targets = Set(ids)
        var used = Set(p.characters.filter { !targets.contains($0.id) }.compactMap(\.voiceID))
        var picks: [String: String] = [:]
        for id in ids {
            guard let c = p.characters.first(where: { $0.id == id }) else { continue }
            var pool = base
            if !filtered {
                let g = AppState.guessGender(c)
                let m = base.filter { g != nil ? $0.gender == g : ($0.gender == .man || $0.gender == .woman) }   // sans indice : voix humaines adultes
                if !m.isEmpty { pool = m }
            }
            let fresh = pool.filter { !used.contains($0.id) }
            guard let v = (fresh.isEmpty ? pool : fresh).randomElement() else { continue }
            picks[id] = v.id; used.insert(v.id)
        }
        mutate { all in
            guard let i = all.firstIndex(where: { $0.id == p.id }) else { return }
            for j in all[i].characters.indices { if let v = picks[all[i].characters[j].id] { all[i].characters[j].voiceID = v } }
        }
    }
    func clearVoice(_ ids: [String]) {
        guard let pid = projectID else { return }
        let t = Set(ids)
        mutate { all in
            guard let i = all.firstIndex(where: { $0.id == pid }) else { return }
            for j in all[i].characters.indices where t.contains(all[i].characters[j].id) { all[i].characters[j].voiceID = nil }
        }
    }
    func choose(voice id: String) { if abVoiceID == id { abVoiceID = nil }; if let c = characterID { update(character: c) { $0.voiceID = id } } }
    func writeCasting() {
        guard let p = project else { return }
        do { let u = try CastingExport.write(p, voices: voices); log = "casting.json → \(u.path)" } catch { self.error = error.localizedDescription }
    }

    // MARK: audio
    func play(rel: String?) {
        guard let rel else { return }
        let url = rel.hasPrefix("/") ? URL(fileURLWithPath: rel) : Paths.audio.appendingPathComponent(rel)
        if playingPath == url.path { player?.stop(); playingPath = nil; return }
        player = try? AVAudioPlayer(contentsOf: url); player?.play(); playingPath = url.path
        DispatchQueue.main.asyncAfter(deadline: .now() + (player?.duration ?? 1) + 0.1) { [weak self] in if self?.playingPath == url.path { self?.playingPath = nil } }
    }

    // MARK: tâches longues (une à la fois)
    func run(_ title: String, _ work: @escaping @Sendable (@escaping @Sendable (String) -> Void) throws -> Void) {
        guard !busyFlag else { return }
        busyFlag = true; task = title; progress = 0; log = ""; cancelRequested = false
        DispatchQueue.global(qos: .userInitiated).async {
            do { try work { s in Task { @MainActor in AppState.shared.log += s } } }
            catch { Task { @MainActor in AppState.shared.error = error.localizedDescription } }
            Task { @MainActor in let a = AppState.shared; a.busyFlag = false; a.task = ""; a.engineInstalled = Engine.installed; a.reload(force: true) }
        }
    }
    func installEngine() { run("engine") { log in try Engine.install(log: log) } }
    func download(_ m: TTSModel) { run(m.title) { log in try Engine.download(m, log: log) } }
    func generateLibrary() {
        run("library") { log in
            try LibraryGenerator.run(progress: { d, t, n, dur in
                Task { @MainActor in let a = AppState.shared; a.progress = Double(d) / Double(max(t, 1)); a.avg = a.avg * 0.8 + dur * 0.2 }
                log("\(n) · \(Int(dur)) s\n")
            }, cancel: { DispatchQueue.main.sync { AppState.shared.cancelRequested } })
        }
    }
    func cancel() { cancelRequested = true }
    private var warnedNoAlt = false
    /// Réplique à dire dans la langue du projet : le texte d'origine en FR ; en EN, la réplique anglaise du même rang si l'import
    /// l'a fournie, sinon la phrase type de la bibliothèque (avec un avertissement, une fois).
    func spokenLine(_ c: Character, _ i: Int, voice: Voice) -> String {
        let pl = project?.lang ?? .fr
        if let a = c.lines(in: pl) { return a.indices.contains(i) ? a[i] : a[0] }
        if pl == .fr { return c.lines.indices.contains(i) ? c.lines[i] : (c.lines.first ?? "") }
        if !warnedNoAlt { warnedNoAlt = true; info = L.t("alt.missing") }
        return Catalog.sample(for: voice, lang: pl)
    }
    func preview(voice: Voice, text: String, style: String, expressive: Bool? = nil) {
        let expr = expressive ?? self.expressive
        let lang = project?.lang ?? .fr
        run("preview") { log in
            let u = try LibraryGenerator.preview(voice: voice, text: text, lang: lang, style: style, expressive: expr, timbreFrom: voice.samples[lang.rawValue] != nil ? lang : voice.timbreLang)
            Task { @MainActor in AppState.shared.play(rel: u.path) }
        }
    }
}
