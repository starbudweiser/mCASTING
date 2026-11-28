import SwiftUI

// Écran Casting, version « lisible » : moins de texte répété, moins de blanc, boutons au survol.
// Deux présentations des voix au choix (commutateur de la barre de filtres) : liste calme ou cartes allégées.

enum VoiceLayout: String { case list, cards }

/// Une voix dans le Casting, en ligne (liste) ou en carte allégée.
/// Ne se redessine que si ses propres données changent (voir `CardInfo`).
struct CastingVoiceItem: View, Equatable {
    let v: Voice; let info: CardInfo; let layout: VoiceLayout
    nonisolated static func == (a: CastingVoiceItem, b: CastingVoiceItem) -> Bool { a.v == b.v && a.info == b.info && a.layout == b.layout }
    private var s: AppState { .shared }
    @State private var pick: Lang?
    @State private var free = false
    @State private var hover = false
    var lang: Lang { pick ?? info.defaultLang }
    var rel: String? { v.samples[lang.rawValue] }
    var playing: Bool { rel.map { info.playingPath?.hasSuffix($0) == true } ?? (info.playingPath?.contains("/cache/\(v.id).\(lang.rawValue).") == true) }
    /// Langues du projet encore à calculer : seules signalées (en orange), les langues prêtes ne sont plus écrites.
    var missing: [Lang] { v.custom ? [] : info.projectLangs.filter { v.samples[$0.rawValue] == nil } }

    var body: some View {
        Group { if layout == .list { row } else { card } }
            .contentShape(Rectangle())
            .onHover { hover = $0 }
            .popover(isPresented: $free) { FreeTextPopover(v: v, lang: lang, shown: $free) }
    }

    // MARK: présentations
    var row: some View {
        HStack(spacing: 12) {
            play
            name.frame(width: 160, alignment: .leading)
            wave.frame(width: 110)
            // Les outils n'apparaissent qu'au survol, dans la place de la description (qui se raccourcit) : la ligne garde sa largeur.
            HStack(spacing: 8) { desc.frame(maxWidth: .infinity, alignment: .leading); if hover || info.isB { tools } }
                .frame(minWidth: 0, maxWidth: .infinity)
            star
            choose
        }
        .padding(.horizontal, 12).frame(height: 42)
        .background(info.chosen ? Flat.ok.opacity(0.07) : hover ? Flat.ctl.opacity(0.45) : Color.clear)
        .overlay(alignment: .leading) { if info.chosen { RoundedRectangle(cornerRadius: 1.5).fill(Flat.ok).frame(width: 3).padding(.vertical, 9) } }
    }
    var card: some View {
        HStack(spacing: 10) {
            play
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) { name.layoutPriority(2); desc }
                wave
            }.frame(maxWidth: .infinity, alignment: .leading)
            if hover || info.isB { tools }
            star
            choose
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(info.chosen ? Flat.ok.opacity(0.06) : hover ? Flat.ctl.opacity(0.55) : Flat.card))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(info.chosen ? Flat.ok.opacity(0.45) : info.isB ? Flat.acc : Flat.line, lineWidth: 1))
    }

    // MARK: éléments
    var play: some View {
        PlayButton(playing: playing, enabled: rel != nil || (info.canListen && !v.samples.isEmpty)) { if playing { s.play(rel: s.playingPath) } else { s.listen(voice: v, lang: lang) } }
    }
    var wave: some View {
        Wave(seed: Double(v.id.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 97 }) / 7, bars: 30, playing: playing).opacity(playing ? 1 : 0.45)
    }
    var name: some View {
        HStack(spacing: 6) {
            Text(v.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(hover ? Flat.brand : Flat.text).rowName(v.name)
            if info.chosen { Text(L.t("lib.chosen").replacingOccurrences(of: " ✓", with: "").uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(Flat.ok).fixedSize() }
            if info.isB { Tag(title: "B", solid: true) }
            if v.custom { Text("clone").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Flat.brand.opacity(0.8)).fixedSize() }
        }
    }
    var desc: some View {
        let miss = missing.map { $0.rawValue.uppercased() + "…" }.joined(separator: " ")
        return (Text(v.tone).foregroundStyle(Flat.text3) + Text(miss.isEmpty ? "" : "  " + miss).foregroundStyle(Flat.warn))
            .font(.system(size: 12)).lineLimit(1).truncationMode(.tail)
            .help(miss.isEmpty ? v.tone : v.tone + " — " + L.t("lang.tag.missing"))
    }
    /// Outils secondaires, visibles au survol : langue d'écoute, réplique du personnage, comparaison A / B.
    var tools: some View {
        HStack(spacing: 6) {
            ListenLangMenu(v: v, lang: Binding(get: { lang }, set: { pick = $0 }), onPick: { s.listen(voice: v, lang: $0) }, onFreeText: { free = true })
            LineMenu(v: v, lang: lang)
            if info.isB { Button(L.t("ab.cancel")) { s.abVoiceID = nil }.buttonStyle(FlatButton(small: true)) }
            else if !info.chosen { Button(L.t("lib.ab")) { s.abVoiceID = v.id }.buttonStyle(FlatButton(small: true)) }
        }.fixedSize()
    }
    var star: some View {
        Button { s.toggleFavorite(v.id) } label: {
            Image(systemName: info.fav ? "star.fill" : "star").font(.system(size: 12)).foregroundStyle(info.fav ? Flat.brand : Flat.text3).frame(width: 20, height: 22).contentShape(Rectangle())
        }.buttonStyle(.plain).help(L.t(info.fav ? "fav.remove" : "fav.add"))
    }
    var choose: some View {
        Button(info.chosen ? L.t("lib.chosen") : L.t("lib.choose")) { s.choose(voice: v.id) }
            .buttonStyle(ChooseStyle(chosen: info.chosen, hot: hover)).disabled(!info.hasCharacter)
    }
}

/// Bouton « Choisir » discret : contour au repos, bleu au survol de la voix, vert une fois choisie.
struct ChooseStyle: ButtonStyle {
    let chosen: Bool; let hot: Bool
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration c: Configuration) -> some View {
        c.label.font(.system(size: 11.5, weight: .medium)).lineLimit(1).fixedSize()
            .padding(.horizontal, 10).padding(.vertical, 3)
            .foregroundStyle(chosen ? Flat.ok : hot ? Color.white : Flat.text2)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(chosen ? Flat.ok.opacity(0.16) : hot ? Flat.acc : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(chosen || hot ? Color.clear : Flat.line, lineWidth: 1))
            .opacity(enabled ? (c.isPressed ? 0.8 : 1) : 0.4)
    }
}

/// Barre de filtres sur une ligne : recherche, menus déroulants (un filtre actif se colore), favoris, clonées,
/// nombre de voix et commutateur liste / cartes. Passe sur deux lignes si la place manque.
struct FilterBar: View {
    @ObservedObject var s = AppState.shared
    @Binding var layout: String
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { search.frame(minWidth: 160, maxWidth: .infinity); filters; trailing }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) { search.frame(maxWidth: .infinity); trailing }
                Flow(spacing: 6) { filters }
            }
        }
        .padding(7).frame(maxWidth: .infinity, alignment: .leading)
        .background(Flat.card, in: RoundedRectangle(cornerRadius: Flat.rb, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Flat.rb, style: .continuous).strokeBorder(Flat.line, lineWidth: 1))
    }
    var search: some View {
        HStack(spacing: 6) { Image(systemName: "magnifyingglass").foregroundStyle(Flat.text3); TextField(L.t("lib.search.short"), text: $s.fText).textFieldStyle(.plain) }
            .font(.system(size: 12.5)).padding(.horizontal, 10).padding(.vertical, 6)
            .background(Flat.bg, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
    }
    @ViewBuilder var filters: some View {
        menu(L.t("f.gender"), s.fGender.map { L.t("g.\($0.rawValue)") }) {
            Button(L.t("lib.all")) { s.fGender = nil }
            ForEach(Gender.allCases, id: \.self) { g in Button(L.t("g.\(g.rawValue)")) { s.fGender = g } }
        }
        let ages = [("young", "age.young"), ("adult", "age.adult"), ("senior", "age.senior")]
        menu(L.t("f.age"), ages.first { $0.0 == s.fAge }.map { L.t($0.1) }) {
            Button(L.t("lib.all")) { s.fAge = nil }
            ForEach(ages, id: \.0) { a in Button(L.t(a.1)) { s.fAge = a.0 } }
        }
        let tones = [("low", "tone.low"), ("high", "tone.high"), ("warm", "tone.warm"), ("dry", "tone.dry"), ("mischievous", "tone.dark")]
        menu(L.t("f.tone"), tones.first { $0.0 == s.fTone }.map { L.t($0.1) }) {
            Button(L.t("lib.all")) { s.fTone = nil }
            ForEach(tones, id: \.0) { t in Button(L.t(t.1)) { s.fTone = t.0 } }
        }
        menu(L.t("f.lang"), s.fLang?.rawValue.uppercased()) {
            Button(L.t("lang.all")) { s.fLang = nil }
            ForEach(s.project?.languages ?? []) { l in Button(l.rawValue.uppercased()) { s.fLang = l } }
        }
        toggle("★", s.fFav, help: L.t("f.fav")) { s.fFav.toggle() }
        toggle(L.t("f.clone"), s.fClone) { s.fClone.toggle(); if !s.fClone { s.fSource = nil } }
        let srcs = Array(Set(s.voices.filter(\.isClone).compactMap(\.originTitle))).sorted()
        if s.fClone, !srcs.isEmpty {
            menu(L.t("clones.source"), s.fSource) {
                Button(L.t("clones.all.f")) { s.fSource = nil }
                ForEach(srcs, id: \.self) { t in Button(t) { s.fSource = t } }
            }
        }
    }
    var trailing: some View {
        HStack(spacing: 6) {
            Text(L.t("lib.count", s.filteredVoices.count)).font(.system(size: 11.5)).foregroundStyle(Flat.text3).fixedSize().monospacedDigit()
            HStack(spacing: 2) {
                layoutButton("list", "list.bullet", L.t("layout.list"))
                layoutButton("cards", "square.grid.2x2", L.t("layout.cards"))
            }.padding(2).background(Flat.ctl, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
        }
    }
    func layoutButton(_ id: String, _ icon: String, _ help: String) -> some View {
        Button { layout = id } label: {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).frame(width: 26, height: 20)
                .foregroundStyle(layout == id ? Flat.onAcc : Flat.text2)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(layout == id ? Flat.acc : Color.clear))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).help(help)
    }
    func menu<C: View>(_ title: String, _ value: String?, @ViewBuilder _ items: () -> C) -> some View {
        Menu { items() } label: {
            HStack(spacing: 4) {
                Text(title).foregroundStyle(value == nil ? Flat.text2 : Flat.acc)
                if let value { Text(value).fontWeight(.medium).foregroundStyle(Flat.text) }
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)).foregroundStyle(Flat.text3)
            }
            .font(.system(size: 12)).lineLimit(1).padding(.horizontal, 9).padding(.vertical, 5)
            .background(value == nil ? Flat.ctl : Flat.acc.opacity(0.18), in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
        }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
    }
    func toggle(_ title: String, _ on: Bool, help: String? = nil, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(title).font(.system(size: 12, weight: on ? .medium : .regular)).lineLimit(1).fixedSize()
                .foregroundStyle(on ? Flat.acc : Flat.text2).padding(.horizontal, 9).padding(.vertical, 5)
                .background(on ? Flat.acc.opacity(0.18) : Flat.ctl, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
        }.buttonStyle(.plain).help(help ?? title)
    }
}

/// Fiche du personnage pendant le choix d'une voix, en une seule bande : qui, voix actuelle, jeu, réplique.
struct CompactStrip: View {
    let c: Character
    @ObservedObject var s = AppState.shared
    @State private var custom = false
    @State private var text = ""
    var known: Bool { TrialBox.emotions.contains { $0.1 == c.style } }
    var body: some View {
        Card(pad: 10, tint: Flat.sky) { VStack(alignment: .leading, spacing: 8) {
            Flow(spacing: 16, rowHeight: 30) {
                HStack(spacing: 10) {
                    Avatar(letter: String(c.name.prefix(1)), size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(c.name).font(.system(size: 14, weight: .semibold)).rowName(c.name)
                        Text(c.role.isEmpty ? "—" : c.role).font(.system(size: 12)).foregroundStyle(Flat.sub).rowName(c.role)
                    }.frame(maxWidth: 300, alignment: .leading)
                }
                if let cur = c.current, !cur.samples.isEmpty {
                    HStack(spacing: 6) {
                        Header(title: L.t("char.current")).fixedSize()
                        ForEach(Array(cur.samples.prefix(3).enumerated()), id: \.offset) { i, smp in
                            Button { s.play(rel: smp.file) } label: { HStack(spacing: 5) { Image(systemName: s.playingPath == smp.file ? "stop.fill" : "play.fill").font(.system(size: 9)); Text(L.t("char.extract", i + 1)) } }
                                .buttonStyle(FlatButton(primary: true, small: true)).disabled(!FileManager.default.fileExists(atPath: smp.file)).help(smp.text ?? "")
                        }
                    }
                }
                HStack(spacing: 5) {
                    Header(title: L.t("char.interp")).fixedSize()
                    ForEach(TrialBox.emotions, id: \.0) { e in Button { custom = false; set(e.1) } label: { Chip(title: L.t(e.0), on: !custom && c.style == e.1) }.buttonStyle(.plain) }
                    Button { custom.toggle() } label: { Chip(title: L.t("emo.custom"), on: custom || !known) }.buttonStyle(.plain)
                }.opacity(s.expressive ? 1 : 0.45)
                HStack(spacing: 5) {
                    Button { s.expressive = false } label: { Chip(title: L.t("rep.faithful"), on: !s.expressive) }.buttonStyle(.plain).help(L.t("rep.hint.f"))
                    Button { s.expressive = true } label: { Chip(title: L.t("rep.expressive"), on: s.expressive) }.buttonStyle(.plain).help(L.t("rep.hint.e"))
                }
            }
            if custom || !known { TextField(L.t("char.style"), text: $text).flatField().onChange(of: text) { _, v in set(v) } }
        } }
        .onAppear { text = c.style; custom = !known }
        .onChange(of: c.id) { _, _ in text = c.style; custom = !known }
    }
    func set(_ v: String) { s.update(character: c.id) { $0.style = v } }
}
