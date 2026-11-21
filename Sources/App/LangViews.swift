// mCASTING 2.0 — langues des voix dans l'interface : choix des 2 langues d'un projet, menu « Écouter en », langues de la bibliothèque.
import SwiftUI

/// Nom d'une langue pour une puce : nom natif, et nom traduit en infobulle.
private func chipTitle(_ l: Lang) -> String { l.native }

/// Choix des langues d'un projet : principale + secondaire facultative, parmi les langues de la bibliothèque.
struct LangPairPicker: View {
    @Binding var main: Lang
    @Binding var second: Lang?
    var showEstimate = true
    @ObservedObject var s = AppState.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                box(L.t("lang.main"), main.native, main.localized) {
                    ForEach(Languages.library) { l in Button { main = l; if second == l { second = nil } } label: { Chip(title: chipTitle(l), on: main == l) }.buttonStyle(.plain).help(l.localized) }
                }
                box(L.t("lang.second"), second?.native ?? L.t("lang.none"), second?.localized ?? "") {
                    ForEach(Languages.library) { l in
                        Button { second = l } label: { Chip(title: chipTitle(l), on: second == l) }.buttonStyle(.plain).disabled(l == main).opacity(l == main ? 0.4 : 1).help(l.localized)
                    }
                    Button { second = nil } label: { Chip(title: L.t("lang.none"), on: second == nil) }.buttonStyle(.plain)
                }
            }
            Text(L.t("lang.engine.note", Languages.library.count)).font(.system(size: 11.5)).foregroundStyle(Flat.sub).fixedSize(horizontal: false, vertical: true)
            if showEstimate { LangEstimate(langs: [main] + (second.map { [$0] } ?? [])) }
        }
    }
    func box<C: View>(_ title: String, _ value: String, _ sub: String, @ViewBuilder _ chips: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) { Text(title + " · " + value).font(.system(size: 13, weight: .bold)).lineLimit(1); Spacer(minLength: 4)
                if sub != value { Text(sub).font(.system(size: 11.5)).foregroundStyle(Flat.sub).lineLimit(1) } }
            Flow { chips() }
        }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Flat.field, in: RoundedRectangle(cornerRadius: Flat.rb, style: .continuous))
    }
}

/// Ce qui est déjà prêt et ce qui reste à calculer pour des langues (une langue déjà calculée n'est jamais refaite).
struct LangEstimate: View {
    let langs: [Lang]
    @ObservedObject var s = AppState.shared
    var body: some View {
        let n = s.libVoices.count
        let parts = langs.map { l -> String in
            let r = LibraryGenerator.ready(s.voices, l)
            return r >= n ? L.t("lang.est.ready", l.native, n) : L.t("lang.est.todo", l.native, n - r)
        }
        let left = langs.reduce(0) { $0 + max(n - LibraryGenerator.ready(s.voices, $1), 0) }
        let secs = Int(Double(left) * s.avg)
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "timer").foregroundStyle(Flat.sub)
            VStack(alignment: .leading, spacing: 2) {
                Text(L.t("lang.est.title", n)).font(.system(size: 13, weight: .semibold))
                Text(parts.joined(separator: " · ") + (left > 0 ? " " + L.t("lang.est.time", secs >= 3600 ? "\(secs / 3600) h \(String(format: "%02d", secs % 3600 / 60))" : "\(max(secs / 60, 1)) min") : ""))
                    .font(.system(size: 11.5)).foregroundStyle(Flat.sub).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }.padding(10).background(Flat.field, in: RoundedRectangle(cornerRadius: Flat.rb, style: .continuous))
    }
}

/// Fenêtre « Langues du projet » (barre latérale) : change les langues du projet affiché.
struct ProjectLangsSheet: View {
    @Binding var shown: Bool
    @ObservedObject var s = AppState.shared
    @State private var main: Lang = .fr
    @State private var second: Lang?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t("lang.sheet.title")).font(.system(size: 15, weight: .semibold))
            Text(L.t("lang.sheet.sub")).font(.system(size: 12)).foregroundStyle(Flat.sub).fixedSize(horizontal: false, vertical: true)
            LangPairPicker(main: $main, second: $second)
            HStack { Spacer(); Button(L.t("btn.cancel")) { shown = false }.buttonStyle(FlatButton())
                Button(L.t("lang.apply")) { s.setLanguages([main] + (second.map { [$0] } ?? [])); shown = false }.buttonStyle(FlatButton(primary: true)) }
        }.padding(20).frame(width: 620).background(Flat.bg).foregroundStyle(Flat.text).tint(Flat.acc)
        .onAppear { let l = s.project?.languages ?? [.fr]; main = l[0]; second = l.count > 1 ? l[1] : nil }
    }
}

/// Langues du projet dans la barre latérale : langue écoutée en un clic, avancement du calcul, bouton pour les changer.
struct SidebarLangs: View {
    @ObservedObject var s = AppState.shared
    @State private var editing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Header(title: L.t("nav.lang")).padding(.horizontal, 11).padding(.top, 14)
            HStack(spacing: 5) {
                ForEach(s.project?.languages ?? []) { l in
                    Button { s.setActive(l) } label: { Chip(title: l.rawValue.uppercased(), on: s.activeLang == l) }.buttonStyle(.plain).help(l.localized)
                }
                Button { editing = true } label: { Chip(title: "＋") }.buttonStyle(.plain).help(L.t("lang.sheet.title")).accessibilityLabel(L.t("lang.sheet.title")).disabled(s.project == nil)
            }.padding(.horizontal, 6)
            let n = s.libVoices.count
            ForEach((s.project?.languages ?? []).filter { LibraryGenerator.ready(s.voices, $0) < n }) { l in
                Text(L.t("lang.side.progress", l.rawValue.uppercased(), LibraryGenerator.ready(s.voices, l), n)).font(.system(size: 11)).foregroundStyle(Flat.text2).padding(.horizontal, 11)
            }
        }
        .sheet(isPresented: $editing) { ProjectLangsSheet(shown: $editing) }
    }
}

/// Menu « Écouter en » d'une voix : langues du projet (extraits prêts) puis toutes les autres langues que sait dire un modèle
/// installé, avec le même timbre (calcul à la demande, gardé en cache).
struct ListenLangMenu: View {
    let v: Voice
    @Binding var lang: Lang
    var onPick: (Lang) -> Void
    var onFreeText: () -> Void
    @ObservedObject var s = AppState.shared
    var body: some View {
        let proj = s.project?.languages ?? [s.activeLang]
        let others = Languages.listenable().filter { !proj.contains($0) }
        Menu {
            Section(L.t("lang.menu.project")) { ForEach(proj) { l in item(l) } }
            Section(L.t("lang.menu.others")) { ForEach(others) { l in item(l) } }
            Divider()
            Button(L.t("lang.menu.free") + "…") { onFreeText() }
            Divider()
            Text("ⓘ " + L.t("lang.accent"))
        } label: {
            HStack(spacing: 3) { Text(lang.rawValue.uppercased()).font(.system(size: 11.5, weight: .bold)); Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)) }
                .padding(.horizontal, 8).padding(.vertical, 4).foregroundStyle(Flat.text).background(Flat.ctl, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize().help(L.t("alt.listen", lang.localized))
    }
    func item(_ l: Lang) -> some View {
        let ready = v.samples[l.rawValue] != nil
        return Button { lang = l; onPick(l) } label: {
            Text("\(l.native)  —  \(ready ? L.t("lang.menu.ready") : L.t("lang.menu.clone"))") + Text(l == lang ? "  ✓" : "")
        }
    }
}

/// Saisie d'un texte libre à faire dire à une voix dans la langue choisie.
struct FreeTextPopover: View {
    let v: Voice; let lang: Lang
    @Binding var shown: Bool
    @State private var text = ""
    @ObservedObject var s = AppState.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t("lang.free.title", v.name, lang.native)).font(.system(size: 13, weight: .semibold))
            TextEditor(text: $text).font(.system(size: 12.5)).flatEditor(height: 70)
            Text("ⓘ " + L.t("lang.accent")).font(.system(size: 11)).foregroundStyle(Flat.sub).fixedSize(horizontal: false, vertical: true)
            HStack { Spacer(); Button(L.t("btn.cancel")) { shown = false }.buttonStyle(FlatButton())
                Button("▶ " + L.t("lib.try")) { s.listen(voice: v, lang: lang, text: text); shown = false }.buttonStyle(FlatButton(primary: true))
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || s.busy || !s.engineInstalled) }
        }.padding(14).frame(width: 340).background(Flat.bg)
        .onAppear { text = Catalog.sample(for: v, lang: lang) }
    }
}

/// Langues de la bibliothèque : extraits prêts par langue, qui s'en sert, pause, calcul complet ou libération d'une langue.
struct LibraryLangsCard: View {
    @ObservedObject var s = AppState.shared
    @State private var adding = false
    @State private var toPurge: Lang?
    var body: some View {
        let st = SetupState.load(), n = max(s.libVoices.count, 1)
        let cache = LibraryGenerator.cacheStats()
        let projLangs = Set(s.projects.flatMap(\.languages))
        let shown = Set(LibraryGenerator.targetLangs(projects: s.projects, setup: st))
            .union(Lang.allCases.filter { LibraryGenerator.ready(s.voices, $0) > 0 || cache[$0.rawValue] != nil }).sorted()
        Card { VStack(alignment: .leading, spacing: 8) {
            HStack { Header(title: L.t("lang.lib.title")); Spacer(minLength: 0)
                Menu { ForEach(Languages.library.filter { !shown.contains($0) }) { l in Button(l.native + " — " + l.localized) { s.addLibraryLang(l) } } } label: { Text("＋ " + L.t("lang.lib.add")) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().font(.system(size: 11.5, weight: .medium)) }
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                ForEach(shown) { l in
                    let r = LibraryGenerator.ready(s.voices, l), users = s.projects.filter { $0.languages.contains(l) }.map(\.name)
                    let paused = st.pausedLangs.contains(l.rawValue), inLib = Languages.library.contains(l)
                    GridRow {
                        HStack(spacing: 6) { Text(l.native).fontWeight(.semibold); Text(l.rawValue).font(.system(size: 11)).foregroundStyle(Flat.text2) }
                        Text("\(r) / \(s.libVoices.count)").monospacedDigit()
                        Bar2(value: Double(r) / Double(n)).frame(width: 140)
                        Text(users.isEmpty ? (cache[l.rawValue].map { L.t("lang.lib.cached", $0.count) } ?? "—") : users.joined(separator: ", "))
                            .font(.system(size: 11.5)).foregroundStyle(Flat.text2).lineLimit(1).truncationMode(.tail).frame(maxWidth: 220, alignment: .leading)
                        HStack(spacing: 6) {
                            if inLib && r < s.libVoices.count {
                                if users.isEmpty && !st.extraLangs.contains(l.rawValue) { Button(L.t("lang.lib.all")) { s.addLibraryLang(l) }.buttonStyle(FlatButton(primary: true, small: true)) }
                                else { Button(paused ? L.t("lang.lib.resume") : L.t("lang.lib.pause")) { s.togglePause(l) }.buttonStyle(FlatButton(small: true)) }
                            }
                            if !projLangs.contains(l) && (r > 0 || cache[l.rawValue] != nil) {
                                Button { toPurge = l } label: { Image(systemName: "xmark") }.buttonStyle(FlatButton(small: true)).help(L.t("lang.lib.purge")).accessibilityLabel(L.t("lang.lib.purge"))
                            }
                        }
                    }
                }
            }
            Text(L.t("lang.lib.note", L.t("gen.start"))).font(.system(size: 11.5)).foregroundStyle(Flat.text2).fixedSize(horizontal: false, vertical: true)
        } }
        .alert(L.t("lang.lib.purge.q", toPurge?.native ?? ""), isPresented: Binding(get: { toPurge != nil }, set: { if !$0 { toPurge = nil } })) {
            Button(L.t("btn.cancel"), role: .cancel) { toPurge = nil }
            Button(L.t("lang.lib.purge"), role: .destructive) { if let l = toPurge { s.purge(l) }; toPurge = nil }
        } message: { Text(L.t("lang.lib.purge.msg")) }
    }
}
