import CryptoKit
import Foundation

/// The deterministic column order shared with the backend's replay. Each column is sorted on its own, ascending by
/// lowercase hex `SHA256(UTF8(boardSeed + "|" + correctCount + "|" + side + "|" + tileId))`, ties broken by `tileId`.
/// Computed for the first board (`correctCount` 0) and again after every correct match.
/// Must stay byte-for-byte equal to the server rule: check it against the shared test vectors.
enum ChallengeBoardOrdering {
    enum Side: String {
        case word
        case meaning
    }

    static func order(_ tileIDs: [String], seed: String, correctCount: Int, side: Side) -> [String] {
        let keyed: [(id: String, key: String)] = tileIDs.map { id in
            (id: id, key: sortKey(seed: seed, correctCount: correctCount, side: side, tileID: id))
        }
        let sorted = keyed.sorted { (a: (id: String, key: String), b: (id: String, key: String)) -> Bool in
            a.key == b.key ? a.id < b.id : a.key < b.key
        }
        return sorted.map { $0.id }
    }

    static func sortKey(seed: String, correctCount: Int, side: Side, tileID: String) -> String {
        let input = "\(seed)|\(correctCount)|\(side.rawValue)|\(tileID)"
        return SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
