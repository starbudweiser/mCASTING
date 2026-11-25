// mCASTING — bibliothèque des voix clonées : classement par type de source (jeu, film, série), source, personnage, genre,
// langue, étiquettes et usage ; fiche modifiable (maquette validée : maquettes/voix-clonees.html).
import AVFoundation
import SwiftUI

struct ClonesView: View {
    @ObservedObject var s = AppState.shared
    @State private var text = ""
    @State private var kind: String?
    @State private var source: String?
    @State private var gender: Gender?
    @State private var lang: String?
    @State private var tags: Set<String> = []
    @State private var usage = 0                 // 0 toutes, 1 utilisées, 2 jamais utilisées
    @State private var group = 0                 // 0 source, 1 personnage, 2 aucun
    @State private var selID: String?

    static let kinds = ["game", "film", "series", "other"]
    var clones: [Voice] { s.voices.filter(\.isClone) }
    var used: [String: [String]] {
        var out: [String: [String]] = [:]
        for p in s.projects { for c in p.characters { if let v = c.voiceID { out[v, default: []].append("\(c.name) (\(p.name))") } } }
        return out
    }
    var shown: [Voice] {
        let q = text.lowercased(), u = used
        return clones.filter { v in
            (kind == nil || v.originKind == kind) && (source == nil || (v.originTitle ?? "") == source) &&
            (gender == nil || v.gender == gender) && (lang == nil || v.samples[lang!] != nil) &&
            tags.allSatisfy { (v.tags ?? []).contains($0) } &&
            (usage == 0 || (usage == 1) == (u[v.id] != nil)) &&
            (q.isEmpty || [v.name, v.character ?? "", v.originTitle ?? "", (v.tags ?? []).joined(separator: " ")].joined(separator: " ").lowercased().contains(q))
        }.sorted { ($0.originTitle ?? "~", $0.name) < ($1.originTitle ?? "~", $1.name) }
    }
    var groups: [(String, [Voice])] {
        let list = shown
        switch group {
        case 0: return Dictionary(grouping: list) { $0.originTitle ?? "" }.sorted { ($0.key.isEmpty ? "~" : $0.key) < ($1.key.isEmpty ? "~" : $1.key) }.map { ($0.key, $0.value) }
        case 1: return Dictionary(grouping: list) { $0.character ?? "" }.sorted { ($0.key.isEmpty ? "~" : $0.key) < ($1.key.isEmpty ? "~" : $1.key) }.map { ($0.key, $0.value) }
        default: return [("", list)]
        }
    }
    var sel: Voice? { s.voices.first { $0.id == selID && $0.isClone } ?? shown.first }

    var body: some View {
        Page {
            if clones.isEmpty { empty } else {
                HStack(alignment: .top, spacing: 12) {
                    ScrollView(showsIndicators: false) { filters }.frame(width: 220)
                    center.frame(maxWidth: .infinity)
                    if let v = sel { ScrollView(showsIndicators: false) { CloneSheet(v: v, uses: used[v.id] ?? []) }.frame(width: 300) }
                }
            }
        }
    }

    var empty: some View {
        Card(pad: 18) { VStack(alignment: .leading, spacing: 8) {
            Text(L.t("clones.empty")).font(.system(size: 15, weight: .semibold))
            Text(L.t("clones.empty.how")).foregroundStyle(Flat.text2).fixedSize(horizontal: false, vertical: true)
            Button(L.t("nav.clone.sub")) { s.screen = .clone }.buttonStyle(FlatButton(primary: true)).padding(.top, 4)
        } }.frame(maxWidth: 620)
    }

    // MARK: filtres (colonne gauche)
    var filters: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "magnifyingglass").foregroundStyle(Flat.text2); TextField(L.t("clones.search"), text: $text).textFieldStyle(.plain) }
                .padding(.horizontal, 11).padding(.vertical, 7).background(Flat.ctl, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
            Card { VStack(alignment: .leading, spacing: 6) {
                Header(title: L.t("clones.kind"))
                Flow(spacing: 5) {
                    chip(L.t("clones.all") + " · \(clones.count)", kind == nil) { kind = nil; source = nil }
                    ForEach(Self.kinds, id: \.self) { k in
                        let n = clones.filter { $0.originKind == k }.count
                        if n > 0 { chip(L.t("kind." + k) + " · \(n)", kind == k) { kind = kind == k ? nil : k; source = nil } }
                    }
                }
            } }
            Card { VStack(alignment: .leading, spacing: 2) {
                Header(title: L.t("clones.source"))
                facet(L.t("clones.all.f"), clones.filter { kind == nil || $0.originKind == kind }.count, source == nil) { source = nil }
                ForEach(sources, id: \.0) { t, n in facet(t, n, source == t) { source = source == t ? nil : t } }
                let none = clones.filter { $0.originTitle == nil && (kind == nil || $0.originKind == kind) }.count
                if none > 0 { facet(L.t("clones.nosource"), none, source == "") { source = source == "" ? nil : "" } }
            } }
            Card { VStack(alignment: .leading, spacing: 6) {
                Header(title: L.t("f.gender"))
                Flow(spacing: 5) {
                    chip(L.t("lib.all"), gender == nil) { gender = nil }
                    ForEach(Gender.allCases, id: \.self) { g in if clones.contains(where: { $0.gender == g }) { chip(L.t("g.\(g.rawValue)"), gender == g) { gender = gender == g ? nil : g } } }
                }
                Header(title: L.t("f.lang")).padding(.top, 4)
                Flow(spacing: 5) {
                    chip(L.t("lang.all"), lang == nil) { lang = nil }
                    ForEach(Array(Set(clones.flatMap { $0.samples.keys })).sorted(), id: \.self) { l in chip(l.uppercased(), lang == l) { lang = lang == l ? nil : l } }
                }
                let all = Array(Set(clones.flatMap { $0.tags ?? [] })).sorted()
                if !all.isEmpty {
                    Header(title: L.t("lines.f.tags")).padding(.top, 4)
                    Flow(spacing: 5) { ForEach(all, id: \.self) { t in chip(t, tags.contains(t)) { if tags.contains(t) { tags.remove(t) } else { tags.insert(t) } } } }
                }
                Header(title: L.t("clones.usage")).padding(.top, 4)
                Flow(spacing: 5) {
                    chip(L.t("lib.used"), usage == 1) { usage = usage == 1 ? 0 : 1 }
                    chip(L.t("lib.unused"), usage == 2) { usage = usage == 2 ? 0 : 2 }
                }
            } }
        }
    }
    var sources: [(String, Int)] {
        Dictionary(grouping: clones.filter { kind == nil || $0.originKind == kind }.compactMap(\.originTitle)) { $0 }.map { ($0.key, $0.value.count) }.sorted { $0.0 < $1.0 }
    }

    // MARK: liste (centre)
    var center: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Title(text: L.t("nav.clones")).fixedSize(); Tag(title: L.t("clones.count", shown.count))
                Spacer(minLength: 6)
                Button(L.t("nav.clone.sub")) { s.screen = .clone }.buttonStyle(FlatButton(small: true))
            }
            HStack(spacing: 6) {
                Text(L.t("clones.group")).font(.system(size: 12)).foregroundStyle(Flat.text2)
                chip(L.t("clones.source"), group == 0) { group = 0 }
                chip(L.t("clones.character"), group == 1) { group = 1 }
                chip(L.t("clones.nogroup"), group == 2) { group = 2 }
                Spacer(minLength: 0)
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(groups, id: \.0) { title, list in
                        if group != 2 {
                            HStack(spacing: 8) {
                                Text(title.isEmpty ? (group == 0 ? L.t("clones.nosource") : L.t("lines.unknown")) : title).font(.system(size: 13, weight: .semibold))
                                if group == 0, let k = list.first?.originKind, k != "none" { Tag(title: L.t("kind." + k), color: Self.color(k)) }
                                Tag(title: "\(list.count)")
                            }.padding(.top, 2)
                        }
                        VStack(spacing: 0) {
                            ForEach(Array(list.enumerated()), id: \.element.id) { i, v in
                                if i > 0 { Rectangle().fill(Flat.line).frame(height: 1) }
                                CloneRow(v: v, uses: used[v.id] ?? [], selected: sel?.id == v.id) { selID = v.id }
                            }
                        }
                        .background(Flat.card, in: RoundedRectangle(cornerRadius: Flat.rb, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: Flat.rb, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Flat.rb, style: .continuous).strokeBorder(Flat.line, lineWidth: 1))
                    }
                }
            }
        }
    }

    static func color(_ k: String) -> Color { k == "game" ? Color(red: 0.36, green: 0.5, blue: 0.75) : k == "film" ? Color(red: 0.7, green: 0.35, blue: 0.55) : k == "series" ? Color(red: 0.42, green: 0.6, blue: 0.3) : Flat.text2 }
    func chip(_ t: String, _ on: Bool, _ a: @escaping () -> Void) -> some View { Button(action: a) { Chip(title: t, on: on) }.buttonStyle(.plain) }
    func facet(_ t: String, _ n: Int, _ on: Bool, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            HStack { Text(t).lineLimit(1).fontWeight(on ? .semibold : .regular); Spacer(minLength: 6); Text("\(n)").foregroundStyle(Flat.text2).monospacedDigit() }
                .font(.system(size: 12)).padding(.horizontal, 6).padding(.vertical, 4).contentShape(Rectangle())
                .background(on ? Flat.ctl : .clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }.buttonStyle(.plain)
    }
}

/// Ligne de la liste des voix clonées : colonnes de largeur fixe (sauf nom et étiquettes) pour rester alignées d'un groupe à l'autre.
struct CloneRow: View {
    let v: Voice; let uses: [String]; let selected: Bool; let select: () -> Void
    @ObservedObject var s = AppState.shared
    @State private var hover = false
    var body: some View {
        let path = Paths.audio.appendingPathComponent(v.refAudio ?? "").path
        HStack(spacing: 10) {
            Avatar(letter: String((v.character ?? v.name).prefix(1)), size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(v.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(hover ? Flat.brand : Flat.text)
                    .animation(.easeOut(duration: 0.12), value: hover).rowName(v.name)
                Text(([v.character, L.t("g.\(v.gender.rawValue)")].compactMap { $0 } + [duration].compactMap { $0 }).joined(separator: " · "))
                    .font(.system(size: 11.5)).foregroundStyle(Flat.text2).lineLimit(1)
            }.frame(minWidth: 170, maxWidth: 260, alignment: .leading)
            HStack(spacing: 3) { ForEach(v.samples.keys.sorted(), id: \.self) { Tag(title: $0.uppercased()) } }.frame(width: 34, alignment: .leading)
            PlayButton(playing: s.playingPath == path) { s.play(rel: v.refAudio) }
            Wave(seed: Double(abs(v.id.hashValue % 97)), playing: s.playingPath == path).frame(minWidth: 90, maxWidth: .infinity)
            Group {
                let t = v.tags ?? []
                if t.isEmpty { Text("—").foregroundStyle(Flat.text2) }
                else {   // autant d'étiquettes entières que la place en permet, jamais une étiquette coupée
                    ViewThatFits(in: .horizontal) {
                        ForEach(Array(stride(from: min(t.count, 3), through: 1, by: -1)), id: \.self) { n in
                            HStack(spacing: 4) { ForEach(t.prefix(n), id: \.self) { Tag(title: $0) } }
                        }
                    }
                }
            }.frame(width: 170, alignment: .leading).help((v.tags ?? []).joined(separator: ", "))
            Group {
                if let u = uses.first {
                    Text("→ " + u.components(separatedBy: " (").first! + (uses.count > 1 ? " +\(uses.count - 1)" : ""))
                        .font(.system(size: 11, weight: .semibold)).lineLimit(1).truncationMode(.middle).padding(.horizontal, 7).padding(.vertical, 2)
                        .foregroundStyle(Flat.ok).background(Capsule().fill(Flat.ok.opacity(0.22))).help(uses.joined(separator: "\n"))
                } else { Tag(title: L.t("clones.unused")) }
            }.frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(selected ? Flat.acc.opacity(0.24) : (hover ? Flat.text.opacity(0.05) : .clear))
        .animation(.easeOut(duration: 0.12), value: hover)
        .onHover { hover = $0 }
        .contentShape(Rectangle()).onTapGesture(perform: select)
    }
    var duration: String? {
        guard let r = v.refAudio, let d = try? AVAudioPlayerShim.duration(Paths.audio.appendingPathComponent(r)) else { return nil }
        return String(format: "%.1f s", d)
    }
}

enum AVAudioPlayerShim {
    nonisolated(unsafe) static var cache: [String: Double] = [:]
    static func duration(_ u: URL) throws -> Double {
        if let d = cache[u.path] { return d }
        let f = try AVAudioFile(forReading: u); let d = Double(f.length) / f.processingFormat.sampleRate
        cache[u.path] = d; return d
    }
}

/// Fiche modifiable d'une voix clonée (colonne droite).
struct CloneSheet: View {
    let v: Voice; let uses: [String]
    @ObservedObject var s = AppState.shared
    @State private var name = ""
    @State private var character = ""
    @State private var title = ""
    @State private var newTag = ""
    @State private var line = ""
    @State private var askDelete = false
    var titles: [String] { Array(Set(s.voices.compactMap(\.originTitle))).sorted() }
    var body: some View {
        Card { VStack(alignment: .leading, spacing: 7) {
            Header(title: L.t("lib.sheet") + " · " + v.name)
            label(L.t("clone.name")); TextField("", text: $name).flatField().onSubmit(save)
            label(L.t("clones.character")); TextField(L.t("clones.character.ph"), text: $character).flatField().onSubmit(save)
            label(L.t("clones.source"))
            Flow(spacing: 5) { ForEach(ClonesView.kinds, id: \.self) { k in Button { edit { $0.sourceKind = k } } label: { Chip(title: L.t("kind." + k), on: v.sourceKind == k || (v.sourceKind == nil && v.originKind == k)) }.buttonStyle(.plain) } }
            HStack(spacing: 6) {
                TextField(L.t("clones.title.ph"), text: $title).flatField().onSubmit(save)
                if !titles.isEmpty {
                    Menu { ForEach(titles, id: \.self) { t in Button(t) { title = t; save() } } } label: { Image(systemName: "chevron.down") }.menuStyle(.borderlessButton).fixedSize()
                }
            }
            label(L.t("f.gender"))
            Flow(spacing: 5) { ForEach(Gender.allCases, id: \.self) { g in Button { edit { $0.gender = g } } label: { Chip(title: L.t("g.\(g.rawValue)"), on: v.gender == g) }.buttonStyle(.plain) } }
            label(L.t("lines.f.tags"))
            Flow(spacing: 5) {
                ForEach(v.tags ?? [], id: \.self) { t in Button { edit { $0.tags?.removeAll { $0 == t } } } label: { Chip(title: t + " ×", on: true) }.buttonStyle(.plain).help(L.t("char.assigned.remove")) }
                TextField(L.t("clones.tag.add"), text: $newTag).textFieldStyle(.plain).font(.system(size: 11.5)).frame(width: 110)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Flat.ctl))
                    .onSubmit { let t = newTag.trimmingCharacters(in: .whitespaces); if !t.isEmpty { edit { $0.tags = Array(Set(($0.tags ?? []) + [t])).sorted() } }; newTag = "" }
            }
            label(L.t("clones.reftext"))
            Text(v.refText ?? "—").font(.system(size: 11, design: .monospaced)).foregroundStyle(Flat.text2).lineLimit(5)
                .padding(8).frame(maxWidth: .infinity, alignment: .leading).background(Flat.ctl, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
            kv(L.t("clones.from"), [v.source?.components(separatedBy: " · ").first, v.added.map { $0.formatted(date: .numeric, time: .omitted) }].compactMap { $0 }.joined(separator: " · "))
            kv(L.t("lib.usedin"), uses.isEmpty ? "—" : uses.joined(separator: ", "))
            Header(title: L.t("lib.test")).padding(.top, 4)
            TextField("", text: $line, axis: .vertical).lineLimit(2...6).flatField()
            HStack {
                Button("▶ " + L.t("lib.try")) { s.preview(voice: v, text: line, style: "", lang: v.timbreLang) }.buttonStyle(FlatButton()).disabled(line.isEmpty || s.busy || !s.engineInstalled)
                Spacer(minLength: 6)
                if let c = s.character {
                    Button(L.t("clones.choose", c.name)) { s.choose(voice: v.id) }.buttonStyle(FlatButton(primary: true)).disabled(c.voiceID == v.id)
                }
            }
            Divider().padding(.vertical, 2)
            Button(role: .destructive) { askDelete = true } label: { Label(L.t("voice.delete"), systemImage: "trash") }.buttonStyle(FlatButton(small: true)).disabled(s.busy)
        } }
        .onAppear(perform: load).onChange(of: v.id) { _, _ in load() }
        .onDisappear(perform: save)
        .alert(L.t("voice.delete.q", v.name), isPresented: $askDelete) {
            Button(L.t("btn.cancel"), role: .cancel) {}
            Button(L.t("voice.delete"), role: .destructive) { s.deleteVoice(v.id) }
        } message: { Text(uses.isEmpty ? L.t("voice.delete.msg") : L.t("voice.delete.used", uses.joined(separator: ", ")) + " " + L.t("voice.delete.msg")) }
    }
    func load() { name = v.name; character = v.character ?? ""; title = v.originTitle ?? ""; line = Catalog.sample(for: v, lang: v.timbreLang) }
    /// Enregistre les champs texte modifiés (à la validation, au changement de voix ou en quittant l'écran).
    func save() {
        let n = name.trimmingCharacters(in: .whitespaces), c = character.trimmingCharacters(in: .whitespaces), t = title.trimmingCharacters(in: .whitespaces)
        guard n != v.name || c != (v.character ?? "") || t != (v.originTitle ?? "") else { return }
        edit { if !n.isEmpty { $0.name = n }; $0.character = c.isEmpty ? nil : c; $0.sourceTitle = t.isEmpty ? nil : t; if $0.sourceKind == nil, !t.isEmpty { $0.sourceKind = $0.originKind == "none" ? "other" : $0.originKind } }
    }
    func edit(_ f: @escaping (inout Voice) -> Void) { s.editVoice(v.id, f) }
    func label(_ t: String) -> some View { Text(t).font(.system(size: 11.5)).foregroundStyle(Flat.text2).padding(.top, 2) }
    func kv(_ k: String, _ val: String) -> some View { HStack(alignment: .top) { Text(k).foregroundStyle(Flat.text2); Spacer(minLength: 8); Text(val).multilineTextAlignment(.trailing) }.font(.system(size: 12)) }
}
