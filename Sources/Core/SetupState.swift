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
    public var serverURL: String?            // serveur de voix du réseau (API OpenAI)
    public var serverLibrary = false         // fabriquer la bibliothèque sur ce serveur
    public var extraLangs: [String] = []     // langues calculées pour toute la bibliothèque sans projet qui les demande
    public var pausedLangs: [String] = []    // langues dont le calcul est mis en pause
    public init() {}
    enum K: String, CodingKey { case completed, step, assistant, voiceMode, compare, actingModel, projectID, serverURL, serverLibrary, extraLangs, pausedLangs }
    /// Lecture tolérante : un champ ajouté par une version plus récente ne fait pas perdre les autres réglages.
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: K.self)
        completed = (try? c.decodeIfPresent(Bool.self, forKey: .completed)) ?? false
        step = (try? c.decodeIfPresent(Int.self, forKey: .step)) ?? 0
        assistant = try? c.decodeIfPresent(String.self, forKey: .assistant)
        voiceMode = (try? c.decodeIfPresent(String.self, forKey: .voiceMode)) ?? "mac"
        compare = (try? c.decodeIfPresent([String].self, forKey: .compare)) ?? []
        actingModel = try? c.decodeIfPresent(String.self, forKey: .actingModel)
        projectID = try? c.decodeIfPresent(String.self, forKey: .projectID)
        serverURL = try? c.decodeIfPresent(String.self, forKey: .serverURL)
        serverLibrary = (try? c.decodeIfPresent(Bool.self, forKey: .serverLibrary)) ?? false
        extraLangs = (try? c.decodeIfPresent([String].self, forKey: .extraLangs)) ?? []
        pausedLangs = (try? c.decodeIfPresent([String].self, forKey: .pausedLangs)) ?? []
    }

    static var url: URL { Paths.home.appendingPathComponent("setup.json") }
    public static func load() -> SetupState { DataStore.load(SetupState.self, from: url, default: SetupState()) }
    public func save() { try? DataStore.save(self, to: Self.url) }
}
