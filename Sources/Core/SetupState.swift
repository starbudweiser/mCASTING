// mCASTING — avancement du guide « Premiers pas » (reprise possible à tout moment).
import Foundation

public struct SetupState: Codable {
    public var completed = false
    public var step = 0                       // dernière étape atteinte
    public var assistant: String?             // "cloud" | "local" | "none"
    public var voiceMode = "mac"              // "mac" | "server" | "cloud"
    public var compare: [String] = []         // modèles cochés pour l'écoute
    public var actingModel: String?           // modèle retenu pour dire les répliques
    public var projectID: String?
    public init() {}

    static var url: URL { Paths.home.appendingPathComponent("setup.json") }
    public static func load() -> SetupState { DataStore.load(SetupState.self, from: url, default: SetupState()) }
    public func save() { try? DataStore.save(self, to: Self.url) }
}
