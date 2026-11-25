// mCASTING — guide « Premiers pas » (maquettes/guide.html) : une question par écran, choix recommandé déjà fait.
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SetupModel: ObservableObject {
    static let shared = SetupModel()
    @Published var open = false
    @Published var step = 0
    @Published var quick = false                 // nouveau projet après une première configuration : on ne repose pas les choix du Mac
    // 1 · Projet
    @Published var name = ""
    @Published var folder: String?
    @Published var lang: Lang = SetupModel.defaultMain
    @Published var lang2: Lang? = SetupModel.defaultMain == .en ? nil : .en
    /// Langue principale proposée : celle du système si la bibliothèque sait la faire, sinon l'anglais.
    static var defaultMain: Lang { Languages.library.contains(Lang.system) ? Lang.system : .en }
    @Published var projectID: String?
    // 2 · Préparation
    @Published var assistant = "cloud"
    @Published var agents: [AgentInstaller.Agent] = []
    @Published var llm: DialogueAnalyzer.Server?
    @Published var llmModel = ""
    @Published var confirmInstall = false
    @Published var analyzing = false
    @Published var analyzeStatus = ""
    @Published var analyzed = false
    // 3 · Dialogues
    @Published var imported: String?
    @Published var importInfo = ""
    // 4 · Voix
    @Published var compare: Set<String> = []
    @Published var voiceMode = "mac"
    @Published var serverURL = ""
    @Published var serverKey = ""
    @Published var serverModels: [String] = []
    @Published var serverModel = ""
    @Published var serverStatus = ""
    @Published var serverLibrary = false
    @Published var elKey = ""
    @Published var elStatus = ""
    @Published var remoteBusy = false
    // 5 · Écoute
    @Published var results: [String: [URL]] = [:]
    @Published var times: [String: Double] = [:]
    @Published var lines: [String] = []
    @Published var running = false
    @Published var status = ""
    @Published var chosen: String?

    var steps: [Int] {
        if quick { return [0, 1, 2] + (creatures.isEmpty ? [] : [5]) }
        switch voiceMode {
        case "server": return [0, 1, 2, 3] + (creatures.isEmpty ? [] : [5]) + [6]     // l'écoute comparée clone des extraits : elle reste sur ce Mac
        case "cloud": return [0, 1, 2, 3] + (creatures.isEmpty ? [] : [5])            // pas de bibliothèque à créer : on caste dans les voix du service
        default: return [0, 1, 2, 3, 4] + (creatures.isEmpty ? [] : [5]) + [6]
        }
    }
    var project: Project? { AppState.shared.projects.first { $0.id == projectID } }
    var creatures: [Character] { (project?.characters ?? []).filter { SetupModel.isCreature($0) } }
    var hw: Hardware { .current }
    var models: [TTSModel] { TTSModel.acting.filter { hw.fit(ramGB: $0.ramGB) != .hidden } }
    var recommended: String { hw.fit(ramGB: TTSModel.find("qwen3-base")!.ramGB) == .proposed ? "qwen3-base" : "omnivoice" }

    static func isCreature(_ c: Character) -> Bool {
        if let k = c.kind { return k != "human" }
        if Creatures.species(c) != nil { return true }
        let t = (c.name + " " + c.role + " " + (c.notes ?? "")).lowercased()
        return ["creature", "créature", "monster", "monstre", "dragon", "goblin", "gobelin", "troll", "ogre", "ghost", "fantôme", "spectre",
                "demon", "démon", "robot", "animal", "cat ", "chat ", "dog", "chien", "wolf", "loup", "bird", "oiseau", "beast", "bête", "lutin", "géant", "giant"]
            .contains { t.contains($0) }
    }

    func start(quick q: Bool) {
        let st = SetupState.load()
        quick = q; step = 0; name = ""; folder = nil; lang = Self.defaultMain; lang2 = Self.defaultMain == .en ? nil : .en; projectID = nil; imported = nil; importInfo = ""
        results = [:]; times = [:]; chosen = st.actingModel; assistant = st.assistant ?? "cloud"
        compare = Set(st.compare.isEmpty ? [recommended] + (models.contains { $0.id == "fish-drama3" } ? ["fish-drama3"] : []) : st.compare)
        voiceMode = st.voiceMode; serverURL = st.serverURL ?? ""; serverLibrary = st.serverLibrary; serverModels = []; serverStatus = ""; elStatus = ""
        serverKey = ""; elKey = ""
        detect(); open = true
    }

    func saveVoiceMode() {
        var st = SetupState.load(); st.voiceMode = voiceMode; st.serverURL = serverURL.isEmpty ? nil : serverURL; st.serverLibrary = serverLibrary; st.save()
    }
    func testServer() {
        let u = serverURL, k = serverKey
        if !k.isEmpty { Keychain.set("server", k) }
        remoteBusy = true; serverStatus = L.t("su.v.testing")
        DispatchQueue.global().async {
            let r = Result { try VoiceServer.models(u) }
            Task { @MainActor in
                let m = SetupModel.shared; m.remoteBusy = false
                switch r {
                case .success(let ms):
                    m.serverModels = ms.filter { !["whisper", "asr", "stt", "llm", "instruct"].contains(where: $0.lowercased().contains) }
                    m.serverModel = m.serverModels.first { !$0.lowercased().contains("voicedesign") } ?? m.serverModels.first ?? ""
                    m.serverStatus = L.t("su.v.connected", m.serverModels.count)
                    if VoiceServer.designModel(in: ms) == nil { m.serverLibrary = false }
                    m.saveVoiceMode()
                case .failure(let e): m.serverModels = []; m.serverStatus = L.t("su.v.unreachable") + " · " + e.localizedDescription
                }
            }
        }
    }
    func importServerVoices() {
        let u = serverURL, model = serverModel
        AppState.shared.run("server") { _ in
            let n = try VoiceServer.importVoices(u, model: model) { i, t in Task { @MainActor in SetupModel.shared.serverStatus = L.t("su.v.importing", i, t) } }
            Task { @MainActor in SetupModel.shared.serverStatus = L.t("su.v.imported", n); AppState.shared.reload(force: true) }
        }
    }
    func checkElevenLabs() {
        if !elKey.isEmpty { Keychain.set("elevenlabs", elKey); elKey = "" }
        remoteBusy = true; elStatus = L.t("su.v.testing")
        DispatchQueue.global().async {
            let r = Result { try ElevenLabs.balance() }
            Task { @MainActor in
                let m = SetupModel.shared; m.remoteBusy = false
                switch r {
                case .success(let b): m.elStatus = L.t("su.v.el.balance", b.left, b.limit); m.saveVoiceMode()
                case .failure(let e): m.elStatus = L.t("su.v.el.bad") + " · " + e.localizedDescription
                }
            }
        }
    }
    func importElevenLabs() {
        AppState.shared.run("elevenlabs") { _ in
            let n = try ElevenLabs.importVoices { i, t in Task { @MainActor in SetupModel.shared.elStatus = L.t("su.v.importing", i, t) } }
            Task { @MainActor in SetupModel.shared.elStatus = L.t("su.v.imported", n); AppState.shared.reload(force: true) }
        }
    }

    func detect() {
        agents = AgentInstaller.detect().filter(\.present)
        DispatchQueue.global().async {
            let found = DialogueAnalyzer.discover().first
            Task { @MainActor in let m = SetupModel.shared; m.llm = found; m.llmModel = found.map { DialogueAnalyzer.preferred($0) } ?? "" }
        }
    }
    /// Installe le skill et le serveur MCP dans les agents présents (après confirmation dans la vue).
    func installAgents() {
        var notes: [String] = [], errors: [String] = []
        for a in agents where !a.installed {
            do { if let n = try AgentInstaller.install(a.id) { notes.append(a.name + " : " + n) } } catch { errors.append(a.name + " : " + error.localizedDescription) }
        }
        agents = AgentInstaller.detect().filter(\.present)
        if !errors.isEmpty { AppState.shared.error = errors.joined(separator: "\n") }
        else { AppState.shared.info = L.t("su.a.installed") + (notes.isEmpty ? "" : "\n\n" + L.t("su.a.manual") + "\n" + notes.joined(separator: "\n")) }
    }
    /// Analyse des personnages par l'IA locale ; complète type et description de voix.
    func analyze() {
        guard let srv = llm, let pid = projectID, !analyzing else { return }
        let chars = project?.characters ?? [], model = llmModel
        analyzing = true; analyzeStatus = L.t("su.d.analyzing", srv.name)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let rs = try DialogueAnalyzer.analyze(chars, server: srv, model: model) { n, t in
                    Task { @MainActor in SetupModel.shared.analyzeStatus = L.t("su.d.analyzing", srv.name) + " \(n)/\(t)" }
                }
                Task { @MainActor in
                    AppState.shared.mutate { all in
                        guard let i = all.firstIndex(where: { $0.id == pid }) else { return }
                        for j in all[i].characters.indices { DialogueAnalyzer.apply(rs, to: &all[i].characters[j]) }
                    }
                    let m = SetupModel.shared; m.analyzing = false; m.analyzed = true
                }
            } catch {
                Task { @MainActor in let m = SetupModel.shared; m.analyzing = false; AppState.shared.error = error.localizedDescription }
            }
        }
    }

    var index: Int { steps.firstIndex(of: step) ?? 0 }
    func next() {
        if step == 0 { saveProject() }
        if step == 1 { var st = SetupState.load(); st.assistant = assistant; st.save() }
        if step == 3 { saveVoiceMode(); var st = SetupState.load(); st.compare = Array(compare); st.save() }
        if step == 4, let c = chosen { var st = SetupState.load(); st.actingModel = c; st.save() }
        if index + 1 < steps.count { step = steps[index + 1] } else { finish(library: false) }
    }
    func back() { if index > 0 { step = steps[index - 1] } }

    func saveProject() {
        let s = AppState.shared
        let nm = name.trimmingCharacters(in: .whitespaces).isEmpty ? L.t("proj.new") : name
        if let pid = projectID {
            let ls = [lang] + (lang2.map { [$0] } ?? [])
            s.mutate { all in if let i = all.firstIndex(where: { $0.id == pid }) { all[i].name = nm; all[i].folder = self.folder; all[i].setLanguages(ls) } }
        } else {
            let p = Project(name: nm, lang: lang, second: lang2, folder: folder); s.mutate { $0.append(p) }; projectID = p.id
        }
        s.projectID = projectID
    }

    /// Importe un fichier de répliques dans le projet du guide (le nom du fichier ne crée pas un autre projet).
    func importDialogues(_ url: URL) {
        guard let pid = projectID, var data = try? Data(contentsOf: url) else { return }
        let ext = url.pathExtension.lowercased()
        if ext != "json" {
            guard let t = String(data: data, encoding: .utf8), let d = DialogueAnalyzer.convert(t, ext: ext) else { AppState.shared.error = L.t("su.d.unreadable"); return }
            data = d
        }
        analyzed = false
        let nm = project?.name ?? name
        if var o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            o["name"] = nm; if o["folder"] == nil, let f = folder { o["folder"] = f }; o["languages"] = ([lang] + (lang2.map { [$0] } ?? [])).map(\.rawValue)
            data = (try? JSONSerialization.data(withJSONObject: o)) ?? data
        }
        do {
            var rep: ProjectImport.Report?
            AppState.shared.projects = try DataStore.updateProjects { rep = try ProjectImport.apply(data, projectName: nm, to: &$0) }
            AppState.shared.projectID = pid
            imported = url.lastPathComponent
            let n = project?.characters.count ?? 0, l = project?.characters.reduce(0) { $0 + $1.lines.count } ?? 0
            importInfo = L.t("su.dlg.done", n, l) + ((rep?.warnings.isEmpty ?? true) ? "" : " · " + L.t("imp.warn", rep!.warnings.count))
        } catch { AppState.shared.error = error.localizedDescription }
    }

    /// Écoute comparée : installe le moteur si besoin, télécharge les modèles cochés, puis chaque modèle dit les mêmes répliques
    /// avec la même voix de la bibliothèque (son extrait est cloné ; créé d'abord par VoiceDesign s'il n'existe pas encore).
    func prepareLines() {
        var texts = (project?.characters ?? []).filter { !SetupModel.isCreature($0) }.compactMap { $0.lines(in: lang, main: project?.lang ?? lang)?.first }.prefix(3).map { $0 }
        let demo = lang == .fr ? Self.demoFR : lang == .en ? Self.demoEN : [String(format: lang.samples[0], "Alex"), lang.samples[1]]
        if texts.count < 3 { texts += demo.prefix(3 - texts.count) }
        lines = texts
    }
    func runComparison() {
        guard !running, !AppState.shared.busy else { return }
        let p = project, lg = lang
        prepareLines(); let texts = lines
        results = [:]; times = [:]; running = true
        let first = p?.characters.first { !SetupModel.isCreature($0) }
        let gender = first.flatMap { AppState.guessGender($0) } ?? .man
        let voiceID = AppState.shared.voices.first { $0.gender == gender && !$0.custom }?.id ?? "man-young-medium-0"
        let ids = TTSModel.acting.map(\.id).filter { compare.contains($0) }
        AppState.shared.run("compare") { log in
            func say(_ s: String) { Task { @MainActor in SetupModel.shared.status = s } }
            if !Engine.installed { say(L.t("su.ec.engine")); try Engine.install(log: log) }
            for m in [TTSModel.find("qwen3-voicedesign")!] + ids.compactMap({ TTSModel.find($0) }) where !m.upToDate {
                say(L.t("su.ec.dl", L.t(m.nameKey.isEmpty ? "mdl.ref" : m.nameKey))); try Engine.download(m, log: log)
            }
            say(L.t("su.ec.ref"))
            let voice = try LibraryGenerator.ensureSample(voiceID, lang: lg)
            for id in ids {
                guard let m = TTSModel.find(id) else { continue }
                say(L.t("su.ec.gen", L.t(m.nameKey)))
                var urls: [URL] = [], total = 0.0
                for t in texts {
                    let out = Paths.audio.appendingPathComponent("preview/compare-\(id)-\(urls.count).m4a")
                    total += try LibraryGenerator.speak(voice: voice, text: t, lang: lg, refLang: lg, style: "", model: m, to: out)
                    urls.append(out)
                    let u = urls
                    Task { @MainActor in SetupModel.shared.results[id] = u }
                }
                let avg = total / Double(max(texts.count, 1))
                Task { @MainActor in SetupModel.shared.times[id] = avg }
            }
            Task { @MainActor in let m = SetupModel.shared; m.running = false; m.status = ""; if m.chosen == nil || !ids.contains(m.chosen!) { m.chosen = ids.first } }
        }
    }
    @Published var sfxRunning = false
    @Published var sfxStatus = ""
    var sfxModel: TTSModel { TTSModel.find("sfx-stable-audio")! }

    func assign(_ voiceID: String, to c: Character) {
        let pid = projectID
        AppState.shared.mutate { all in
            guard let i = all.firstIndex(where: { $0.id == pid }), let j = all[i].characters.firstIndex(where: { $0.id == c.id }) else { return }
            all[i].characters[j].voiceID = all[i].characters[j].voiceID == voiceID ? nil : voiceID
        }
    }
    func setFX(_ id: String?, for c: Character) {
        let pid = projectID
        AppState.shared.mutate { all in
            guard let i = all.firstIndex(where: { $0.id == pid }), let j = all[i].characters.firstIndex(where: { $0.id == c.id }) else { return }
            all[i].characters[j].fx = id
        }
    }
    /// Cris des créatures par le modèle de bruitage (téléchargé au premier usage), un fichier par personnage.
    func generateSFX(only one: Character? = nil) {
        guard !sfxRunning, !AppState.shared.busy, let pid = projectID else { return }
        let list = one.map { [$0] } ?? creatures, m = sfxModel
        sfxRunning = true
        AppState.shared.run("sfx") { log in
            func say(_ t: String) { Task { @MainActor in SetupModel.shared.sfxStatus = t } }
            if !Engine.installed { say(L.t("su.ec.engine")); try Engine.install(log: log) }
            if !m.installed { say(L.t("su.ec.dl", L.t("mdl.sfx"))); try Engine.download(m, log: log) }
            for c in list {
                say(L.t("su.c.making", c.name))
                let seed = c.sfx == nil ? 7 : Int.random(in: 1...9999)
                let rel = try Creatures.generateSFX(for: c, projectID: pid, seed: seed)
                try DataStore.updateProjects { all in
                    if let i = all.firstIndex(where: { $0.id == pid }), let j = all[i].characters.firstIndex(where: { $0.id == c.id }) { all[i].characters[j].sfx = rel }
                }
            }
            Task { @MainActor in let s = SetupModel.shared; s.sfxRunning = false; s.sfxStatus = "" }
        }
    }

    static let demoFR = ["Hé hé hé ! Vous croyiez vraiment m'échapper ?", "Qui ose entrer dans mon château à cette heure-ci ?", "Approchez, voyageur. La Reine vous attend depuis longtemps."]
    static let demoEN = ["Hee hee hee! Did you really think you could escape me?", "Who dares to enter my castle at this hour?", "Come closer, traveller. The Queen has been waiting for you."]

    func finish(library: Bool) {
        var st = SetupState.load(); st.completed = true; st.step = 0; st.projectID = projectID; st.save()
        open = false
        let s = AppState.shared
        s.projectID = projectID ?? s.projectID; s.characterID = s.project?.characters.first?.id; s.screen = .casting
        if library { s.generateLibrary() }
    }
}

// MARK: Vue
struct SetupWizard: View {
    @ObservedObject var m = SetupModel.shared
    @ObservedObject var s = AppState.shared
    static let titles = ["su.s.project", "su.s.prep", "su.s.dialogues", "su.s.voice", "su.s.listen", "su.s.creatures", "su.s.library"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                BrandName().padding(.leading, 104)
                Spacer()
                Text(L.t("su.title")).font(.system(size: 12)).foregroundStyle(Flat.text2)
            }.frame(height: 52).padding(.trailing, 18)
            .overlay(alignment: .bottom) { Rectangle().fill(Flat.line).frame(height: 1) }
            content
        }
        .background(Flat.bg).foregroundStyle(Flat.text).font(.system(size: 13)).tint(Flat.acc)
    }

    var content: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(m.steps.enumerated()), id: \.offset) { k, st in
                    HStack(spacing: 10) {
                        Text(k < m.index ? "✓" : "\(k + 1)").font(.system(size: 11, weight: .semibold)).frame(width: 22, height: 22)
                            .foregroundStyle(k < m.index ? Color.white : (k == m.index ? Flat.onAcc : Flat.text2))
                            .background(Circle().fill(k < m.index ? Flat.ok : (k == m.index ? Flat.acc : Flat.ctl)))
                        Text(L.t(Self.titles[st])).lineLimit(1)
                        Spacer(minLength: 0)
                    }.padding(.horizontal, 10).padding(.vertical, 8)
                    .background(k == m.index ? Flat.ctl : .clear, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
                    .foregroundStyle(k == m.index ? Flat.text : Flat.text2).fontWeight(k == m.index ? .semibold : .regular)
                }
                Spacer()
            }.padding(.horizontal, 12).padding(.top, 18).padding(.bottom, 18).frame(width: 230)
            .overlay(alignment: .trailing) { Rectangle().fill(Flat.line).frame(width: 1) }

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) { page }.padding(.horizontal, 30).padding(.top, 24).padding(.bottom, 20)
                        .frame(maxWidth: 860, alignment: .leading).frame(maxWidth: .infinity, alignment: .center)
                }
                HStack(spacing: 10) {
                    Button(L.t("su.later")) { m.open = false }.buttonStyle(.plain).foregroundStyle(Flat.text2)
                    Spacer()
                    if let skip = skipTitle { Button(skip) { m.next() }.buttonStyle(.plain).foregroundStyle(Flat.text2) }
                    Text("\(m.index + 1) / \(m.steps.count)").font(.system(size: 12)).foregroundStyle(Flat.text2)
                    if m.index > 0 { Button("← " + L.t("su.back")) { m.back() }.buttonStyle(FlatButton()) }
                    Button(nextTitle + " →") { m.step == 6 ? m.finish(library: true) : m.next() }.buttonStyle(FlatButton(primary: true)).disabled(!canNext)
                }.padding(.horizontal, 26).padding(.vertical, 12).overlay(alignment: .top) { Rectangle().fill(Flat.line).frame(height: 1) }
            }
        }
    }

    var nextTitle: String {
        switch m.step { case 3 where m.voiceMode == "mac": return L.t("su.listen"); case 6: return L.t("su.lib.go")
        default: return m.index == m.steps.count - 1 ? L.t("su.finish") : L.t("su.next") }
    }
    var skipTitle: String? { m.step == 2 && m.imported == nil ? L.t("su.dlg.skip") : (m.step == 5 ? L.t("su.skip") : nil) }
    var canNext: Bool {
        switch m.step { case 3: return m.voiceMode != "mac" || !m.compare.isEmpty; case 4: return !m.running && m.chosen != nil && !m.results.isEmpty; default: return true }
    }

    @ViewBuilder var page: some View {
        switch m.step {
        case 0: project
        case 1: prep
        case 2: dialogues
        case 3: voice
        case 4: listen
        case 5: creatures
        default: library
        }
    }

    func question(_ t: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t).font(.system(size: 24, weight: .bold))
            Text(l).font(.system(size: 14)).foregroundStyle(Flat.text2).fixedSize(horizontal: false, vertical: true)
        }
    }
    func choice(_ on: Bool, _ icon: String, _ title: String, _ detail: String, enabled: Bool = true, action: @escaping () -> Void, @ViewBuilder extra: () -> some View = { EmptyView() }) -> some View {
        // La carte n'est pas un bouton : seul son en-tête l'est, pour que les boutons du contenu restent cliquables à part.
        VStack(alignment: .leading, spacing: 0) {
            Button(action: action) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 18)).foregroundStyle(on ? Flat.acc : Flat.text2)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) { Image(systemName: icon).frame(width: 20); Text(title).font(.system(size: 15, weight: .semibold)) }
                        Text(detail).font(.system(size: 12.5)).foregroundStyle(Flat.text2).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(!enabled)
            extra().padding(.leading, 32)
        }.padding(16)
        .tile(pad: EdgeInsets(), selected: on).opacity(enabled ? 1 : 0.55)
    }

    // 1
    var project: some View {
        VStack(alignment: .leading, spacing: 16) {
            question(L.t("su.p.q"), L.t("su.p.l"))
            Card(pad: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    field(L.t("su.p.name")) { TextField(L.t("proj.name"), text: $m.name).flatField().font(.system(size: 14)) }
                    field(L.t("su.p.folder")) {
                        HStack {
                            Text(m.folder.map { URL(fileURLWithPath: $0).lastPathComponent } ?? L.t("su.p.nofolder")).foregroundStyle(m.folder == nil ? Flat.text2 : Flat.text)
                                .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 11).padding(.vertical, 7)
                                .background(Flat.ctl, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous)).help(m.folder ?? "")
                            Button(L.t("su.p.choose")) {
                                let o = NSOpenPanel(); o.canChooseDirectories = true; o.canChooseFiles = false; o.canCreateDirectories = true
                                if o.runModal() == .OK { m.folder = o.url?.path }
                            }.buttonStyle(FlatButton(small: true))
                        }
                    }
                    field(L.t("su.p.lang")) { LangPairPicker(main: $m.lang, second: $m.lang2) }
                }
            }.frame(maxWidth: .infinity)
            HStack(spacing: 18) {
                Button(L.t("su.p.open")) { m.open = false; s.screen = .projects }.buttonStyle(.plain).foregroundStyle(Flat.text2)
            }
        }
    }
    func field(_ t: String, @ViewBuilder _ c: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(t).font(.system(size: 11.5)).foregroundStyle(Flat.text2); c() }
    }

    // 2
    var prep: some View {
        VStack(alignment: .leading, spacing: 16) {
            question(L.t("su.a.q"), L.t("su.a.l"))
            VStack(spacing: 10) {
                choice(m.assistant == "cloud", "bubble.left.and.bubble.right", L.t("su.a.cloud"), L.t("su.a.cloud.d"), action: { m.assistant = "cloud" }) {
                    VStack(alignment: .leading, spacing: 8) {
                        if m.agents.isEmpty { Text(L.t("su.a.noagent")).font(.system(size: 11.5)).foregroundStyle(Flat.text2) }
                        Flow(spacing: 6) { ForEach(m.agents) { a in Tag(title: a.name + (a.installed ? " ✓" : ""), color: a.installed ? Flat.ok : nil) } }
                        if m.assistant == "cloud" {
                            HStack(spacing: 8) {
                                if m.agents.contains(where: { !$0.installed }) {
                                    Button(L.t("su.a.install")) { m.confirmInstall = true }.buttonStyle(FlatButton(small: true, green: true))
                                } else if !m.agents.isEmpty { Tag(title: L.t("su.a.ready"), color: Flat.ok) }
                                Button(L.t("su.a.copy")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(ProjectImport.guide, forType: .string); s.info = L.t("su.a.copied") }
                                    .buttonStyle(FlatButton(small: true))
                            }
                        }
                    }.padding(.top, 8)
                }
                choice(m.assistant == "local", "lock.shield", L.t("su.a.local"), m.llm.map { L.t("su.a.local.ok", $0.name, m.llmModel) } ?? L.t("su.a.local.no"), action: { m.assistant = "local" })
                choice(m.assistant == "none", "pencil", L.t("su.a.none"), L.t("su.a.none.d"), action: { m.assistant = "none" })
            }.frame(maxWidth: .infinity)
        }
        .alert(L.t("su.a.confirm.q"), isPresented: $m.confirmInstall) {
            Button(L.t("btn.cancel"), role: .cancel) {}
            Button(L.t("su.a.install")) { m.installAgents() }
        } message: { Text(L.t("su.a.confirm.msg", m.agents.filter { !$0.installed }.map(\.name).joined(separator: ", "))) }
    }

    // 3
    var dialogues: some View {
        VStack(alignment: .leading, spacing: 16) {
            question(L.t("su.d.q"), L.t("su.d.l"))
            VStack(spacing: 6) {
                Image(systemName: "arrow.down.doc").font(.system(size: 26)).foregroundStyle(Flat.text2)
                Text(L.t("su.d.drop")).font(.system(size: 14, weight: .semibold))
                Text(L.t("su.d.formats")).foregroundStyle(Flat.text2)
                Button(L.t("su.d.choose")) {
                    let o = NSOpenPanel(); o.allowedContentTypes = [.json, .commaSeparatedText, .tabSeparatedText, .plainText]
                    if o.runModal() == .OK, let u = o.url { m.importDialogues(u) }
                }.buttonStyle(FlatButton(small: true)).padding(.top, 6)
            }.frame(maxWidth: .infinity).padding(28)
            .overlay(RoundedRectangle(cornerRadius: Flat.rb, style: .continuous).strokeBorder(Flat.ctl, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
            .onDrop(of: [.fileURL], isTargeted: nil) { items in
                items.first?.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { d, _ in
                    if let d = d as? Data, let u = URL(dataRepresentation: d, relativeTo: nil) { Task { @MainActor in SetupModel.shared.importDialogues(u) } }
                }
                return true
            }
            if let f = m.imported {
                Card(pad: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Text("✓ " + f).font(.system(size: 14, weight: .semibold)); Spacer(); Text(m.importInfo).foregroundStyle(Flat.text2) }
                        if m.llm != nil, m.assistant == "local" {
                            HStack(spacing: 8) {
                                if m.analyzing { ProgressView().controlSize(.small); Text(m.analyzeStatus).font(.system(size: 11.5)).foregroundStyle(Flat.text2) }
                                else if m.analyzed { Tag(title: L.t("su.d.analyzed"), color: Flat.ok); Button(L.t("su.e.again")) { m.analyze() }.buttonStyle(FlatButton(small: true)) }
                                else { Button(L.t("su.d.analyze", m.llm!.name)) { m.analyze() }.buttonStyle(FlatButton(small: true, green: true)) }
                            }
                        }
                        Flow(spacing: 6) {
                            ForEach((m.project?.characters ?? []).prefix(8)) { c in Tag(title: c.name + (c.kind == "creature" ? " · " + L.t("su.k.creature") : c.kind == "animal" ? " · " + L.t("su.k.animal") : ""), color: c.kind != nil && c.kind != "human" ? Flat.warn : nil) }
                            if (m.project?.characters.count ?? 0) > 8 { Tag(title: L.t("su.d.more", (m.project?.characters.count ?? 0) - 8)) }
                        }
                    }
                }.frame(maxWidth: .infinity).overlay(RoundedRectangle(cornerRadius: Flat.rb, style: .continuous).strokeBorder(Flat.ok, lineWidth: 2))
            }
        }
    }

    // 4
    var voice: some View {
        VStack(alignment: .leading, spacing: 16) {
            question(L.t("su.v.q"), L.t("su.v.l", m.hw.chip, Int(m.hw.memoryGB.rounded())))
            VStack(spacing: 10) {
                choice(m.voiceMode == "mac", "laptopcomputer", L.t("su.v.mac"), L.t("su.v.mac.d"), action: { m.voiceMode = "mac" }) {
                    if m.voiceMode == "mac" {
                    VStack(spacing: 6) {
                        ForEach(m.models) { md in
                            Button { if m.compare.contains(md.id) { m.compare.remove(md.id) } else { m.compare.insert(md.id) } } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: m.compare.contains(md.id) ? "checkmark.square.fill" : "square").foregroundStyle(m.compare.contains(md.id) ? Flat.acc : Flat.text2)
                                    Text(L.t(md.nameKey)).fontWeight(.semibold)
                                    Text("· " + L.t(md.nameKey + ".d")).foregroundStyle(Flat.text2).lineLimit(1)
                                    Spacer(minLength: 6)
                                    if m.hw.fit(ramGB: md.ramGB) == .possible { Tag(title: L.t("su.v.heavy"), color: Flat.warn) }
                                    if md.id == m.recommended { Tag(title: L.t("su.v.reco"), solid: true) }
                                }.padding(.horizontal, 12).padding(.vertical, 9).contentShape(Rectangle()).tile(pad: EdgeInsets())
                            }.buttonStyle(.plain)
                        }
                        Text(L.t("su.v.hint")).font(.system(size: 11.5)).foregroundStyle(Flat.text2).frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(.top, 10)
                    }
                }
                choice(m.voiceMode == "server", "desktopcomputer", L.t("su.v.server"), L.t("su.v.server.d"), action: { m.voiceMode = "server" }) {
                    if m.voiceMode == "server" {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                TextField("http://pc-studio.local:8000", text: $m.serverURL).flatField()
                                SecureField(L.t("su.v.key.opt"), text: $m.serverKey).flatField().frame(width: 180)
                                Button(L.t("su.v.test")) { m.testServer() }.buttonStyle(FlatButton(small: true)).disabled(m.serverURL.isEmpty || m.remoteBusy)
                            }
                            if !m.serverStatus.isEmpty { Text(m.serverStatus).font(.system(size: 11.5)).foregroundStyle(m.serverModels.isEmpty ? Flat.warn : Flat.ok) }
                            if !m.serverModels.isEmpty {
                                if VoiceServer.designModel(in: m.serverModels) != nil {
                                    Button { m.serverLibrary.toggle(); m.saveVoiceMode() } label: { HStack(spacing: 8) { Image(systemName: m.serverLibrary ? "checkmark.square.fill" : "square").foregroundStyle(m.serverLibrary ? Flat.acc : Flat.text2); Text(L.t("su.v.srvlib")) } }.buttonStyle(.plain)
                                }
                                HStack(spacing: 8) {
                                    Picker("", selection: $m.serverModel) { ForEach(m.serverModels, id: \.self) { Text($0).tag($0) } }.labelsHidden().frame(maxWidth: 320)
                                    Button(L.t("su.v.importsrv")) { m.importServerVoices() }.buttonStyle(FlatButton(small: true)).disabled(s.busy || m.serverModel.isEmpty)
                                }
                                Text(L.t("su.v.srvnote")).font(.system(size: 11)).foregroundStyle(Flat.text2).fixedSize(horizontal: false, vertical: true)
                            }
                        }.padding(.top, 10)
                    }
                }
                choice(m.voiceMode == "cloud", "cloud", L.t("su.v.cloud"), L.t("su.v.cloud.d"), action: { m.voiceMode = "cloud" }) {
                    if m.voiceMode == "cloud" {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("ElevenLabs").fontWeight(.semibold)
                                SecureField(ElevenLabs.key == nil ? L.t("su.v.el.key") : L.t("su.v.el.keyok"), text: $m.elKey).flatField()
                                Button(L.t("su.v.check")) { m.checkElevenLabs() }.buttonStyle(FlatButton(small: true)).disabled((m.elKey.isEmpty && ElevenLabs.key == nil) || m.remoteBusy)
                            }
                            if !m.elStatus.isEmpty { Text(m.elStatus).font(.system(size: 11.5)).foregroundStyle(Flat.text2) }
                            HStack(spacing: 8) {
                                Button(L.t("su.v.el.import")) { m.importElevenLabs() }.buttonStyle(FlatButton(small: true, green: true)).disabled(ElevenLabs.key == nil || s.busy)
                                Text(L.t("su.v.el.free")).font(.system(size: 11)).foregroundStyle(Flat.text2)
                            }
                            Text(L.t("su.v.el.note")).font(.system(size: 11)).foregroundStyle(Flat.text2).fixedSize(horizontal: false, vertical: true)
                        }.padding(.top, 10)
                    }
                }
            }.frame(maxWidth: .infinity)
        }
    }

    // 5
    var listen: some View {
        VStack(alignment: .leading, spacing: 16) {
            question(L.t("su.e.q"), L.t("su.e.l"))
            let ids = TTSModel.acting.map(\.id).filter { m.compare.contains($0) }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(ids, id: \.self) { id in
                    let md = TTSModel.find(id)!, sel = m.chosen == id
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text(L.t(md.nameKey)).font(.system(size: 15, weight: .semibold)); Spacer()
                            if let t = m.times[id] { Text(L.t("su.e.time", t)).font(.system(size: 11.5)).foregroundStyle(Flat.text2) } }
                        ForEach(Array(m.lines.enumerated()), id: \.offset) { j, l in
                            let u = (m.results[id] ?? []).indices.contains(j) ? m.results[id]![j] : nil
                            HStack(spacing: 8) {
                                PlayButton(playing: u != nil && s.playingPath == u!.path, enabled: u != nil) { if let u { s.play(rel: u.path) } }
                                VStack(alignment: .leading, spacing: 2) { Text("« \(l) »").font(.system(size: 11.5)).foregroundStyle(Flat.text2).lineLimit(1); Wave(seed: Double(j) + Double(id.count), bars: 30, playing: u != nil && s.playingPath == u!.path) }
                            }
                        }
                        Button { m.chosen = id } label: { Text((sel ? "✓ " : "") + L.t("su.e.keep")).frame(maxWidth: .infinity) }
                            .buttonStyle(FlatButton(primary: sel)).disabled(m.results[id]?.count != m.lines.count)
                    }.padding(16).tile(pad: EdgeInsets(), selected: sel)
                }
            }.frame(maxWidth: .infinity).onAppear { if m.lines.isEmpty { m.prepareLines() } }
            HStack(spacing: 10) {
                if m.running {
                    ProgressView().controlSize(.small)
                    Text(m.status).foregroundStyle(Flat.text2)
                } else if m.results.isEmpty {
                    Button(L.t("su.e.start")) { m.runComparison() }.buttonStyle(FlatButton(green: true)).disabled(s.busy)
                    let gb = ids.compactMap { TTSModel.find($0) }.filter { !$0.installed }.reduce(0) { $0 + $1.sizeGB }
                    if gb > 0 { Text(L.t("su.e.size", gb)).foregroundStyle(Flat.text2) }
                } else { Tag(title: L.t("su.e.ready"), color: Flat.ok); Button(L.t("su.e.again")) { m.runComparison() }.buttonStyle(FlatButton(small: true)) }
            }
        }
    }

    // 6
    var creatures: some View {
        VStack(alignment: .leading, spacing: 14) {
            question(L.t("su.c.q"), L.t("su.c.l", m.creatures.count))
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "waveform.badge.plus").font(.system(size: 18)).foregroundStyle(Flat.brand).frame(width: 22)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) { Text(L.t("su.c.sfx")).font(.system(size: 14, weight: .semibold)); Tag(title: L.t("su.c.sfx.model")) }
                    Text(L.t("su.c.sfx.d")).font(.system(size: 12)).foregroundStyle(Flat.text2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if m.sfxRunning { HStack(spacing: 6) { ProgressView().controlSize(.small); Text(m.sfxStatus).font(.system(size: 11.5)).foregroundStyle(Flat.text2).lineLimit(1) }.frame(maxWidth: 260, alignment: .trailing) }
                else { Button(L.t(m.creatures.contains { $0.sfx != nil } ? "su.c.sfx.again" : "su.c.sfx.go") + (m.sfxModel.installed ? "" : " · " + L.t("su.c.size", m.sfxModel.sizeGB))) { m.generateSFX() }
                        .buttonStyle(FlatButton(green: true)).disabled(s.busy) }
            }.padding(14).tile(pad: EdgeInsets(), outline: Flat.brand.opacity(0.5)).frame(maxWidth: .infinity)
            VStack(spacing: 8) {
                HStack { Text(L.t("su.c.col.char")).frame(width: 190, alignment: .leading); Text(L.t("su.c.col.voice")).frame(maxWidth: .infinity, alignment: .leading); Text(L.t("su.c.col.sfx")).frame(width: 110, alignment: .leading) }
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(Flat.text2).padding(.horizontal, 12)
                ForEach(m.creatures) { c in creatureRow(c) }
            }.frame(maxWidth: .infinity)
            Text(L.t("su.c.hint")).font(.system(size: 11.5)).foregroundStyle(Flat.text2)
        }
    }
    func creatureRow(_ c: Character) -> some View {
        let sug = Creatures.suggestions(for: c, in: s.voices), lg = m.lang.rawValue
        return HStack(spacing: 12) {
            HStack(spacing: 10) {
                Avatar(letter: Self.initial(c.name))
                VStack(alignment: .leading, spacing: 1) { Text(c.name).fontWeight(.semibold).rowName(c.name); Text(c.role).font(.system(size: 11)).foregroundStyle(Flat.text2).rowName(c.role) }
            }.frame(width: 190, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(sug) { v in
                    let on = c.voiceID == v.id, rel = v.samples[lg] ?? v.samples.values.first
                    HStack(spacing: 6) {
                        PlayButton(playing: rel != nil && s.playingPath == Paths.audio.appendingPathComponent(rel!).path, enabled: rel != nil) { s.play(rel: rel) }
                        Button { m.assign(v.id, to: c) } label: { Text((on ? "✓ " : "") + v.name).font(.system(size: 12, weight: on ? .semibold : .regular)).lineLimit(1) }.buttonStyle(.plain)
                    }.padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 4)
                    .background(Capsule().fill(on ? Flat.acc.opacity(0.22) : Flat.ctl)).overlay(Capsule().strokeBorder(on ? Flat.acc : .clear, lineWidth: 1.5))
                }
                if sug.isEmpty { Text(L.t("su.c.nolib")).font(.system(size: 11.5)).foregroundStyle(Flat.text2) }
            }
            if let vid = c.voiceID, let v = s.voices.first(where: { $0.id == vid }), let rel = v.samples[lg] ?? v.samples.values.first {
                HStack(spacing: 6) {
                    Text(L.t("su.c.fx")).font(.system(size: 11)).foregroundStyle(Flat.text2)
                    Button { m.setFX(nil, for: c); s.play(rel: rel) } label: { Chip(title: L.t("fx.none"), on: c.fx == nil) }.buttonStyle(.plain)
                    ForEach(CreatureFX.presets(for: c), id: \.id) { fx in
                        Button { m.setFX(fx.id, for: c); s.playWithFX(fx, sample: rel) } label: { Chip(title: "▶ " + L.t(fx.key), on: c.fx == fx.id) }.buttonStyle(.plain)
                    }
                }
            }
            }.frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                if let f = c.sfx {
                    PlayButton(playing: s.playingPath == Paths.audio.appendingPathComponent(f).path) { s.play(rel: f) }
                    Button { m.generateSFX(only: c) } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).foregroundStyle(Flat.text2).help(L.t("su.c.redo")).disabled(m.sfxRunning || s.busy)
                } else { Text("—").foregroundStyle(Flat.text2) }
            }.frame(width: 110, alignment: .leading)
        }.tile(pad: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }
    /// Initiale du nom sans l'article (« Le Dragon » → D).
    static func initial(_ n: String) -> String {
        var t = n.trimmingCharacters(in: .whitespaces)
        for a in ["le ", "la ", "les ", "l'", "l’", "the ", "el ", "il ", "lo ", "los ", "las "] where t.lowercased().hasPrefix(a) { t = String(t.dropFirst(a.count)); break }
        return String(t.prefix(1)).uppercased()
    }

    // 7
    var library: some View {
        let left = s.remainingSamples, secs = Double(left) * s.avg
        return VStack(alignment: .leading, spacing: 16) {
            question(L.t("su.l.q"), L.t("su.l.l"))
            Card(pad: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 30) {
                        stat("\(s.libVoices.count)", L.t("su.l.voices"))
                        stat(left == 0 ? "✓" : Self.duration(secs), left == 0 ? L.t("su.l.done") : L.t("su.l.time"))
                        stat(L.t("su.l.mb", max(1, Int(Double(s.totalSamples) * 0.032))), L.t("su.l.disk"))
                    }
                    Text(L.t("su.l.note")).font(.system(size: 12.5)).foregroundStyle(Flat.text2).fixedSize(horizontal: false, vertical: true)
                }
            }.frame(maxWidth: .infinity)
        }
    }
    func stat(_ v: String, _ l: String) -> some View { VStack(alignment: .leading, spacing: 2) { Text(v).font(.system(size: 24, weight: .bold)); Text(l).font(.system(size: 11.5)).foregroundStyle(Flat.text2) } }
    static func duration(_ s: Double) -> String { let h = Int(s / 3600), mn = Int(s.truncatingRemainder(dividingBy: 3600) / 60); return h > 0 ? "≈ \(h) h \(String(format: "%02d", mn))" : "≈ \(max(mn, 1)) min" }
}
