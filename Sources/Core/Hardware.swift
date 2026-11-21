// mCASTING — détection du matériel et adéquation des modèles (guide « Premiers pas »).
import Foundation

public struct Hardware {
    public enum Tier: Int, Comparable { case light = 0, comfort, studio
        public static func < (a: Tier, b: Tier) -> Bool { a.rawValue < b.rawValue }
    }
    public enum Fit { case proposed, possible, hidden }

    public let chip: String
    public let memoryGB: Double
    public let freeDiskGB: Double

    public static let current: Hardware = {
        func sys(_ name: String) -> String {
            var size = 0; sysctlbyname(name, nil, &size, nil, 0)
            var buf = [CChar](repeating: 0, count: max(size, 1)); sysctlbyname(name, &buf, &size, nil, 0)
            return String(cString: buf)
        }
        var mem: UInt64 = 0, len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &mem, &len, nil, 0)
        let free = (try? Paths.home.deletingLastPathComponent().resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage ?? 0
        let chip = sys("machdep.cpu.brand_string").replacingOccurrences(of: "Apple ", with: "")
        return Hardware(chip: chip.isEmpty ? "Mac" : chip, memoryGB: Double(mem) / 1_073_741_824, freeDiskGB: Double(free) / 1_000_000_000)
    }()

    public var tier: Tier { memoryGB >= 60 ? .studio : memoryGB >= 24 ? .comfort : .light }

    /// Proposé si le modèle occupe moins de la moitié de la mémoire, possible jusqu'à 70 %, masqué au-delà.
    public func fit(ramGB: Double) -> Fit {
        let r = ramGB / max(memoryGB, 1)
        return r < 0.5 ? .proposed : r <= 0.7 ? .possible : .hidden
    }
}
