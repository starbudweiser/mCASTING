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
    /// lancement centré sur l'écran du pointeur, 1200 × 720, minimum 900 × 560).
    @MainActor func showMain(front: Bool = true) {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 740), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true; w.titleVisibility = .hidden; w.isReleasedWhenClosed = false
            w.title = "mCASTING"; w.backgroundColor = Flat.bgNS
            let tb = NSToolbar(identifier: "mcasting.main"); tb.showsBaselineSeparator = false; w.toolbar = tb; w.toolbarStyle = .unified
            w.minSize = NSSize(width: 1000, height: 640)
            let host = NSHostingController(rootView: ContentView())
            host.sizingOptions = []
            w.contentViewController = host
            w.setFrame(NSRect(x: 0, y: 0, width: 1200, height: 740), display: false)
            if let zone = (NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main)?.visibleFrame {
                let size = NSSize(width: min(1200, zone.width), height: min(740, zone.height))
                w.setFrame(NSRect(x: zone.midX - size.width / 2, y: zone.midY - size.height / 2, width: size.width, height: size.height), display: false)
            }
            window = w
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
