// mCASTING — casting de voix IA locales : bibliothèque, clonage, choix par projet, pilotable par un agent (MCP).
import SwiftUI

@main
struct McastingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @ObservedObject private var s = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            if let p = s.project { Text(L.t("menu.project", p.name, p.castCount, p.characters.count)) }
            if s.busy { Text(L.t("menu.busy", s.task)) }
            Divider()
            Button(L.t("menu.open")) { delegate.showMain() }
            Button(L.t("menu.setup")) { delegate.showMain(); SetupModel.shared.start(quick: false) }
            Divider()
            Button(L.t("menu.about")) { About.show() }
            Button(L.t("menu.quit")) { NSApp.terminate(nil) }.keyboardShortcut("q")
        } label: { MenuBarIcon() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private static let sizeKey = "mcasting.mainWindowSize"

    /// Splash animé (règle Socle) : il part avant la fenêtre principale, qui n'apparaît qu'à t = 2 s.
    func applicationWillFinishLaunching(_ notification: Notification) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        MainActor.assumeIsolated {
            Splash.shared.start(Splash.Config(title: "mCASTING", subtitle: L.t("splash.subtitle"), footer: version.isEmpty ? "" : "v" + version,
                                              accent: Color(red: 0xf0 / 255, green: 0x8a / 255, blue: 0x52 / 255)))
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            AppState.shared.start()
            Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in Task { @MainActor in Updater.shared.tick(busy: AppState.shared.busy) } }
            Updater.shared.tick(busy: AppState.shared.busy)
            if !CommandLine.arguments.contains("--silent") { showMain() }     // --silent : essais sans fenêtre au premier plan
            else { showMain(front: false) }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows f: Bool) -> Bool { if !f { Task { @MainActor in showMain() } }; return true }

    /// Fenêtre principale (Socle : barre de titre transparente, contenu dessous, barre d'outils vide qui descend les boutons,
    /// lancement centré sur l'écran du pointeur, à la dernière taille choisie (1200 × 740 au premier lancement), minimum 1000 × 640).
    @MainActor func showMain(front: Bool = true) {
        if window == nil {
            let w = MainWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 740), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true; w.titleVisibility = .hidden; w.isReleasedWhenClosed = false
            w.title = "mCASTING"; w.backgroundColor = Flat.bgNS
            let tb = NSToolbar(identifier: "mcasting.main"); tb.showsBaselineSeparator = false; w.toolbar = tb; w.toolbarStyle = .unified
            w.minSize = NSSize(width: 1000, height: 640)
            let host = NSHostingController(rootView: ContentView())
            host.sizingOptions = []
            w.contentViewController = host
            // Taille mémorisée, position jamais : la fenêtre s'ouvre toujours centrée sur l'écran du pointeur.
            let saved = NSSizeFromString(UserDefaults.standard.string(forKey: Self.sizeKey) ?? "")
            var size = saved.width >= w.minSize.width && saved.height >= w.minSize.height ? saved : NSSize(width: 1200, height: 740)
            w.setFrame(NSRect(origin: .zero, size: size), display: false)
            if let zone = (NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main)?.visibleFrame {
                size = NSSize(width: min(size.width, zone.width), height: min(size.height, zone.height))
                w.setFrame(NSRect(x: (zone.midX - size.width / 2).rounded(), y: (zone.midY - size.height / 2).rounded(), width: size.width, height: size.height), display: false)
            }
            NotificationCenter.default.addObserver(forName: NSWindow.didEndLiveResizeNotification, object: w, queue: .main) { n in
                guard let w = n.object as? NSWindow, !w.styleMask.contains(.fullScreen) else { return }
                UserDefaults.standard.set(NSStringFromSize(w.frame.size), forKey: Self.sizeKey)
            }
            window = w
            if Splash.shared.hold(w) { return }          // premier affichage confié au splash (t = 2 s)
        }
        if front { window?.present() } else { window?.orderBack(nil) }
    }
}

/// Icône de barre de menus : micro en couleur (orange Flat Mat), à la demande de l'auteur.
struct MenuBarIcon: View {
    private static let img: NSImage = {
        let c = NSColor(srgbRed: 0xd9 / 255, green: 0x62 / 255, blue: 0x2b / 255, alpha: 1)
        let base = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "mCASTING") ?? NSImage()
        let i = base.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [c]).applying(NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold))) ?? base
        i.isTemplate = false; return i
    }()
    var body: some View { Image(nsImage: Self.img) }
}


/// Fenêtre principale. La barre d'outils vide (Socle : elle descend les boutons de fenêtre) recouvre les 52 px du haut ;
/// depuis macOS 27.2 elle avale les clics, et le bouton « Réglages » de la barre du haut ne répondait plus (25/11/2026).
/// Les clics de cette bande vont donc directement au contenu SwiftUI, sauf sur les trois boutons de fenêtre ;
/// le déplacement de la fenêtre par la barre est rendu par `WindowDragGesture` (TopBar).
final class MainWindow: NSWindow {
    static let band: CGFloat = 52
    private var tracked: NSView?
    override func sendEvent(_ e: NSEvent) {
        switch e.type {
        case .leftMouseDown:
            if let cv = contentView, e.locationInWindow.y >= cv.bounds.height - Self.band, !onWindowButton(e.locationInWindow),
               let hit = cv.hitTest(cv.convert(e.locationInWindow, from: nil)) {
                tracked = hit; hit.mouseDown(with: e); return
            }
        case .leftMouseDragged:
            if let v = tracked { v.mouseDragged(with: e); return }
        case .leftMouseUp:
            if let v = tracked { tracked = nil; v.mouseUp(with: e); return }
        default: break
        }
        super.sendEvent(e)
    }
    private func onWindowButton(_ p: NSPoint) -> Bool {
        [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].contains { type in
            guard let b = standardWindowButton(type), let sv = b.superview else { return false }
            return sv.convert(b.frame, to: nil).insetBy(dx: -4, dy: -4).contains(p)
        }
    }
}
