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
            (fGender == nil || v.gender == fGender) && (fLang == nil || v.samples[fLang!.rawValue] != nil) &&
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

    func start() {
        Paths.prepare(); reload(force: true)
        if CommandLine.arguments.contains("--demo-busy") { busyFlag = true; task = "library" }      // essais d'interface : calcul simulé
        if voices.isEmpty { voices = (try? LibraryGenerator.ensureCatalog()) ?? [] }
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
    private func run(_ title: String, _ work: @escaping @Sendable (@escaping @Sendable (String) -> Void) throws -> Void) {
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
    func preview(voice: Voice, text: String, style: String) {
        let lang = project?.lang ?? .fr
        run("preview") { log in
            let u = try LibraryGenerator.preview(voice: voice, text: text, lang: lang, style: style)
            Task { @MainActor in AppState.shared.play(rel: u.path) }
        }
    }
}
