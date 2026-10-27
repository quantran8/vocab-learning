import Foundation

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    // SplitMix64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum DemoSeed {
    static let defaultSeed: UInt64 = 20_261_027

    static func shuffled<T>(_ items: [T], seed: UInt64) -> [T] {
        var generator = SeededGenerator(seed: seed)
        return items.shuffled(using: &generator)
    }
}
