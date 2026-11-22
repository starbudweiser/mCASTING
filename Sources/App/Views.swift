// mCASTING — écrans, à l'identique de la maquette Flat Mat validée (maquettes/maquettes-flatmat.html).
import SwiftUI
import UniformTypeIdentifiers

// MARK: Fenêtre
struct ContentView: View {
    @ObservedObject var s = AppState.shared
    @ObservedObject var setup = SetupModel.shared
    var body: some View {
        Group { if setup.open { SetupWizard() } else { main } }
        .ignoresSafeArea(.container, edges: .top)
        .background(Flat.bg).foregroundStyle(Flat.text).font(.system(size: 13)).tint(Flat.acc)
        .alert(L.t("err.title"), isPresented: Binding(get: { s.error != nil }, set: { if !$0 { s.error = nil } })) { Button("OK") { s.error = nil } } message: { Text(s.error ?? "") }
        .alert(L.t("info.title"), isPresented: Binding(get: { s.info != nil }, set: { if !$0 { s.info = nil } })) { Button("OK") { s.info = nil } } message: { Text(s.info ?? "") }
        .alert(L.t("el.confirm.q"), isPresented: Binding(get: { s.pendingPaid != nil }, set: { if !$0 { s.pendingPaid = nil } })) {
            Button(L.t("btn.cancel"), role: .cancel) { s.pendingPaid = nil }
            Button(L.t("el.confirm.go", ElevenLabs.cost(s.pendingPaid?.text ?? ""))) { s.confirmPaid() }
        } message: { Text(L.t("el.confirm.msg", (s.pendingPaid?.text ?? "").count, ElevenLabs.cost(s.pendingPaid?.text ?? ""))) }
    }
    var main: some View {
        VStack(spacing: 0) {
            TopBar()
            HStack(spacing: 0) {
                NavPanel().frame(width: 212)
                Group {
                    switch s.screen {
                    case .projects: ProjectsView()
                    case .casting: CastingView()
                    case .library: LibraryView()
                    case .generation: GenerationView()
                    case .clone: CloneView()
                    case .models: ModelsView()
                    case .settings: SettingsView()
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(alignment: .bottomTrailing) { Watermark() }.clipped()
            }
        }
    }
}

/// Micro de l'icône (sans le carré de fond), tracé dans le repère 1024 px de l'icône.
struct MicShape: Shape {
    func path(in r: CGRect) -> Path {
        // Boîte du dessin dans le repère de l'icône : x 319…705, y 202…665 (haut = 0).
        let box = CGRect(x: 319, y: 202, width: 386, height: 463)
        let k = min(r.width / box.width, r.height / box.height)
        let ox = r.midX - box.width * k / 2, oy = r.midY - box.height * k / 2
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + (x - box.minX) * k, y: oy + (y - box.minY) * k) }
        var p = Path()
        p.addRoundedRect(in: CGRect(x: ox + (407 - box.minX) * k, y: oy + (202 - box.minY) * k, width: 210 * k, height: 330 * k), cornerSize: CGSize(width: 105 * k, height: 105 * k))
        var arc = Path()
        arc.addArc(center: pt(512, 442), radius: 175 * k, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        arc.move(to: pt(512, 577)); arc.addLine(to: pt(512, 647))
        arc.move(to: pt(422, 647)); arc.addLine(to: pt(602, 647))
        p.addPath(arc.strokedPath(StrokeStyle(lineWidth: 36 * k, lineCap: .round)))
        return p
    }
}

/// Micro de l'icône en filigrane très léger au fond de l'interface (derrière les cartes, sans gêner la lecture).
struct Watermark: View {
    @Environment(\.colorScheme) var scheme
    var body: some View {
        MicShape().fill(Flat.brand).frame(width: 420, height: 490)
            .opacity(scheme == .dark ? 0.025 : 0.03)
            .padding(.trailing, 48).padding(.bottom, 52).allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// `.bar` : une seule ligne sur l'axe des boutons de fenêtre (52 px), nom après les trois boutons (104 px), filet dessous.
struct TopBar: View {
    @ObservedObject var s = AppState.shared
    var body: some View {
        HStack(spacing: 10) {
            BrandName().padding(.leading, 104)
            Spacer()
            HStack(spacing: 8) { Dot(color: Flat.ok); Text(L.t("bar.mcp")) }.font(.system(size: 12)).foregroundStyle(Flat.text2).lineLimit(1).fixedSize()
            Text("Qwen3-TTS · " + (s.engineInstalled ? L.t("mod.installed") : L.t("mod.notinstalled"))).font(.system(size: 12)).foregroundStyle(Flat.text2).lineLimit(1).fixedSize()
            Button { s.screen = .settings } label: { HStack(spacing: 5) { Image(systemName: "gearshape"); Text(L.t("nav.settings")) } }.buttonStyle(FlatButton(small: true))
        }.frame(height: 52).padding(.trailing, 18)
        .overlay(alignment: .bottom) { Rectangle().fill(Flat.line).frame(height: 1) }
    }
}

struct Dot: View {
    let color: Color
    var body: some View { Circle().fill(color).frame(width: 8, height: 8).overlay(Circle().stroke(color.opacity(0.25), lineWidth: 3)) }
}

/// `.nav` : 190 px, filet à droite, entrées 8 × 11 de rayon 8.
struct NavPanel: View {
    @ObservedObject var s = AppState.shared
    static let items: [(Screen, String, String)] = [(.projects, "rectangle.stack", "nav.projects"), (.casting, "person.wave.2", "nav.casting"), (.library, "music.note.list", "nav.library"), (.clone, "waveform.badge.plus", "nav.clone"), (.models, "arrow.down.circle", "nav.models")]
    var active: Screen { s.screen == .generation ? .library : s.screen }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Header(title: L.t("nav.title")).padding(.horizontal, 11).padding(.top, 10).padding(.bottom, 2)
            ForEach(Self.items, id: \.0) { it in
                Button { s.screen = it.0 } label: {
                    HStack(spacing: 9) { Image(systemName: it.1).frame(width: 16); Text(L.t(it.2)).lineLimit(1); Spacer(minLength: 0) }
                        .padding(.horizontal, 11).padding(.vertical, 8).contentShape(Rectangle())
                        .background(active == it.0 ? Flat.ctl : .clear, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
                        .foregroundStyle(active == it.0 ? Flat.text : Flat.text2).fontWeight(active == it.0 ? .semibold : .regular)
                }.buttonStyle(.plain)
            }
            SidebarLangs()
            Spacer()
            ComputeStatus()
        }.padding(.horizontal, 10).padding(.vertical, 12)
        .overlay(alignment: .trailing) { Rectangle().fill(Flat.line).frame(width: 1) }
    }
}

/// État du calcul, en bas de la navigation : texte centré sur une barre de progression en arrière-plan (indéterminée si le calcul n'a pas de pourcentage).
struct ComputeStatus: View {
    @ObservedObject var s = AppState.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    var fraction: Double? { s.busy && s.task == "library" && s.totalSamples > 0 ? Double(s.doneSamples) / Double(s.totalSamples) : nil }
    var label: String {
        guard s.busy else { return L.t("compute.free") }
        if let f = fraction { return L.t("compute.busy") + " · " + "\(Int((f * 100).rounded())) %" }
        return L.t("compute.busy")
    }
    var body: some View {
        GeometryReader { g in
            ZStack {
                RoundedRectangle(cornerRadius: Flat.rc, style: .continuous).fill(Flat.ctl)
                if s.busy {
                    RoundedRectangle(cornerRadius: Flat.rc, style: .continuous).fill(Flat.warn.opacity(fraction == nil ? (pulse ? 0.45 : 0.2) : 0.42))
                        .frame(width: fraction.map { max(g.size.width * $0, 8) } ?? g.size.width).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 7) {
                    if !s.busy { Dot(color: Flat.ok) }
                    Text(label).font(.system(size: 12, weight: s.busy ? .medium : .regular)).foregroundStyle(s.busy ? Flat.text : Flat.text2).lineLimit(1).minimumScaleFactor(0.85)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
        }
        .frame(height: 34)
        .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true } } }
        .animation(.easeOut(duration: 0.3), value: fraction)
    }
}

/// Zone principale : marges 14, 10 entre blocs.
struct Page<C: View>: View {
    @ViewBuilder var content: C
    var body: some View { VStack(alignment: .leading, spacing: 10) { content }.padding(14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) }
}
struct Title: View {
    let text: String
    var body: some View { Text(text).font(.system(size: 16, weight: .semibold)).lineLimit(1).rowName(text) }
}

// MARK: Casting
struct CastingView: View {
    @ObservedObject var s = AppState.shared
    @State private var adding = false
    @State private var newName = ""
    var body: some View {
        Page {
            if let p = s.project {
                HStack(spacing: 8) {
                    Title(text: p.name)
                    Tag(title: L.t("cast.n", p.characters.count)); Tag(title: L.t("cast.done", p.castCount), color: Flat.ok)
                    if p.characters.count > p.castCount { Tag(title: L.t("cast.left", p.characters.count - p.castCount), color: Flat.warn) }
                    Spacer(minLength: 8)
                    Button { pickFolder(p) } label: { HStack(spacing: 6) { Image(systemName: "folder"); Text(L.t("proj.folder.short")) } }.buttonStyle(FlatButton()).help(p.folder ?? L.t("proj.folder"))
                    Button(L.t("cast.import")) { importFile() }.buttonStyle(FlatButton())
                    Button(L.t("proj.write")) { s.writeCasting() }.buttonStyle(FlatButton(primary: true)).disabled(p.folder == nil).help(p.folder == nil ? L.t("proj.nofolder") : "")
                }
                HStack(alignment: .top, spacing: 12) {
                    CharacterColumn(adding: $adding).frame(width: 280)
                    CastingRight()
                }
            } else {
                EmptyProject()
            }
        }
        .sheet(isPresented: $adding) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L.t("char.add")).font(.system(size: 15, weight: .semibold))
                TextField(L.t("char.name"), text: $newName).flatField()
                HStack { Spacer(); Button(L.t("btn.cancel")) { adding = false }.buttonStyle(FlatButton())
                    Button(L.t("btn.add")) { if !newName.isEmpty { s.addCharacter(name: newName) }; newName = ""; adding = false }.buttonStyle(FlatButton(primary: true)) }
            }.padding(20).frame(width: 340).background(Flat.bg).foregroundStyle(Flat.text).tint(Flat.acc)
        }
    }
    func pickFolder(_ p: Project) {
        let o = NSOpenPanel(); o.canChooseDirectories = true; o.canChooseFiles = false; o.canCreateDirectories = true
        if o.runModal() == .OK, let u = o.url { s.mutate { all in if let i = all.firstIndex(where: { $0.id == p.id }) { all[i].folder = u.path } } }
    }
    func importFile() { let o = NSOpenPanel(); o.allowedContentTypes = [.json]; if o.runModal() == .OK, let u = o.url { s.importProject(from: u, intoCurrent: true) } }
}

struct EmptyProject: View {
    @ObservedObject var s = AppState.shared
    var body: some View {
        VStack(spacing: 10) { Text(L.t("proj.empty")).foregroundStyle(Flat.text2); Button("＋ " + L.t("proj.new")) { s.screen = .projects }.buttonStyle(FlatButton(green: true)) }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Colonne gauche : la liste des personnages, sur toute la hauteur, rien d'autre.
struct CharacterColumn: View {
    @Binding var adding: Bool
    @ObservedObject var s = AppState.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Header(title: L.t("char.title"))
            if !s.multi.isEmpty {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Tag(title: L.t("rand.sel", s.multi.count))
                        Spacer(minLength: 0)
                        Button(L.t("rand.cancel")) { s.multi = [] }.buttonStyle(FlatButton(small: true))
                    }
                    Button(s.multi.count > 1 ? L.t("rand.many", s.multi.count) : L.t("rand.one")) { s.assignRandom(ordered(s.multi)) }.buttonStyle(FlatButton(green: true, wide: true))
                }
            }
            ScrollView(showsIndicators: false) { VStack(spacing: 8) { ForEach(s.project?.characters ?? []) { c in row(c) } } }
            Button("＋ " + L.t("char.add")) { adding = true }.buttonStyle(FlatButton(green: true, wide: true))
        }
    }
    var chars: [Character] { s.project?.characters ?? [] }
    func ordered(_ set: Set<String>) -> [String] { chars.map(\.id).filter { set.contains($0) } }
    /// Clic : sélection simple ; ⌘-clic : ajoute ou retire ; ⇧-clic : étend depuis le personnage actif.
    func click(_ c: Character) {
        let f = NSApp.currentEvent?.modifierFlags ?? []
        if f.contains(.command) {
            if s.multi.isEmpty, let a = s.characterID { s.multi = [a] }
            if s.multi.contains(c.id) { s.multi.remove(c.id) } else { s.multi.insert(c.id) }
        } else if f.contains(.shift), let a = s.characterID, let i = chars.firstIndex(where: { $0.id == a }), let j = chars.firstIndex(where: { $0.id == c.id }) {
            s.multi = Set(chars[min(i, j)...max(i, j)].map(\.id))
        } else { s.multi = []; s.characterID = c.id }
    }
    @ViewBuilder func menu(_ c: Character) -> some View {
        let t = s.multi.contains(c.id) ? ordered(s.multi) : [c.id]
        Button(t.count > 1 ? L.t("rand.many", t.count) : L.t("rand.one")) { s.assignRandom(t) }
        Button(t.count > 1 ? L.t("rand.clear.many", t.count) : L.t("rand.clear")) { s.clearVoice(t) }
        Divider()
        Button(L.t("rand.nov")) { s.multi = Set(chars.filter { $0.voiceID == nil }.map(\.id)) }
        Button(L.t("rand.all")) { s.multi = Set(chars.map(\.id)) }
        if !s.multi.isEmpty { Button(L.t("rand.none")) { s.multi = [] } }
    }
    func row(_ c: Character) -> some View {
        let v = s.voices.first { $0.id == c.voiceID }
        return Group {
            HStack(spacing: 10) {
                Avatar(letter: String(c.name.prefix(1)))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) { Text(c.name).fontWeight(.semibold).rowName(c.name); if let v { Tag(title: v.name, color: Flat.ok).contentShape(Rectangle()).onTapGesture { s.showVoice(of: c) }.help(L.t("char.showvoice")) } else { Tag(title: L.t("char.novoice")) } }
                    Text(c.role).font(.system(size: 11.5)).foregroundStyle(Flat.text2).rowName(c.role)
                }
                Spacer(minLength: 0)
            }.tile(selected: s.characterID == c.id || s.multi.contains(c.id))
        }.contentShape(Rectangle()).onTapGesture { click(c) }.contextMenu { menu(c) }.accessibilityAddTraits(.isButton)
    }
}

enum TrialBox { static let emotions = [("emo.neutral", ""), ("emo.tired", "tired, low energy"), ("emo.joy", "joyful, bright"), ("emo.anger", "angry, sharp")] }

/// Commutateur à deux états (capsule).
struct Seg: View {
    let items: [String]; @Binding var selection: Int
    var body: some View {
        HStack(spacing: 2) {
            ForEach(items.indices, id: \.self) { i in
                Button { selection = i } label: {
                    Text(items[i]).font(.system(size: 12.5, weight: .medium)).lineLimit(1).fixedSize().padding(.horizontal, 14).padding(.vertical, 5)
                        .foregroundStyle(selection == i ? Flat.onAcc : Flat.text).background(Capsule().fill(selection == i ? Flat.acc : .clear))
                }.buttonStyle(.plain)
            }
        }.padding(3).background(Capsule().fill(Flat.ctl))
    }
}

/// Partie droite de l'écran Casting : un commutateur « Choisir une voix » / « Fiche du personnage ».
struct CastingRight: View {
    @ObservedObject var s = AppState.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Seg(items: [L.t("char.tab.voices"), L.t("char.tab.sheet")], selection: $s.castTab)
            if let c = s.character {
                if s.castTab == 0 {
                    HStack(alignment: .top, spacing: 10) {
                        CharacterStrip(c: c).frame(maxWidth: .infinity, alignment: .topLeading)
                        FilterBox(search: true, stretch: true).frame(maxWidth: .infinity, alignment: .topLeading)
                    }.fixedSize(horizontal: false, vertical: true)
                    VoicePane()
                } else { CharacterSheet(c: c).id(c.id) }
            } else { Text(L.t("char.none")).foregroundStyle(Flat.text2); Spacer() }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Bandeau du personnage affiché pendant le choix d'une voix : qui, voix actuelle, interprétation.
struct CharacterStrip: View {
    let c: Character
    @ObservedObject var s = AppState.shared
    var body: some View {
        Card(pad: 12, stretch: true, tint: Flat.sky) { VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Avatar(letter: String(c.name.prefix(1)), size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(c.name).font(.system(size: 15, weight: .semibold)).rowName(c.name)
                    Text(c.role.isEmpty ? "—" : c.role).font(.system(size: 12)).foregroundStyle(Flat.sub).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if let cur = c.current, !cur.samples.isEmpty {
                HStack(spacing: 8) {
                    Header(title: L.t("char.current")).fixedSize()
                    ForEach(Array(cur.samples.prefix(3).enumerated()), id: \.offset) { i, smp in
                        Button { s.play(rel: smp.file) } label: { HStack(spacing: 5) { Image(systemName: s.playingPath == smp.file ? "stop.fill" : "play.fill").font(.system(size: 10)); Text(L.t("char.extract", i + 1)) } }
                            .buttonStyle(FlatButton(primary: true, small: true)).disabled(!FileManager.default.fileExists(atPath: smp.file)).help(smp.text ?? "")
                    }
                    Spacer(minLength: 0)
                }
            }
            Divider().overlay(Flat.sep)
            VStack(alignment: .leading, spacing: 5) {
                Header(title: L.t("char.interp"))
                EmotionPicker(c: c).opacity(s.expressive ? 1 : 0.45)
            }
            VStack(alignment: .leading, spacing: 5) {
                Header(title: L.t("rep.title"))
                HStack(spacing: 6) {
                    Button { s.expressive = false } label: { Chip(title: L.t("rep.faithful"), on: !s.expressive) }.buttonStyle(.plain)
                    Button { s.expressive = true } label: { Chip(title: L.t("rep.expressive"), on: s.expressive) }.buttonStyle(.plain)
                }
                Text(L.t(s.expressive ? "rep.hint.e" : "rep.hint.f")).font(.system(size: 11)).foregroundStyle(Flat.sub).fixedSize(horizontal: false, vertical: true)
            }
        } }
    }
}

/// Choix de l'interprétation (consigne d'émotion) : puces prêtes + consigne libre.
struct EmotionPicker: View {
    let c: Character
    @ObservedObject var s = AppState.shared
    @State private var custom = false
    @State private var text = ""
    var known: Bool { TrialBox.emotions.contains { $0.1 == c.style } }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Flow {
                ForEach(TrialBox.emotions, id: \.0) { e in Button { custom = false; set(e.1) } label: { Chip(title: L.t(e.0), on: !custom && c.style == e.1) }.buttonStyle(.plain) }
                Button { custom.toggle() } label: { Chip(title: L.t("emo.custom"), on: custom || !known) }.buttonStyle(.plain)
            }
            if custom || !known { TextField(L.t("char.style"), text: $text).flatField().onChange(of: text) { _, v in set(v) } }
        }.onAppear { text = c.style; custom = !known }
    }
    func set(_ v: String) { s.update(character: c.id) { $0.style = v } }
}

/// Fiche complète du personnage : identité, voix actuelle, répliques à essayer, interprétation (deux colonnes, rien de tronqué).
struct CharacterSheet: View {
    let c: Character
    @ObservedObject var s = AppState.shared
    @State private var name = ""
    @State private var role = ""
    @State private var notes = ""
    @State private var editing = false
    @State private var linesText = ""
    var voice: Voice? { s.voices.first { $0.id == c.voiceID } }
    var body: some View {
        ScrollView(showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 10) { identity; interpretation; if let cur = c.current { current(cur) } }.frame(maxWidth: .infinity)
                VStack(spacing: 10) { lines }.frame(maxWidth: .infinity)
            }
        }
        .onAppear { name = c.name; role = c.role; notes = c.notes ?? ""; linesText = c.lines.joined(separator: "\n") }
    }
    var identity: some View {
        Card(pad: 14, tint: Flat.sky) { VStack(alignment: .leading, spacing: 8) {
            Header(title: L.t("char.identity"))
            TextField(L.t("char.name"), text: $name).flatField().onChange(of: name) { _, v in s.update(character: c.id) { $0.name = v } }
            Text(L.t("char.role")).font(.system(size: 12)).foregroundStyle(Flat.sub)
            TextEditor(text: $role).font(.system(size: 13)).flatEditor(height: 74).onChange(of: role) { _, v in s.update(character: c.id) { $0.role = v } }
            Text(L.t("char.notes")).font(.system(size: 12)).foregroundStyle(Flat.sub)
            TextEditor(text: $notes).font(.system(size: 13)).flatEditor(height: 74).onChange(of: notes) { _, v in s.update(character: c.id) { $0.notes = v.isEmpty ? nil : v } }
        } }
    }
    func current(_ cur: CurrentVoice) -> some View {
        Card(pad: 14, tint: Flat.mint) { VStack(alignment: .leading, spacing: 10) {
            HStack { Header(title: L.t("char.current")); Spacer(minLength: 6); if let n = c.lineCount { Tag(title: L.t("char.linecount", n)) } }
            if let d = cur.description { Text(d).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true) }
            ForEach(Array(cur.samples.enumerated()), id: \.offset) { _, smp in
                HStack(alignment: .top, spacing: 10) {
                    PlayButton(playing: s.playingPath == smp.file, enabled: FileManager.default.fileExists(atPath: smp.file)) { s.play(rel: smp.file) }
                    Text(smp.text ?? URL(fileURLWithPath: smp.file).lastPathComponent).font(.system(size: 13)).foregroundStyle(Flat.sub).fixedSize(horizontal: false, vertical: true)
                }
            }
        } }
    }
    var lines: some View {
        Card(pad: 14, tint: Flat.lavender) { VStack(alignment: .leading, spacing: 8) {
            HStack { Header(title: L.t("char.lines.title")); Tag(title: "\(s.shownLines(c).count)"); Tag(title: s.activeLang.rawValue.uppercased()); Spacer(minLength: 6)
                Button(editing ? L.t("char.lines.done") : L.t("char.lines.edit")) { editing.toggle(); linesText = editLines.joined(separator: "\n") }.buttonStyle(FlatButton(small: true)) }
            if editing {
                Text(L.t("char.lines")).font(.system(size: 12)).foregroundStyle(Flat.sub)
                TextEditor(text: $linesText).font(.system(size: 13)).flatEditor(height: 240)
                    .onChange(of: linesText) { _, v in
                        let l = v.split(separator: "\n").map(String.init), lang = s.activeLang, main = s.project?.lang ?? .fr
                        s.update(character: c.id) { ch in if lang == main { ch.lines = l } else { var a = ch.altLines ?? [:]; a[lang.rawValue] = l; ch.altLines = a } } }
            } else if s.shownLines(c).isEmpty {
                Text(L.t("char.nolines")).font(.system(size: 13)).foregroundStyle(Flat.sub)
            } else {
                ForEach(Array(s.shownLines(c).enumerated()), id: \.offset) { i, l in
                    HStack(alignment: .top, spacing: 10) {
                        Text(l).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                        Button(L.t("char.lines.try")) { if let v = voice { s.preview(voice: v, text: s.spokenLine(c, i, voice: v), style: c.style, fx: CreatureFX.find(c.fx, for: c)) } }.buttonStyle(FlatButton(small: true))
                            .disabled(voice == nil || s.busy || !s.engineInstalled).help(voice == nil ? L.t("char.pickvoice") : "")
                    }
                    if i < s.shownLines(c).count - 1 { Divider().overlay(Flat.sep) }
                }
            }
        } }
    }
    /// Répliques modifiées par « Modifier » : celles de la langue écoutée (principale = `lines`).
    var editLines: [String] { s.activeLang == (s.project?.lang ?? .fr) ? c.lines : (c.lines(in: s.activeLang) ?? []) }
    var interpretation: some View {
        Card(pad: 14, tint: Flat.butter) { VStack(alignment: .leading, spacing: 8) { Header(title: L.t("char.interp")); EmotionPicker(c: c) } }
    }
}

/// Colonne droite : recherche, filtres (`.box`), voix en deux colonnes, comparaison A / B.
struct VoicePane: View {
    @ObservedObject var s = AppState.shared
    /// Voix affichées : les 120 premières, ou une fenêtre autour de la voix choisie si elle est plus loin.
    var shown: [Voice] {
        let all = s.filteredVoices
        guard let id = s.character?.voiceID, let i = all.firstIndex(where: { $0.id == id }), i >= 100 else { return Array(all.prefix(120)) }
        return Array(all[max(0, i - 50)..<min(all.count, i + 70)])
    }
    /// Au changement de personnage, amène sa voix choisie au centre de la liste pour essayer les voisines.
    func reveal(_ proxy: ScrollViewProxy) {
        guard let id = s.character?.voiceID, shown.contains(where: { $0.id == id }) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .center) } }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(shown) { v in VoiceCard(v: v, mode: .casting).id(v.id) }
                    }
                }
                .onAppear { reveal(proxy) }
                .onChange(of: s.characterID) { _ in reveal(proxy) }
                .onChange(of: s.revealTick) { _ in reveal(proxy) }
            }
            ABBox()
        }.frame(maxWidth: .infinity)
    }
}

struct FilterBox: View {
    @ObservedObject var s = AppState.shared
    var showAgeTone = true
    var search = false
    var stretch = false
    var body: some View {
        Card(pad: 12, stretch: stretch, tint: Flat.prune) { VStack(alignment: .leading, spacing: 8) {
            if search {
                HStack { Image(systemName: "magnifyingglass").foregroundStyle(Flat.sub); TextField(L.t("lib.search.short"), text: $s.fText).textFieldStyle(.plain) }
                    .padding(.horizontal, 11).padding(.vertical, 7).background(Flat.field, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous)).overlay(RoundedRectangle(cornerRadius: Flat.rc, style: .continuous).strokeBorder(Flat.fieldEdge, lineWidth: 1))
            }
            row(L.t("f.gender")) {
                chip(L.t("lib.all"), s.fGender == nil) { s.fGender = nil }
                ForEach(Gender.allCases, id: \.self) { g in chip(L.t("g.\(g.rawValue)"), s.fGender == g) { s.fGender = g } }
            }
            if showAgeTone {
                row(L.t("f.age")) {
                    ForEach([("young", "age.young"), ("adult", "age.adult"), ("senior", "age.senior")], id: \.0) { a in chip(L.t(a.1), s.fAge == a.0) { s.fAge = s.fAge == a.0 ? nil : a.0 } }
                }
                row(L.t("f.tone")) {
                    ForEach([("low", "tone.low"), ("high", "tone.high"), ("warm", "tone.warm"), ("dry", "tone.dry"), ("mischievous", "tone.dark")], id: \.0) { t in chip(L.t(t.1), s.fTone == t.0) { s.fTone = s.fTone == t.0 ? nil : t.0 } }
                }
            }
            row(L.t("f.lang")) {
                ForEach(s.project?.languages ?? []) { l in chip(l.rawValue.uppercased(), s.fLang == l) { s.fLang = s.fLang == l ? nil : l } }
                chip(L.t("lang.all"), s.fLang == nil) { s.fLang = nil }
                chip("★ " + L.t("f.fav"), s.fFav) { s.fFav.toggle() }
                chip(L.t("f.clone"), s.fClone) { s.fClone.toggle() }
            }
            Spacer(minLength: 0)
            HStack { Spacer(minLength: 0); Tag(title: L.t("voices.found", s.voices.count, s.filteredVoices.count)) }
        } }
    }
    func label(_ t: String) -> some View { Text(t).font(.system(size: 11)).foregroundStyle(Flat.sub).frame(width: 44, alignment: .leading) }
    func chip(_ t: String, _ on: Bool, _ a: @escaping () -> Void) -> some View { Button(action: a) { Chip(title: t, on: on) }.buttonStyle(.plain) }
    func row<C: View>(_ t: String, @ViewBuilder _ c: () -> C) -> some View { HStack(alignment: .top, spacing: 8) { label(t).padding(.top, 5); Flow(spacing: 6) { c() }; Spacer(minLength: 0) } }
}

enum CardMode { case casting, library }

/// `.v` : nom + balises, ligne de description, lecteur avec forme d'onde, actions.
struct VoiceCard: View {
    let v: Voice; let mode: CardMode
    var selected = false
    var onSelect: (() -> Void)? = nil
    @ObservedObject var s = AppState.shared
    var chosen: Bool { mode == .casting && s.character?.voiceID == v.id }
    var fav: Bool { s.favorites.contains(v.id) }
    @State private var pick: Lang?
    @State private var free = false
    /// Langue écoutée sur cette carte : celle choisie dans son menu, sinon la langue écoutée du projet (ou le filtre Langue).
    var lang: Lang { pick ?? (mode == .casting ? s.activeLang : (s.fLang ?? s.project?.activeLang ?? .fr)) }
    var body: some View {
        let rel = v.samples[lang.rawValue]
        let isA = chosen, isB = mode == .casting && s.abVoiceID == v.id
        let playing = rel.map { s.playingPath?.hasSuffix($0) == true } ?? (s.playingPath?.contains("/cache/\(v.id).\(lang.rawValue).") == true)
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) { Text(v.name).fontWeight(.semibold).rowName(v.name)
                        if chosen { Tag(title: L.t("lib.chosen").replacingOccurrences(of: " ✓", with: ""), color: Flat.ok) }
                        if isA { Tag(title: "A", solid: true) }; if isB { Tag(title: "B", solid: true) }
                        if v.custom { Tag(title: "clone", color: Flat.brand) } }
                    Text(mode == .casting ? "\(L.t("g.\(v.gender.rawValue)")) · \(v.tone)" : v.tone).font(.system(size: 11.5)).foregroundStyle(Flat.text2).rowName(v.tone)
                }
                Spacer(minLength: 0)
                langTag
                Button { s.toggleFavorite(v.id) } label: {
                    Image(systemName: fav ? "star.fill" : "star").font(.system(size: 13)).foregroundStyle(fav ? Flat.brand : Flat.text2).frame(width: 22, height: 22).contentShape(Rectangle())
                }.buttonStyle(.plain).help(L.t(fav ? "fav.remove" : "fav.add"))
            }
            HStack(spacing: 8) {
                PlayButton(playing: playing, enabled: rel != nil || (s.engineInstalled && !s.busy && !v.samples.isEmpty)) { if playing { s.play(rel: s.playingPath) } else { s.listen(voice: v, lang: lang) } }
                Wave(seed: Double(v.id.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 97 }) / 7, bars: mode == .casting ? 30 : 22, playing: playing)
                ListenLangMenu(v: v, lang: Binding(get: { lang }, set: { pick = $0 }), onPick: { s.listen(voice: v, lang: $0) }, onFreeText: { free = true })
            }
            .popover(isPresented: $free) { FreeTextPopover(v: v, lang: lang, shown: $free) }
            if mode == .casting {
                HStack(spacing: 6) {
                    Button(L.t("v.line")) { tryLine() }.buttonStyle(FlatButton(small: true)).disabled(s.busy || !s.engineInstalled || s.character.map(s.shownLines)?.first == nil)
                    if isB { Button(L.t("ab.cancel")) { s.abVoiceID = nil }.buttonStyle(FlatButton(small: true)) }
                    else if !chosen { Button(L.t("lib.ab")) { s.abVoiceID = v.id }.buttonStyle(FlatButton(small: true)) }
                    Spacer(minLength: 0)
                    Button(chosen ? L.t("lib.chosen") : L.t("lib.choose")) { s.choose(voice: v.id) }.buttonStyle(FlatButton(primary: chosen, small: true)).disabled(s.characterID == nil)
                }
            }
        }
        .tile(pad: EdgeInsets(top: 9, leading: 10, bottom: 9, trailing: 10), outline: chosen ? Flat.ok : (isB ? Flat.acc : nil), dashed: isB && !chosen, selected: selected)
        .contentShape(Rectangle()).onTapGesture { onSelect?() }
    }
    func tryLine() { if let c = s.character, !s.shownLines(c).isEmpty { s.preview(voice: v, text: s.spokenLine(c, 0, voice: v, lang: lang), style: c.style, fx: CreatureFX.find(c.fx, for: c), lang: lang) } }
    /// Langues prêtes de la voix pour le projet (« DE · EN »), en orange si une langue du projet reste à calculer.
    @ViewBuilder var langTag: some View {
        let proj = s.project?.languages ?? []
        let ready = proj.filter { v.samples[$0.rawValue] != nil }, missing = proj.filter { v.samples[$0.rawValue] == nil }
        if mode == .library { EmptyView() }      // bibliothèque : cartes étroites, langues dans le menu et la fiche
        else if v.custom || proj.isEmpty { if !v.samples.isEmpty { Tag(title: v.samples.keys.compactMap(Lang.init(rawValue:)).sorted().map { $0.rawValue.uppercased() }.joined(separator: " · ")) } }
        else if missing.isEmpty { Tag(title: ready.map { $0.rawValue.uppercased() }.joined(separator: " · "), color: Flat.ok) }
        else { Tag(title: (ready + missing).map { $0.rawValue.uppercased() + (missing.contains($0) ? "…" : "") }.joined(separator: " · "), color: Flat.warn).help(L.t("lang.tag.missing")) }
    }
}

/// Comparaison A / B : voix choisie (A) contre la voix mise de côté (B), même réplique.
struct ABBox: View {
    @ObservedObject var s = AppState.shared
    var body: some View {
        if let b = s.voices.first(where: { $0.id == s.abVoiceID }), let a = s.voices.first(where: { $0.id == s.character?.voiceID }), a.id != b.id {
            Card { VStack(alignment: .leading, spacing: 6) {
                HStack { Header(title: L.t("ab.title")); Spacer(minLength: 0)
                    Button(L.t("ab.cancel")) { s.abVoiceID = nil }.buttonStyle(FlatButton(small: true)) }
                HStack(alignment: .top, spacing: 8) { side("A", a); side("B", b) }
            } }
        }
    }
    func side(_ l: String, _ v: Voice) -> some View {
        let lang = s.activeLang.rawValue, rel = v.samples[lang]
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) { Tag(title: l, solid: true); Text(v.name).fontWeight(.semibold).rowName(v.name) }
            HStack(spacing: 8) { PlayButton(playing: rel.map { s.playingPath?.hasSuffix($0) == true } ?? false, enabled: rel != nil) { s.play(rel: rel) }; Wave(seed: l == "A" ? 3 : 5, bars: 40, playing: l == "A") }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Projets
struct ProjectsView: View {
    @ObservedObject var s = AppState.shared
    @State private var adding = false
    @State private var name = ""
    @State private var lang: Lang = .fr
    @State private var second: Lang? = nil
    @State private var filter = ""
    @State private var toDelete: Project?
    var shown: [Project] { filter.isEmpty ? s.projects : s.projects.filter { $0.name.lowercased().contains(filter.lowercased()) } }
    var body: some View {
        Page {
            HStack(spacing: 10) {
                Title(text: L.t("nav.projects"))
                HStack { Image(systemName: "magnifyingglass").foregroundStyle(Flat.text2); TextField(L.t("proj.filter"), text: $filter).textFieldStyle(.plain) }
                    .padding(.horizontal, 11).padding(.vertical, 7).background(Flat.ctl, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous)).frame(maxWidth: 300)
                Spacer()
                Button(L.t("btn.import")) { let o = NSOpenPanel(); o.allowedContentTypes = [.json]; if o.runModal() == .OK, let u = o.url { s.importProject(from: u) } }.buttonStyle(FlatButton())
                Button("＋ " + L.t("proj.new")) { SetupModel.shared.start(quick: SetupState.load().completed) }.buttonStyle(FlatButton(green: true))
            }
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(shown) { p in
                        card(p).overlay(alignment: .topTrailing) {
                            Button { toDelete = p } label: { Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Flat.text2).frame(width: 22, height: 22).contentShape(Rectangle()) }
                                .buttonStyle(.plain).help(L.t("proj.delete")).accessibilityLabel(L.t("proj.delete")).padding(.top, 12).padding(.trailing, 10)
                        }
                    }
                    Button { SetupModel.shared.start(quick: SetupState.load().completed) } label: {
                        VStack(spacing: 4) { Text("＋ " + L.t("proj.new")); Text(L.t("proj.create.agent")).font(.system(size: 11.5)) }.foregroundStyle(Flat.text2)
                            .frame(maxWidth: .infinity, minHeight: 150)
                            .overlay(RoundedRectangle(cornerRadius: Flat.rb, style: .continuous).strokeBorder(Flat.ctl, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
                    }.buttonStyle(.plain)
                }
            }
            Text(L.t("proj.note")).font(.system(size: 11.5)).foregroundStyle(Flat.text2).padding(.horizontal, 10).padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading)
                .background(Flat.ctl, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
        }
        .alert(L.t("proj.delete.q", toDelete?.name ?? ""), isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } })) {
            Button(L.t("btn.cancel"), role: .cancel) { toDelete = nil }
            Button(L.t("proj.delete"), role: .destructive) { if let p = toDelete { s.deleteProject(p.id) }; toDelete = nil }
        } message: { Text(L.t("proj.delete.msg")) }
        .sheet(isPresented: $adding) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L.t("proj.new")).font(.system(size: 15, weight: .semibold))
                TextField(L.t("proj.name"), text: $name).flatField()
                LangPairPicker(main: $lang, second: $second)
                HStack { Spacer(); Button(L.t("btn.cancel")) { adding = false }.buttonStyle(FlatButton())
                    Button(L.t("btn.create")) { s.newProject(name: name.isEmpty ? L.t("proj.new") : name, lang: lang, second: second); name = ""; adding = false }.buttonStyle(FlatButton(primary: true)) }
            }.padding(20).frame(width: 620).background(Flat.bg).foregroundStyle(Flat.text).tint(Flat.acc)
        }
    }
    func state(_ p: Project) -> (String, Color) {
        if p.characters.isEmpty || p.castCount == 0 { return (L.t("proj.state.empty"), Flat.warn) }
        if let f = p.folder, FileManager.default.fileExists(atPath: f + "/casting.json") { return p.castCount == p.characters.count ? (L.t("proj.state.done"), Flat.ok) : (L.t("proj.state.progress"), Flat.warn) }
        return (L.t("proj.state.progress"), Flat.warn)
    }
    func card(_ p: Project) -> some View {
        let st = state(p)
        return Button { s.projectID = p.id; s.characterID = p.characters.first?.id; s.screen = .casting } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text(p.name).font(.system(size: 15, weight: .semibold)).rowName(p.name); Spacer(minLength: 4); Tag(title: p.languages.map { $0.rawValue.uppercased() }.joined(separator: " · ")).padding(.trailing, 22) }
                Text(p.folder.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "—").font(.system(size: 11.5)).foregroundStyle(Flat.text2).rowName(p.folder ?? "")
                HStack(spacing: 18) {
                    VStack(alignment: .leading) { Text("\(p.characters.count)").font(.system(size: 24, weight: .bold)); Text(L.t("proj.chars")).font(.system(size: 11.5)).foregroundStyle(Flat.text2) }
                    VStack(alignment: .leading) { Text("\(p.castCount)").font(.system(size: 24, weight: .bold)).foregroundStyle(Flat.brand); Text(L.t("proj.cast")).font(.system(size: 11.5)).foregroundStyle(Flat.text2) }
                }
                Bar2(value: Double(p.castCount) / Double(max(p.characters.count, 1)))
                HStack(spacing: 6) { Text(p.folder.map { "…/" + URL(fileURLWithPath: $0).lastPathComponent + "/casting.json" } ?? "casting.json").font(.system(size: 11.5)).foregroundStyle(Flat.text2).rowName(p.folder ?? ""); Tag(title: st.0, color: st.1) }
            }.tile(pad: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14), selected: s.projectID == p.id)
        }.buttonStyle(.plain)
    }
}

/// `.bar2` : jauge de 6 px, accent.
struct Bar2: View {
    var value: Double; var height: CGFloat = 6
    var body: some View {
        GeometryReader { g in ZStack(alignment: .leading) { Capsule().fill(Flat.ctl); Capsule().fill(Flat.acc).frame(width: g.size.width * min(max(value, 0), 1)) } }.frame(height: height)
    }
}

// MARK: Bibliothèque
struct LibraryView: View {
    @ObservedObject var s = AppState.shared
    @State private var selID: String?
    @State private var line = ""
    @State private var emo = ""
    @State private var usage: Int = 0      // 0 tous, 1 utilisées, 2 jamais utilisées
    var used: [String: Int] { s.projects.flatMap(\.characters).compactMap(\.voiceID).reduce(into: [:]) { $0[$1, default: 0] += 1 } }
    var voices: [Voice] { s.filteredVoices.filter { usage == 0 || (usage == 1) == (used[$0.id] != nil) } }
    var sel: Voice? { s.voices.first { $0.id == selID } ?? voices.first }
    var body: some View {
        Page {
            HStack(spacing: 10) {
                Title(text: L.t("nav.library"))
                Tag(title: L.t("lib.recipes", s.libVoices.count, s.doneSamples))
                HStack { Image(systemName: "magnifyingglass").foregroundStyle(Flat.text2); TextField(L.t("lib.search"), text: $s.fText).textFieldStyle(.plain) }
                    .padding(.horizontal, 11).padding(.vertical, 7).background(Flat.ctl, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous)).frame(maxWidth: 440)
                Spacer()
                Button(L.t("gen.title")) { s.screen = .generation }.buttonStyle(FlatButton(primary: s.remainingSamples > 0))
            }
            Card { VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(L.t("f.gender")).font(.system(size: 11)).foregroundStyle(Flat.text2).frame(width: 44, alignment: .leading)
                    Button { s.fGender = nil } label: { Chip(title: L.t("lib.all"), on: s.fGender == nil) }.buttonStyle(.plain)
                    ForEach(Gender.allCases, id: \.self) { g in Button { s.fGender = g } label: { Chip(title: L.t("g.\(g.rawValue)"), on: s.fGender == g) }.buttonStyle(.plain) }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    Text(L.t("f.lang")).font(.system(size: 11)).foregroundStyle(Flat.text2).frame(width: 44, alignment: .leading)
                    ForEach(s.filterLangs) { l in Button { s.fLang = s.fLang == l ? nil : l } label: { Chip(title: l.rawValue.uppercased(), on: s.fLang == l) }.buttonStyle(.plain).help(l.localized) }
                    Button { s.fFav.toggle() } label: { Chip(title: "★ " + L.t("f.fav"), on: s.fFav) }.buttonStyle(.plain).padding(.leading, 14)
                    Button { s.fClone.toggle() } label: { Chip(title: L.t("f.clone"), on: s.fClone) }.buttonStyle(.plain)
                    Spacer(minLength: 0)
                    Button { usage = usage == 1 ? 0 : 1 } label: { Chip(title: L.t("lib.used"), on: usage == 1) }.buttonStyle(.plain)
                    Button { usage = usage == 2 ? 0 : 2 } label: { Chip(title: L.t("lib.unused"), on: usage == 2) }.buttonStyle(.plain)
                }
            } }
            HStack(alignment: .top, spacing: 12) {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(voices.prefix(150)) { v in VoiceCard(v: v, mode: .library, selected: sel?.id == v.id, onSelect: { selID = v.id }) }
                    }.frame(maxWidth: .infinity)
                }.frame(maxWidth: .infinity)
                if let v = sel { ScrollView(showsIndicators: false) { Sheet(v: v, line: $line, emo: $emo, uses: used[v.id] ?? 0) }.frame(width: 340) }
            }
        }
    }
}

struct Sheet: View {
    let v: Voice; @Binding var line: String; @Binding var emo: String; let uses: Int
    @ObservedObject var s = AppState.shared
    @State private var askDelete = false
    var body: some View {
        let names = s.projects.filter { $0.characters.contains { $0.voiceID == v.id } }.map(\.name).joined(separator: ", ")
        Card { VStack(alignment: .leading, spacing: 8) {
            Header(title: L.t("lib.sheet") + " · " + v.name)
            Text(L.t("lib.recipe")).font(.system(size: 11.5)).foregroundStyle(Flat.text2)
            Text(v.recipe).font(.system(size: 11.5, design: .monospaced)).padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Flat.ctl, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
            kv(L.t("lib.engine"), v.engine == "qwen3-base" ? "Qwen3 Base" : "Qwen3 VoiceDesign")
            kv(L.t("lib.samples"), s.filterLangs.map { $0.rawValue.uppercased() + (v.samples[$0.rawValue] != nil ? " ✓" : " –") }.joined(separator: " · "))
            kv(L.t("lib.usedin"), names.isEmpty ? "—" : names)
            Header(title: L.t("lib.test")).padding(.top, 6)
            TextField("", text: $line, axis: .vertical).font(.system(size: 12.5)).lineLimit(3...14).flatField()   // grandit avec le texte
            Flow { ForEach(TrialBox.emotions, id: \.0) { e in Button { emo = e.1 } label: { Chip(title: L.t(e.0), on: emo == e.1) }.buttonStyle(.plain) } }
            Button("▶ " + L.t("lib.try")) { s.preview(voice: v, text: line.isEmpty ? Catalog.sample(for: v, lang: sheetLang) : line, style: emo, expressive: !emo.isEmpty, lang: sheetLang) }
                .buttonStyle(FlatButton(primary: true)).disabled(s.busy || !s.engineInstalled)
            if v.custom {
                Divider().padding(.vertical, 4)
                Button(role: .destructive) { askDelete = true } label: { Label(L.t("voice.delete"), systemImage: "trash") }
                    .buttonStyle(FlatButton(small: true)).disabled(s.busy)
            }
        } }
        .alert(L.t("voice.delete.q", v.name), isPresented: $askDelete) {
            Button(L.t("btn.cancel"), role: .cancel) {}
            Button(L.t("voice.delete"), role: .destructive) { s.deleteVoice(v.id) }
        } message: { Text(names.isEmpty ? L.t("voice.delete.msg") : L.t("voice.delete.used", names) + " " + L.t("voice.delete.msg")) }
        .onAppear { if line.isEmpty { line = Catalog.sample(for: v, lang: sheetLang) } }
        .onChange(of: v.id) { _, _ in line = Catalog.sample(for: v, lang: sheetLang) }
        .onChange(of: s.fLang) { _, _ in line = Catalog.sample(for: v, lang: sheetLang) }
    }
    var sheetLang: Lang { s.fLang ?? s.project?.activeLang ?? .fr }
    func kv(_ k: String, _ val: String) -> some View { HStack(alignment: .top) { Text(k).foregroundStyle(Flat.text2); Spacer(minLength: 8); Text(val).multilineTextAlignment(.trailing) }.font(.system(size: 13)) }
}

// MARK: Génération
struct GenerationView: View {
    @ObservedObject var s = AppState.shared
    @State private var sizeMB = 0
    var running: Bool { s.busy && s.task == "library" }
    var body: some View {
        let done = s.doneSamples, total = max(s.totalSamples, 1), left = s.remainingSamples
        let secs = Int(Double(left) * s.avg), time = secs >= 3600 ? "\(secs / 3600) h \(String(format: "%02d", secs % 3600 / 60))" : "\(secs / 60) min"
        Page {
            HStack(spacing: 10) {
                Title(text: L.t("gen.title"))
                Tag(title: running ? L.t("gen.running") : (left == 0 ? L.t("gen.complete") : L.t("gen.idle")), color: running ? Flat.warn : (left == 0 ? Flat.ok : nil))
                Spacer()
                if running { Button(L.t("btn.stop")) { s.cancel() }.buttonStyle(FlatButton()) }
                else { Button(L.t("gen.start")) { s.generateLibrary() }.buttonStyle(FlatButton(primary: true)).disabled(left == 0 || !s.engineInstalled || s.busy) }
            }
            HStack(spacing: 10) {
                stat("\(done) / \(s.totalSamples)", L.t("gen.samples")); stat("\(done * 100 / total) %", L.t("gen.progress"))
                stat(left == 0 ? "—" : time, L.t("gen.left", s.avg)); stat("\(sizeMB) Mo", "audio")
            }
            Card { Bar2(value: Double(done) / Double(total), height: 10) }
            LibraryLangsCard()
            HStack(alignment: .top, spacing: 12) {
                Card { VStack(alignment: .leading, spacing: 6) {
                    Header(title: L.t("gen.bycat"))
                    ForEach(Gender.allCases, id: \.self) { g in
                        let vs = s.libVoices.filter { $0.gender == g }, ls = s.libLangs
                        let d = ls.reduce(0) { $0 + LibraryGenerator.ready(vs, $1) }, t = max(vs.count * ls.count, 1)
                        HStack { Text(L.t("g.\(g.rawValue)")).foregroundStyle(Flat.text2); Spacer(); Text("\(d) / \(vs.count * ls.count)").monospacedDigit() }
                        Bar2(value: Double(d) / Double(t))
                    }
                } }
                Card { VStack(alignment: .leading, spacing: 8) {
                    Header(title: L.t("gen.log"))
                    Text(s.log.isEmpty ? " " : String(s.log.split(separator: "\n").suffix(8).joined(separator: "\n"))).font(.system(size: 11.5, design: .monospaced)).frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                        .padding(10).background(Flat.ctl, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
                    Text(L.t("gen.note")).font(.system(size: 11.5)).foregroundStyle(Flat.text2)
                } }
            }
            Spacer(minLength: 0)
        }.onAppear { sizeMB = Self.audioMB() }
    }
    func stat(_ big: String, _ small: String) -> some View {
        Card { VStack(alignment: .leading, spacing: 2) { Text(big).font(.system(size: 22, weight: .bold)).lineLimit(1).monospacedDigit(); Text(small).font(.system(size: 11.5)).foregroundStyle(Flat.text2).lineLimit(1) } }
    }
    static func audioMB() -> Int {
        let en = FileManager.default.enumerator(at: Paths.audio.appendingPathComponent("lib"), includingPropertiesForKeys: [.fileSizeKey])
        var n = 0; while let u = en?.nextObject() as? URL { n += (try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0 }
        return n / 1_000_000
    }
}

// MARK: Clonage
struct CloneView: View {
    @ObservedObject var s = AppState.shared
    @State private var link = ""
    @State private var source: URL?
    @State private var label = ""
    @State private var start = 0.0
    @State private var length = 10.0
    @State private var transcript = ""
    @State private var name = ""
    @State private var consent = false
    @State private var gender: Gender = .man
    @State private var working = false
    @State private var message = ""
    @State private var total = 0.0
    var body: some View {
        Page { ScrollView(showsIndicators: false) { VStack(alignment: .leading, spacing: 10) {
            Title(text: L.t("nav.clone")); Text(L.t("clone.sub")).font(.system(size: 12)).foregroundStyle(Flat.text2)
            Card { VStack(alignment: .leading, spacing: 8) {
                HStack { Button(L.t("clone.file")) { pickFile() }.buttonStyle(FlatButton(primary: true))
                    Text(label).font(.system(size: 12)).foregroundStyle(Flat.text2).lineLimit(1) }
                HStack { TextField(L.t("clone.link"), text: $link).flatField()
                    Button(L.t("clone.fetch")) { fetch() }.buttonStyle(FlatButton()).disabled(link.isEmpty || working || !s.engineInstalled) }
            } }
            if source != nil {
                Card { VStack(alignment: .leading, spacing: 8) {
                    HStack { Text(L.t("clone.start")); TextField("", value: $start, format: .number).frame(width: 60).flatField()
                        Text(L.t("clone.length")); TextField("", value: $length, format: .number).frame(width: 60).flatField()
                        Text(String(format: "/ %.0f s", total)).foregroundStyle(Flat.text2); Spacer()
                        Button { listen() } label: { Image(systemName: "play.fill") }.buttonStyle(FlatButton()) }
                    Text(L.t("clone.hint")).font(.system(size: 12)).foregroundStyle(Flat.text2)
                    Text(L.t("clone.transcript")).font(.system(size: 12)).foregroundStyle(Flat.text2)
                    TextEditor(text: $transcript).font(.system(size: 12.5)).flatEditor(height: 70)
                    Button(L.t("clone.auto")) { transcribe() }.buttonStyle(FlatButton()).disabled(working || !s.engineInstalled)
                    HStack { TextField(L.t("clone.name"), text: $name).flatField()
                        Picker("", selection: $gender) { ForEach(Gender.allCases, id: \.self) { Text(L.t("g.\($0.rawValue)")).tag($0) } }.frame(width: 130) }
                    Toggle(L.t("clone.consent"), isOn: $consent).toggleStyle(.checkbox)
                    Button(L.t("clone.create")) { create() }.buttonStyle(FlatButton(primary: true)).disabled(!consent || name.isEmpty || transcript.isEmpty || working)
                } }
            }
            if working { ProgressView().controlSize(.small) }
            if !message.isEmpty { Text(message).font(.system(size: 12)).foregroundStyle(Flat.text2) }
        } } }
    }
    private var work: URL { FileManager.default.temporaryDirectory.appendingPathComponent("mcasting-clone") }
    func pickFile() {
        let o = NSOpenPanel(); o.allowedContentTypes = [.audio, .movie]
        if o.runModal() == .OK, let u = o.url { source = u; label = u.lastPathComponent; load(u) }
    }
    func load(_ u: URL) { Task { total = await VoiceCloning.duration(of: u); length = min(10, total) } }
    func fetch() {
        working = true; message = ""
        let l = link, dir = work.appendingPathComponent("dl-\(UUID().uuidString)")
        Task.detached {
            do { let f = try VoiceCloning.fetch(link: l, into: dir, log: { _ in })
                await MainActor.run { source = f; label = l; working = false; load(f) } }
            catch { await MainActor.run { working = false; message = error.localizedDescription } }
        }
    }
    func prepared() async throws -> VoiceCloning.Prepared {
        guard let src = source else { throw EngineError.failed("No source") }
        return try await VoiceCloning.prepare(source: src, start: start, length: length, label: label, into: work.appendingPathComponent("p-\(UUID().uuidString)"))
    }
    func listen() { Task { if let p = try? await prepared() { s.play(rel: p.wav.path) } } }
    func transcribe() {
        working = true; message = ""
        Task { do { let p = try await prepared(); let lang = s.project?.lang ?? .fr
            let t = try await Task.detached { try VoiceCloning.transcribe(p.wav, lang: lang) }.value
            transcript = t; working = false } catch { working = false; message = error.localizedDescription } }
    }
    func create() {
        working = true
        Task { do { let p = try await prepared(); try VoiceCloning.register(name: name, gender: gender, prepared: p, refText: transcript, lang: s.project?.lang ?? .fr)
            s.reload(force: true); working = false; message = L.t("clone.done"); source = nil; name = ""; transcript = ""; consent = false }
            catch { working = false; message = error.localizedDescription } }
    }
}

// MARK: Modèles
struct ModelsView: View {
    @ObservedObject var s = AppState.shared
    var body: some View {
        Page {
            HStack(spacing: 10) { Title(text: L.t("mod.title")); Spacer(); Button(L.t("mod.verify")) { s.engineInstalled = Engine.installed; s.objectWillChange.send() }.buttonStyle(FlatButton()) }
            Text(L.t("mod.sub")).font(.system(size: 12)).foregroundStyle(Flat.text2)
            ScrollView(showsIndicators: false) { VStack(spacing: 8) {
                row(letter: "E", title: L.t("mod.engine"), sub: "uv · Python 3.12 · mlx-audio · yt-dlp", ok: s.engineInstalled, size: nil, first: false, action: { s.installEngine() }, label: L.t("mod.install"), enabled: !s.busy)
                ForEach(TTSModel.catalog) { m in
                    row(letter: String(m.title.prefix(1)), title: m.title, sub: m.notes.replacingOccurrences(of: "_", with: " "), ok: m.installed, size: m.sizeGB, first: m.reference && m.id == "qwen3-voicedesign", ref: m.reference, langs: Languages.of(m),
                        action: { s.download(m) }, label: L.t("mod.download"), enabled: !s.busy && s.engineInstalled)
                }
                if s.busy { Card { Text(String(s.log.suffix(400))).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Flat.text2).frame(maxWidth: .infinity, alignment: .leading) } }
            } }
            Text(L.t("mod.note")).font(.system(size: 11.5)).foregroundStyle(Flat.text2).padding(.horizontal, 10).padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading)
                .background(Flat.ctl, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
        }
    }
    func row(letter: String, title: String, sub: String, ok: Bool, size: Double?, first: Bool, ref: Bool = false, langs: [Lang] = [], action: @escaping () -> Void, label: String, enabled: Bool) -> some View {
        HStack(spacing: 14) {
            Avatar(letter: letter, size: 42)
            VStack(alignment: .leading, spacing: 2) { HStack(spacing: 8) { Text(title).fontWeight(.semibold).rowName(title); if ref { Tag(title: L.t("mod.reference"), solid: true) }
                    if !langs.isEmpty { Tag(title: L.t("mdl.langs", langs.count), color: Flat.acc).help(langs.map(\.native).joined(separator: " · ")) } }
                Text(sub).font(.system(size: 11.5)).foregroundStyle(Flat.text2).rowName(sub)
                if !langs.isEmpty { Text(langs.map(\.native).joined(separator: " · ")).font(.system(size: 11)).foregroundStyle(Flat.text2).lineLimit(1).truncationMode(.tail).help(langs.map { $0.localized }.joined(separator: ", ")) } }
            Spacer(minLength: 8)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) { Tag(title: ok ? L.t("mod.installed") : L.t("mod.notinstalled"), color: ok ? Flat.ok : Flat.warn); if let size { Text(String(format: "%.1f GB", size)).font(.system(size: 11.5)).foregroundStyle(Flat.text2) } }
                Bar2(value: ok ? 1 : 0)
            }.frame(width: 170)
            Group { if ok { Text("✓").foregroundStyle(Flat.ok) } else { Button(label, action: action).buttonStyle(FlatButton(primary: true, small: true)).disabled(!enabled) } }.frame(width: 130, alignment: .trailing)
        }.padding(.horizontal, 14).padding(.vertical, 11)
        .background(Flat.card, in: RoundedRectangle(cornerRadius: Flat.rb, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Flat.rb, style: .continuous).strokeBorder(Flat.line, lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: Flat.rb, style: .continuous).strokeBorder(first ? Flat.acc : .clear, lineWidth: 2))
    }
}

// MARK: Réglages
struct SettingsView: View {
    @ObservedObject var updater = Updater.shared
    @ObservedObject var s = AppState.shared
    @AppStorage("autoUpdate") private var auto = true
    var mcp: String { "claude mcp add mcasting -- \"\(Bundle.main.bundlePath)/Contents/MacOS/mcasting-mcp\"" }
    var body: some View {
        Page {
            Title(text: L.t("nav.settings"))
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 10) {
                    Card { VStack(alignment: .leading, spacing: 4) {
                        Header(title: L.t("set.general"))
                        line(L.t("set.lang")) { Text(L.t("set.lang.auto")).foregroundStyle(Flat.text2) }
                        Divider().overlay(Flat.line)
                        line(L.t("set.library")) { Button(L.t("btn.finder")) { NSWorkspace.shared.open(Paths.home) }.buttonStyle(FlatButton(small: true)) }
                        Text(Paths.home.path).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Flat.text2).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                    } }
                    Card { VStack(alignment: .leading, spacing: 4) {
                        Header(title: L.t("upd.title"))
                        line(L.t("upd.auto")) { Toggle("", isOn: $auto).toggleStyle(.switch).labelsHidden().tint(Flat.ok) }
                        Divider().overlay(Flat.line)
                        line(L.t("upd.version", updater.currentVersion)) { Button(L.t("upd.check")) { Task { await updater.check() } }.buttonStyle(FlatButton(small: true)).disabled(updater.state == .checking || updater.state == .downloading) }
                        if case .available(let v) = updater.state { Button(L.t("upd.install", v)) { Task { await updater.install() } }.buttonStyle(FlatButton(primary: true, small: true)) }
                        Text(status).font(.system(size: 11.5)).foregroundStyle(Flat.text2)
                    } }
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                VStack(spacing: 10) {
                    Card { VStack(alignment: .leading, spacing: 6) {
                        Header(title: L.t("set.mcp"))
                        line(L.t("set.transport")) { Tag(title: "stdio", color: Flat.ok) }
                        Text(L.t("set.mcp.help")).font(.system(size: 11.5)).foregroundStyle(Flat.text2)
                        Text(mcp).font(.system(size: 11.5, design: .monospaced)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true).padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Flat.ctl, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
                        Button(L.t("set.copy")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(mcp, forType: .string) }.buttonStyle(FlatButton(small: true))
                        Text(L.t("set.tools")).font(.system(size: 11.5)).foregroundStyle(Flat.text2).fixedSize(horizontal: false, vertical: true)
                    } }
                    Card { VStack(alignment: .leading, spacing: 6) {
                        Header(title: L.t("set.agentlog"))
                        Text(s.mcpLog().isEmpty ? L.t("set.agentlog.empty") : s.mcpLog()).font(.system(size: 11.5, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).padding(10).background(Flat.ctl, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
                    } }
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            Spacer(minLength: 0)
        }
    }
    func line<C: View>(_ t: String, @ViewBuilder _ c: () -> C) -> some View { HStack { Text(t).lineLimit(1); Spacer(minLength: 8); c() }.frame(minHeight: 30) }
    var status: String {
        switch updater.state {
        case .idle: return L.t("upd.version", updater.currentVersion)
        case .checking: return L.t("upd.checking")
        case .upToDate: return L.t("upd.uptodate", updater.currentVersion)
        case .available(let v): return L.t("upd.available", v)
        case .downloading: return L.t("upd.downloading")
        case .failed(let e): return L.t("upd.failed", e)
        }
    }
}
