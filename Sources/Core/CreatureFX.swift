// mCASTING — effets de voix pour créatures et animaux (AVAudioEngine, rendu hors ligne, aucune dépendance).
// Chaque effet a son équivalent ffmpeg dans casting.json, pour que la génération des répliques donne le même son.
import Foundation
import AVFoundation

public struct VoiceFX: Hashable {
    public let id: String          // giant.deep, dragon.growl…
    public let key: String         // clé du nom affiché (L10n)
    public var semitones: Float = 0
    public var rate: Float = 1     // vitesse (1 = inchangée)
    public var distortion: Float = 0          // 0…100 (mélange)
    public var reverb: Float = 0              // 0…100 (mélange)
    public var reverbPreset: AVAudioUnitReverbPreset = .mediumHall
    public var echo: Bool = false

    /// Filtre ffmpeg équivalent (hauteur par rééchantillonnage + tempo compensé, écho, sans réverbération ni distorsion exactes).
    public var ffmpeg: String {
        let f = pow(2, semitones / 12)
        var parts = ["asetrate=24000*\(String(format: "%.4f", f))", "aresample=24000", "atempo=\(String(format: "%.4f", min(2, max(0.5, rate / f))))"]
        if reverb > 0 || echo { parts.append(echo ? "aecho=0.8:0.7:120|240:0.4|0.25" : "aecho=0.8:0.6:60:0.3") }
        if distortion > 0 { parts.append("acrusher=bits=10:mix=\(String(format: "%.2f", distortion / 200))") }
        return parts.joined(separator: ",")
    }
}

public enum CreatureFX {
    /// Trois effets par famille de personnage (gros, petit, spectral, mécanique, animal).
    public static func presets(for c: Character) -> [VoiceFX] {
        let sp = Creatures.species(c) ?? "", t = Creatures.text(c)
        let big = ["dragon", "troll", "giant", "golem", "orc", "demon", "gargoyle", "bear", "sphinx"].contains(sp) || t.contains("grave") || t.contains("immense") || t.contains("géant")
        let small = ["goblin", "imp", "fairy", "mouse", "rat", "frog", "hedgehog", "parrot", "bat"].contains(sp) || t.contains("petit") || t.contains("aigu")
        if ["ghost", "wraith", "skeleton", "vampire"].contains(sp) {
            return [VoiceFX(id: "ghost.echo", key: "fx.echo", semitones: -2, reverb: 60, reverbPreset: .cathedral, echo: true),
                    VoiceFX(id: "ghost.whisper", key: "fx.whisper", semitones: 1, rate: 0.95, reverb: 45, reverbPreset: .largeHall),
                    VoiceFX(id: "ghost.deep", key: "fx.deep", semitones: -5, reverb: 50, reverbPreset: .cathedral)]
        }
        if sp == "robot" {
            return [VoiceFX(id: "robot.metal", key: "fx.metal", semitones: -1, distortion: 35, reverb: 15, reverbPreset: .smallRoom),
                    VoiceFX(id: "robot.radio", key: "fx.radio", distortion: 55),
                    VoiceFX(id: "robot.deep", key: "fx.deep", semitones: -4, distortion: 25)]
        }
        if big {
            return [VoiceFX(id: "big.deep", key: "fx.verydeep", semitones: -7, rate: 0.95),
                    VoiceFX(id: "big.growl", key: "fx.growl", semitones: -5, distortion: 30),
                    VoiceFX(id: "big.cave", key: "fx.cave", semitones: -4, reverb: 45, reverbPreset: .cathedral)]
        }
        if small {
            return [VoiceFX(id: "small.high", key: "fx.high", semitones: 5, rate: 1.1),
                    VoiceFX(id: "small.squeak", key: "fx.squeak", semitones: 8, rate: 1.15),
                    VoiceFX(id: "small.sly", key: "fx.sly", semitones: 3, reverb: 20, reverbPreset: .smallRoom)]
        }
        return [VoiceFX(id: "mid.deep", key: "fx.deep", semitones: -3),
                VoiceFX(id: "mid.high", key: "fx.high", semitones: 4, rate: 1.05),
                VoiceFX(id: "mid.rough", key: "fx.rough", semitones: -2, distortion: 25)]
    }
    public static func find(_ id: String?, for c: Character) -> VoiceFX? { id.flatMap { i in presets(for: c).first { $0.id == i } } }

    /// Applique l'effet à un fichier audio et écrit le résultat en .m4a.
    public static func render(_ fx: VoiceFX, input: URL, output: URL) throws {
        let file = try AVAudioFile(forReading: input)
        // Les effets veulent du stéréo standard : un mélangeur convertit l'extrait (souvent mono 24 kHz).
        let format = AVAudioFormat(standardFormatWithSampleRate: file.processingFormat.sampleRate, channels: 2)!
        let engine = AVAudioEngine(), player = AVAudioPlayerNode(), conv = AVAudioMixerNode(), pitch = AVAudioUnitTimePitch()
        let dist = AVAudioUnitDistortion(), verb = AVAudioUnitReverb()
        pitch.pitch = fx.semitones * 100; pitch.rate = fx.rate
        dist.loadFactoryPreset(.multiDecimated2); dist.wetDryMix = fx.distortion
        verb.loadFactoryPreset(fx.reverbPreset); verb.wetDryMix = fx.reverb
        [player, conv, pitch, dist, verb].forEach { engine.attach($0) }
        engine.connect(player, to: conv, format: file.processingFormat)
        engine.connect(conv, to: pitch, format: format)
        engine.connect(pitch, to: dist, format: format)
        engine.connect(dist, to: verb, format: format)
        engine.connect(verb, to: engine.mainMixerNode, format: format)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        try engine.start()
        player.scheduleFile(file, at: nil)
        player.play()
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: output)
        let out = try AVAudioFile(forWriting: output, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: format.sampleRate,
                                                                 AVNumberOfChannelsKey: format.channelCount, AVEncoderBitRateKey: 96000])
        let buf = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: engine.manualRenderingMaximumFrameCount)!
        // Durée de sortie = durée d'entrée / vitesse, plus une queue pour la réverbération.
        let total = AVAudioFramePosition(Double(file.length) / Double(fx.rate)) + AVAudioFramePosition(format.sampleRate * (fx.reverb > 0 ? 1.2 : 0.2))
        while engine.manualRenderingSampleTime < total {
            let n = min(buf.frameCapacity, AVAudioFrameCount(total - engine.manualRenderingSampleTime))
            guard try engine.renderOffline(n, to: buf) == .success else { break }
            try out.write(from: buf)
        }
        player.stop(); engine.stop()
    }
}
