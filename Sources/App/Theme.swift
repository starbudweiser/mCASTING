// mCASTING — Flat Mat Design, à l'identique de la maquette validée (maquettes/maquettes-flatmat.html) :
// beige chaud en clair, sombre commun Socle, filets de 1 px, rayons 12 / 8, boutons et pastilles de la maquette.
import SwiftUI
import AppKit

enum Flat {
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color { Color(nsColor: dynNS(light, dark)) }
    /// Couleur à transparence (clair, sombre) : sert aux éléments « ton sur ton » posés sur un panneau coloré.
    static func dynA(_ light: UInt32, _ la: CGFloat, _ dark: UInt32, _ da: CGFloat) -> Color {
        Color(nsColor: NSColor(name: nil) { a in
            let dk = a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua, v = dk ? dark : light
            return NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: dk ? da : la)
        })
    }
    static func dynNS(_ light: UInt32, _ dark: UInt32) -> NSColor {
        NSColor(name: nil) { a in
            let v = a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
        }
    }
    static let bgNS = dynNS(0xf4f1ec, 0x131316)
    static let bg = Color(nsColor: bgNS)
    static let card = dyn(0xffffff, 0x232327)
    static let ctl = dyn(0xebe6de, 0x2c2c31)
    static let text = dyn(0x26231e, 0xf5f5f7), text2 = dyn(0x7b756a, 0x98989f)
    static let line = dyn(0xe3ddd2, 0x303035)
    static let acc = dyn(0x26231e, 0x0a84ff), onAcc = dyn(0xf4f1ec, 0xffffff)
    static let brand = dyn(0xd9622b, 0xf08a52)
    static let ok = dyn(0x3f8f5a, 0x30d158), warn = dyn(0xb7791f, 0xff9f0a)
    static let go = dyn(0x3f8f5a, 0x2f7d52)              // vert des boutons de création (plus doux que le vert d'état)
    static let avatar = dyn(0x26231e, 0x2c2c31)
    static let rb: CGFloat = 12, rc: CGFloat = 8
    /// Hauteur commune des barres du bas (bouton large, état du calcul) pour qu'elles s'alignent d'une colonne à l'autre.
    static let barH: CGFloat = 40
    /// Fonds pastel des panneaux de l'écran Casting (thème clair : pastel ; thème sombre : même teinte, assombrie).
    static let peach = dyn(0xfbe7dc, 0x45301f), sky = dyn(0xccc8c0, 0x1d3350), mint = dyn(0xe3e0da, 0x1c3f2d),
               lavender = dyn(0xe3e0da, 0x36285a), butter = dyn(0xccc8c0, 0x423a1c), rose = dyn(0xf8e2e7, 0x472433),
               prune = dyn(0xe3e0da, 0x3e2440)
    /// Éléments posés sur un panneau coloré (« ton sur ton », maquettes/contrastes-panneaux.html) : ils prennent la teinte
    /// du panneau, éclaircie ou creusée, et la sélection est le seul élément très contrasté.
    static let tChip = dynA(0xffffff, 0.65, 0xffffff, 0.09), tChipText = dynA(0x26231e, 1, 0xffffff, 0.88)
    static let tSel = dynA(0x26231e, 1, 0xffffff, 0.94), tSelText = dynA(0xffffff, 1, 0x15151a, 1)
    static let tField = dynA(0xffffff, 0.75, 0x000000, 0.22), tFieldEdge = dynA(0x000000, 0.06, 0xffffff, 0.06)
    static let tSub = dynA(0x1d1b18, 0.66, 0xffffff, 0.68), tHead = dynA(0x1d1b18, 0.55, 0xffffff, 0.55)
    static let tSep = dynA(0x000000, 0.08, 0xffffff, 0.10), tEdge = dynA(0x000000, 0.06, 0xffffff, 0.06)
    static let tAvatar = dynA(0x000000, 0.72, 0x000000, 0.28)
    /// Couleurs qui suivent le panneau : neutres hors panneau coloré, « ton sur ton » dedans.
    static let sub = Tone.sub, head = Tone.head, sep = Tone.sep, field = Tone.field, fieldEdge = Tone.fieldEdge, chip = Tone.chip
}

/// Vrai à l'intérieur d'un panneau coloré (Card avec `tint`).
private struct OnTintKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues { var onTint: Bool { get { self[OnTintKey.self] } set { self[OnTintKey.self] = newValue } } }

enum Tone: ShapeStyle {
    case sub, head, sep, field, fieldEdge, chip, avatar
    func resolve(in e: EnvironmentValues) -> Color {
        switch self {
        case .sub: return e.onTint ? Flat.tSub : Flat.text2
        case .head: return e.onTint ? Flat.tHead : Flat.text2
        case .sep: return e.onTint ? Flat.tSep : Flat.line
        case .field: return e.onTint ? Flat.tField : Flat.ctl
        case .fieldEdge: return e.onTint ? Flat.tFieldEdge : .clear
        case .chip: return e.onTint ? Flat.tChip : Flat.ctl
        case .avatar: return e.onTint ? Flat.tAvatar : Flat.avatar
        }
    }
}

/// Boîte de la maquette : fond carte, filet 1 px, rayon 12, marge 11.
struct Card<C: View>: View {
    var pad: CGFloat = 11
    var stretch = false          // prend la hauteur du voisin (deux cartes côte à côte de même hauteur)
    var tint: Color? = nil       // fond pastel propre au panneau (écran Casting)
    @ViewBuilder var content: C
    var body: some View {
        content.padding(pad).frame(maxWidth: .infinity, maxHeight: stretch ? .infinity : nil, alignment: .topLeading)
            .background(tint ?? Flat.card, in: RoundedRectangle(cornerRadius: Flat.rb, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Flat.rb, style: .continuous).strokeBorder(tint == nil ? Flat.line : Flat.tEdge, lineWidth: 1))
            .environment(\.onTint, tint != nil)
    }
}
extension View {
    /// Ligne / tuile de la maquette (`.chr`, `.v`, `.pc`) : marges réglables, contour optionnel (plein ou pointillé).
    /// `selected` : teinte d'accent (ou `tint`, par exemple vert pour la voix choisie) ; `hovered` : léger éclaircissement au survol.
    func tile(pad: EdgeInsets = EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10), outline: Color? = nil, dashed: Bool = false, selected: Bool = false, hovered: Bool = false, tint: Color? = nil) -> some View {
        padding(pad)
            .background { ZStack {
                RoundedRectangle(cornerRadius: Flat.rb, style: .continuous).fill(Flat.card)
                RoundedRectangle(cornerRadius: Flat.rb, style: .continuous).fill(selected ? (tint ?? Flat.acc).opacity(0.24) : .clear)
                RoundedRectangle(cornerRadius: Flat.rb, style: .continuous).fill(hovered ? Flat.text.opacity(selected ? 0.04 : 0.07) : .clear)
            }.animation(.easeOut(duration: 0.12), value: hovered) }
            .overlay(RoundedRectangle(cornerRadius: Flat.rb, style: .continuous).strokeBorder(Flat.line, lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: Flat.rb, style: .continuous).strokeBorder(outline ?? .clear, style: StrokeStyle(lineWidth: 2, dash: dashed ? [5, 4] : [])))
    }
    /// Tuile cliquable qui s'éclaircit au survol (lignes de personnages, cartes de projets).
    func hoverTile(pad: EdgeInsets = EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10), selected: Bool = false) -> some View {
        modifier(HoverTile(pad: pad, selected: selected))
    }
    /// Champ de la maquette (`.search`) : fond contrôle, rayon 8, marge 7 × 11.
    func flatField() -> some View {
        textFieldStyle(.plain).padding(.horizontal, 11).padding(.vertical, 7)
            .background(Flat.field, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Flat.rc, style: .continuous).strokeBorder(Flat.fieldEdge, lineWidth: 1))
    }
    func flatEditor(height: CGFloat) -> some View {
        scrollContentBackground(.hidden).padding(6).frame(height: height)
            .background(Flat.field, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Flat.rc, style: .continuous).strokeBorder(Flat.fieldEdge, lineWidth: 1))
    }
    /// Nom d'une ligne : une seule ligne, troncature en fin, infobulle.
    func rowName(_ full: String) -> some View { lineLimit(1).truncationMode(.tail).layoutPriority(1).help(full) }
}

/// Bouton `.btn` de la maquette : fond contrôle, rayon 8, marges 6 × 12, graisse 500 ; `primary` = accent ; `small` = 3 × 9.
struct FlatButton: ButtonStyle {
    var primary = false, small = false, green = false, wide = false
    func makeBody(configuration c: Configuration) -> some View { Inner(c: c, primary: primary, small: small, green: green, wide: wide) }
    private struct Inner: View {
        let c: Configuration; let primary: Bool, small: Bool, green: Bool, wide: Bool
        @State private var hover = false
        @Environment(\.isEnabled) private var enabled
        @Environment(\.onTint) private var onTint
        var body: some View {
            c.label.font(.system(size: small ? 11.5 : (wide ? 14 : 13), weight: wide ? .semibold : .medium)).lineLimit(1).fixedSize()
                .padding(.horizontal, small ? 9 : 12).padding(.vertical, small ? 3 : (wide ? 0 : 6))
                .frame(maxWidth: wide ? .infinity : nil, minHeight: wide ? Flat.barH : nil)
                .foregroundStyle(green ? Color.white : primary ? (onTint ? Flat.tSelText : Flat.onAcc) : (onTint ? Flat.tChipText : Flat.text))
                .background(RoundedRectangle(cornerRadius: Flat.rc, style: .continuous).fill(green ? Flat.go.opacity(hover ? 0.85 : 1)
                    : primary ? (onTint ? Flat.tSel : Flat.acc).opacity(hover ? 0.85 : 1)
                    : (onTint ? Flat.tChip : Flat.ctl).opacity(hover || c.isPressed ? 0.7 : 1)))
                .scaleEffect(c.isPressed ? 0.98 : 1).animation(.easeOut(duration: 0.1), value: c.isPressed)
                .opacity(enabled ? 1 : 0.4).onHover { hover = $0 }
        }
    }
}

/// `.chip` : pastille 4 × 10, 11,5 px ; active = accent.
struct Chip: View {
    let title: String; var on = false
    @Environment(\.onTint) private var onTint
    var body: some View {
        Text(title).font(.system(size: 11.5, weight: on ? .semibold : .regular)).lineLimit(1).fixedSize().padding(.horizontal, 10).padding(.vertical, 4)
            .foregroundStyle(on ? (onTint ? Flat.tSelText : Flat.onAcc) : (onTint ? Flat.tChipText : Flat.text))
            .background(Capsule().fill(on ? (onTint ? Flat.tSel : Flat.acc) : (onTint ? Flat.tChip : Flat.ctl)))
    }
}

/// `.tag` : 11 px / 600, pastille ; variantes ok, warn, accent.
struct Tag: View {
    let title: String; var color: Color? = nil; var solid = false
    var body: some View {
        let c = color ?? Flat.text2
        Text(title).font(.system(size: 11, weight: .semibold)).lineLimit(1).fixedSize().padding(.horizontal, 7).padding(.vertical, 2)
            .foregroundStyle(solid ? AnyShapeStyle(Flat.onAcc) : color == nil ? AnyShapeStyle(Flat.sub) : AnyShapeStyle(c))
            .background(Capsule().fill(solid ? AnyShapeStyle(Flat.acc) : color == nil ? AnyShapeStyle(Flat.chip) : AnyShapeStyle(c.opacity(0.22))))
    }
}

/// `.h` : 11 px / 600, capitales, interlettrage .04 em, secondaire.
struct Header: View {
    let title: String
    var body: some View { Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(0.44).foregroundStyle(Flat.head).lineLimit(1) }
}

/// Nom de l'appli avec son « m » orange (jamais dans un menu déroulant).
struct BrandName: View {
    var size: CGFloat = 15
    var body: some View { (Text("m").foregroundStyle(Flat.brand) + Text("CASTING").foregroundStyle(Flat.text)).font(.system(size: size, weight: .bold)) }
}

/// `.wave` : barres de 2,5 px, écart 1,5, hauteur 22 ; accent pendant la lecture.
/// Onde d'un extrait : elle remplit la largeur disponible, le nombre de barres suit la largeur (une barre tous les 4 pt).
struct Wave: View {
    var seed: Double; var bars = 34; var playing = false
    var body: some View {
        GeometryReader { g in
            let n = max(8, Int((g.size.width + 1.5) / 4))
            HStack(spacing: 1.5) {
                ForEach(0..<n, id: \.self) { i in
                    let h = 0.2 + abs(sin(Double(i) * 0.7 + seed) * cos(Double(i) * 0.31 + seed * 2)) * 0.8
                    RoundedRectangle(cornerRadius: 1.25).fill(playing ? Flat.acc : Flat.text2.opacity(0.65)).frame(width: 2.5, height: 22 * h)
                }
            }.frame(maxHeight: .infinity)
        }.frame(minWidth: CGFloat(min(bars, 20)) * 4, maxWidth: .infinity).frame(height: 22)
    }
}

/// `.play` : rond de 26 px, accent.
struct PlayButton: View {
    var playing = false; var enabled = true; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: playing ? "stop.fill" : "play.fill").font(.system(size: 10)).foregroundStyle(Flat.onAcc).frame(width: 26, height: 26).background(Circle().fill(Flat.acc))
        }.buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.4)
    }
}

/// Avatar `.av` : 34 px, rayon 8, initiale blanche.
struct Avatar: View {
    let letter: String; var size: CGFloat = 34
    var body: some View {
        Text(letter.uppercased()).font(.system(size: 13, weight: .bold)).foregroundStyle(.white).frame(width: size, height: size)
            .background(Tone.avatar, in: RoundedRectangle(cornerRadius: Flat.rc, style: .continuous))
    }
}

/// Rangée de puces qui passe à la ligne plutôt que de déborder.
struct Flow: Layout {
    var spacing: CGFloat = 5
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { layout(proposal.width ?? 300, subviews).size }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = layout(b.width, subviews)
        for (i, f) in r.frames.enumerated() { subviews[i].place(at: CGPoint(x: b.minX + f.minX, y: b.minY + f.minY), proposal: .unspecified) }
    }
    private func layout(_ w: CGFloat, _ subs: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxW: CGFloat = 0, frames: [CGRect] = []
        for s in subs {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0, x + sz.width > w { x = 0; y += rowH + spacing; rowH = 0 }
            frames.append(CGRect(x: x, y: y, width: sz.width, height: sz.height))
            x += sz.width + spacing; rowH = max(rowH, sz.height); maxW = max(maxW, x - spacing)
        }
        return (CGSize(width: min(maxW, w), height: y + rowH), frames)
    }
}

struct HoverTile: ViewModifier {
    let pad: EdgeInsets; let selected: Bool
    @State private var hover = false
    func body(content: Content) -> some View { content.tile(pad: pad, selected: selected, hovered: hover).onHover { hover = $0 } }
}
