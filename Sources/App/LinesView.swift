// mCASTING — écran « Répliques » : base de répliques reçues (mTALKIE, autres outils), recherche plein texte, filtres,
// écoute et attribution à un personnage (maquette validée : mTALKIE/maquettes/pipeline.html, écran D).
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct LinesView: View {
    @ObservedObject var s = AppState.shared
    @State private var text = ""
    @State private var srcs: Set<String> = []
    @State private var tags: Set<String> = []
    @State private var lang = ""
    @State private var speaker = ""
    @State private var dur = 0                 // 0 toutes, 1 < 2 s, 2 2-6 s, 3 > 6 s
    @State private var results: [LineRecord] = []
    @State private var total = 0
    @State private var sources: [LineSource] = []
    @State private var assigning: LineRecord?
    @State private var removing: LineSource?
    @State private var tick = 0

    var allCount: Int { sources.reduce(0) { $0 + $1.count } }
    var langs: [String] { Array(Set(sources.flatMap(\.langs))).filter { !$0.isEmpty }.sorted() }

    var body: some View {
        Page {
            HStack(spacing: 10) {
                Title(text: L.t("nav.lines"))
                Tag(title: L.t("lines.total", allCount))
                HStack { Image(systemName: "magnifyingglass").foregroundStyle(Flat.text2); TextField(L.t("lines.search"), text: $text).textFieldStyle(.plain) }
                    .padding(.horizontal, 11).padding(.vertical, 7).background(Flat.ctl, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous)).frame(maxWidth: 460)
                if allCount > 0 { Tag(title: L.t("lines.found", total), color: Flat.ok) }
                Spacer()
                Button(L.t("lines.inbox")) { NSWorkspace.shared.open(Paths.inbox) }.buttonStyle(FlatButton(small: true))
                Button(L.t("lines.export")) { export() }.buttonStyle(FlatButton()).disabled(results.isEmpty)
            }
            if sources.isEmpty { empty } else { filters; list }
        }
        .onAppear { reloadSources(); search() }
        .onChange(of: s.linesTick) { _, _ in reloadSources(); search() }
        .task(id: query) { try? await Task.sleep(nanoseconds: 150_000_000); search() }
        .sheet(item: $assigning) { r in AssignSheet(r: r) }
        .alert(L.t("lines.remove.q", removing?.title ?? "", removing?.count ?? 0), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            Button(L.t("btn.cancel"), role: .cancel) { removing = nil }
            Button(L.t("char.assigned.remove"), role: .destructive) { if let r = removing { try? LinesStore.remove(source: r.id); srcs.remove(r.id); reloadSources(); search() }; removing = nil }
        } message: { Text(L.t("lines.remove.msg")) }
    }

    /// Clé de recherche : relance la recherche à chaque changement de texte ou de filtre.
    var query: String { [text, srcs.sorted().joined(separator: ","), tags.sorted().joined(separator: ","), lang, speaker, "\(dur)", "\(tick)"].joined(separator: "|") }

    var empty: some View {
        Card(pad: 18) { VStack(alignment: .leading, spacing: 8) {
            Text(L.t("lines.empty")).font(.system(size: 15, weight: .semibold))
            Text(L.t("lines.empty.how")).foregroundStyle(Flat.text2).fixedSize(horizontal: false, vertical: true)
            Button(L.t("lines.inbox")) { NSWorkspace.shared.open(Paths.inbox) }.buttonStyle(FlatButton(primary: true)).padding(.top, 4)
        } }.frame(maxWidth: 620)
    }

    var filters: some View {
        Card { VStack(alignment: .leading, spacing: 6) {
            row(L.t("lines.f.source")) {
                Button { srcs = [] } label: { Chip(title: L.t("lines.all"), on: srcs.isEmpty) }.buttonStyle(.plain)
                ForEach(sources) { src in
                    Button { if srcs.contains(src.id) { srcs.remove(src.id) } else { srcs.insert(src.id) } } label: { Chip(title: src.title, on: srcs.contains(src.id)) }
                        .buttonStyle(.plain).help("\(src.count)")
                        .contextMenu { Button(L.t("lines.remove", src.title), role: .destructive) { removing = src } }
                }
            }
            row(L.t("lines.f.tags")) {
                ForEach(LinesStore.knownTags, id: \.self) { t in
                    Button { if tags.contains(t) { tags.remove(t) } else { tags.insert(t) } } label: { Chip(title: L.t("tag." + t), on: tags.contains(t)) }.buttonStyle(.plain)
                }
            }
            row(L.t("lines.f.lang")) {
                Button { lang = "" } label: { Chip(title: L.t("lines.all"), on: lang.isEmpty) }.buttonStyle(.plain)
                ForEach(langs, id: \.self) { l in Button { lang = lang == l ? "" : l } label: { Chip(title: l.uppercased(), on: lang == l) }.buttonStyle(.plain) }
                Text(L.t("lines.f.dur")).font(.system(size: 11)).foregroundStyle(Flat.text2).padding(.leading, 12)
                ForEach(Array(["< 2 s", "2-6 s", "> 6 s"].enumerated()), id: \.offset) { i, t in
                    Button { dur = dur == i + 1 ? 0 : i + 1 } label: { Chip(title: t, on: dur == i + 1) }.buttonStyle(.plain)
                }
                TextField(L.t("lines.f.char"), text: $speaker).flatField().frame(width: 200).padding(.leading, 12)
            }
        } }
    }

    func row<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title).font(.system(size: 11)).foregroundStyle(Flat.text2).frame(width: 74, alignment: .leading).padding(.top, 4)
            Flow { c() }
        }
    }

    var list: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 6) {
                ForEach(results) { r in LineRow(r: r) { assigning = r } }
                if total > results.count { Text(L.t("lines.more", results.count)).font(.system(size: 12)).foregroundStyle(Flat.text2).padding(8) }
            }
        }
    }

    func reloadSources() { sources = LinesStore.sources() }
    func search() {
        var q = LinesStore.Query()
        q.text = text; q.sources = Array(srcs); q.tags = Array(tags); q.lang = lang; q.character = speaker; q.limit = 300
        switch dur { case 1: q.maxDuration = 2; case 2: q.minDuration = 2; q.maxDuration = 6; case 3: q.minDuration = 6; default: break }
        let r = LinesStore.search(q); results = r.lines; total = r.total
    }

    /// Export des répliques affichées : CSV (tableur) ou JSON, selon l'extension choisie.
    func export() {
        let p = NSSavePanel()
        p.allowedContentTypes = [.commaSeparatedText, .json]; p.nameFieldStringValue = "lines.csv"
        guard p.runModal() == .OK, let url = p.url else { return }
        do {
            if url.pathExtension.lowercased() == "json" {
                let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
                try e.encode(results).write(to: url, options: .atomic)
            } else {
                func q(_ v: String) -> String { "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
                var csv = "source,key,character,lang,duration,tags,text,audio\n"
                for r in results { csv += [r.sourceTitle, r.key, r.character, r.lang, String(format: "%.2f", r.duration), r.tags.joined(separator: " "), r.text, r.audio ?? ""].map(q).joined(separator: ",") + "\n" }
                try csv.write(to: url, atomically: true, encoding: .utf8)
            }
        } catch { s.error = error.localizedDescription }
    }
}

struct LineRow: View {
    let r: LineRecord; let assign: () -> Void
    @ObservedObject var s = AppState.shared
    @State private var hover = false
    var body: some View {
        HStack(spacing: 10) {
            PlayButton(playing: s.playingPath == r.audio, enabled: r.audio != nil) { s.play(rel: r.audio) }
            VStack(alignment: .leading, spacing: 3) {
                Text(r.text.isEmpty ? "—" : "« " + r.text + " »").font(.system(size: 13)).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                HStack(spacing: 6) {
                    Text(r.character.isEmpty ? L.t("lines.unknown") : r.character).foregroundStyle(r.character.isEmpty ? Flat.warn : Flat.text2)
                    Text("· " + r.sourceTitle + " · " + String(format: "%.1f s", r.duration)).foregroundStyle(Flat.text2)
                    if !r.lang.isEmpty { Tag(title: r.lang.uppercased()) }
                    ForEach(r.tags, id: \.self) { Tag(title: L.t("tag." + $0)) }
                    if r.audio == nil { Tag(title: L.t("lines.textonly"), color: Flat.brand) }
                    ForEach(s.assignedNames(r), id: \.self) { Tag(title: "→ " + $0, color: Flat.ok) }
                }.font(.system(size: 11.5))
            }
            Spacer(minLength: 8)
            Button(L.t("lines.assign"), action: assign).buttonStyle(FlatButton(primary: hover, small: true))
        }
        .tile(hovered: hover).onHover { hover = $0 }
    }
}

/// Feuille « Attribuer à un personnage » : projet, personnage, mode (inspiration ou texte d'origine), texte à dire.
struct AssignSheet: View {
    let r: LineRecord
    @ObservedObject var s = AppState.shared
    @Environment(\.dismiss) private var dismiss
    @State private var pid: String?
    @State private var cid: String?
    @State private var mode = "inspiration"
    @State private var say = ""
    var project: Project? { s.projects.first { $0.id == pid } }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Header(title: L.t("lines.assign.title"))
            Text("« " + r.text + " »").font(.system(size: 13)).foregroundStyle(Flat.text2).fixedSize(horizontal: false, vertical: true)
            if s.projects.isEmpty { Text(L.t("lines.noproject")).foregroundStyle(Flat.warn) } else {
                Picker(L.t("lines.project"), selection: $pid) { ForEach(s.projects) { Text($0.name).tag(Optional($0.id)) } }
                Picker(L.t("lines.character"), selection: $cid) {
                    ForEach(project?.characters ?? []) { c in Text(c.name + (c.voiceID.flatMap { id in s.voices.first { $0.id == id }?.name }.map { "  ·  " + $0 } ?? "")).tag(Optional(c.id)) }
                }
                Picker("", selection: $mode) { Text(L.t("lines.mode.insp")).tag("inspiration"); Text(L.t("lines.mode.orig")).tag("original") }.pickerStyle(.segmented).labelsHidden()
                Text(L.t("lines.mode.note")).font(.system(size: 11.5)).foregroundStyle(Flat.text2).fixedSize(horizontal: false, vertical: true)
                if mode == "inspiration" {
                    Text(L.t("lines.say")).font(.system(size: 12)).foregroundStyle(Flat.sub)
                    TextField("", text: $say, axis: .vertical).lineLimit(2...6).flatField()
                }
            }
            HStack { Spacer()
                Button(L.t("btn.cancel")) { dismiss() }.buttonStyle(FlatButton())
                Button(L.t("lines.do")) {
                    if let pid, let cid { s.assign(r, project: pid, character: cid, mode: mode, text: mode == "inspiration" ? say : nil) }
                    dismiss()
                }.buttonStyle(FlatButton(primary: true)).disabled(pid == nil || cid == nil)
            }
        }
        .padding(18).frame(width: 460)
        .onAppear {
            pid = s.projectID ?? s.projects.first?.id
            cid = (s.project?.id == pid ? s.characterID : nil) ?? project?.characters.first?.id
            say = r.text
        }
        .onChange(of: pid) { _, _ in if !(project?.characters.contains { $0.id == cid } ?? false) { cid = project?.characters.first?.id } }
    }
}

/// Carte « Répliques attribuées » de la fiche du personnage (écran E de la maquette).
struct AssignedCard: View {
    let c: Character
    @ObservedObject var s = AppState.shared
    var voice: Voice? { s.voices.first { $0.id == c.voiceID } }
    var body: some View {
        Card(pad: 14, tint: Flat.peach) { VStack(alignment: .leading, spacing: 8) {
            HStack { Header(title: L.t("char.assigned.title")); Tag(title: "\(c.assigned?.count ?? 0)"); Spacer(minLength: 0) }
            let list = c.assigned ?? []
            if list.isEmpty { Text(L.t("char.assigned.none")).font(.system(size: 13)).foregroundStyle(Flat.sub) }
            ForEach(Array(list.enumerated()), id: \.element.id) { i, a in
                HStack(alignment: .top, spacing: 10) {
                    PlayButton(playing: s.playingPath == a.audio, enabled: a.audio.map { FileManager.default.fileExists(atPath: $0) } ?? false) { s.play(rel: a.audio) }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(a.text).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                        HStack(spacing: 6) {
                            if a.mode == "inspiration", let o = a.original, o != a.text { Text(L.t("char.assigned.from", o)).italic().lineLimit(1) }
                            Text([a.speaker, a.source].compactMap { $0 }.joined(separator: " · ")).lineLimit(1)
                        }.font(.system(size: 11.5)).foregroundStyle(Flat.sub)
                        Tag(title: a.mode == "original" ? L.t("lines.mode.orig") : L.t("lines.mode.insp"), color: a.mode == "original" ? Flat.brand : nil)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 4) {
                        Button(L.t("char.lines.try")) { if let v = voice { s.preview(voice: v, text: a.text, style: a.emotion ?? c.style, fx: CreatureFX.find(c.fx, for: c)) } }
                            .buttonStyle(FlatButton(small: true)).disabled(voice == nil || s.busy || !s.engineInstalled).help(voice == nil ? L.t("char.pickvoice") : "")
                        Button(L.t("char.assigned.remove")) { s.update(character: c.id) { $0.assigned?.removeAll { $0.id == a.id } } }.buttonStyle(FlatButton(small: true))
                    }
                }
                if i < list.count - 1 { Divider().overlay(Flat.sep) }
            }
            Button(L.t("char.assigned.search")) { s.screen = .lines }.buttonStyle(FlatButton(small: true))
        } }
    }
}
