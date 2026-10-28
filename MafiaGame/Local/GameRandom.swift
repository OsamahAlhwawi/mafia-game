import Foundation

/// The game's dice. Seeded in tests so a game plays out the same every run.
final class GameRandom {
    private var generator: any RandomNumberGenerator

    init(seed: UInt64? = nil) {
        if let seed {
            generator = SplitMix64(state: seed)
        } else {
            generator = SystemRandomNumberGenerator()
        }
    }

    /// A float in [0, 1).
    func next() -> Double {
        Double(generator.next() >> 11) * 0x1.0p-53
    }

    func int(_ upperBound: Int) -> Int {
        Int(next() * Double(upperBound))
    }

    func chance(_ probability: Double) -> Bool {
        next() < probability
    }

    func pick<T>(_ items: [T]) -> T {
        precondition(!items.isEmpty, "pick from empty list")
        return items[int(items.count)]
    }

    /// Fisher–Yates; returns a new array.
    func shuffled<T>(_ items: [T]) -> [T] {
        var out = items
        for i in stride(from: out.count - 1, to: 0, by: -1) {
            out.swapAt(i, int(i + 1))
        }
        return out
    }
}

/// Small deterministic generator for tests.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
