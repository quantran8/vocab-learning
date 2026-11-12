import Foundation

/// One learner action, in the shape commit expects. The backend's schema is strict, so each
/// action encodes only its own fields.
struct TaskEvent: Encodable, Equatable {
    enum Action: Equatable {
        case submitOption(Int)
        case submitValue(String)
        case submitTiles([Int])
        /// Surgery: every fix, sorted by index. An empty replacement deletes the grapheme.
        case submitRepair([RepairEdit])
        case pair(leftID: Int, rightID: Int)
        case tapTile(Int)
        case removeTile(Int)
        case moveTile(Int, toIndex: Int)
        case hint
        case reveal
        case assessed(receiptID: String)
        case unavailable(reason: String)
        /// On-device take. The backend re-checks the transcript against the task's text.
        case transcribed(String)

        var isSubmit: Bool {
            switch self {
            case .submitOption, .submitValue, .submitTiles, .submitRepair: true
            default: false
            }
        }
    }

    let seq: Int
    let action: Action

    private enum CodingKeys: String, CodingKey {
        case seq, action, optionId, value, tileIds, graphemeIndex, replacement, edits
        case leftId, rightId, tileId, toIndex, assessmentReceiptId, reason, transcript
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(seq, forKey: .seq)
        switch action {
        case .submitOption(let id):
            try container.encode("submit", forKey: .action)
            try container.encode(id, forKey: .optionId)
        case .submitValue(let value):
            try container.encode("submit", forKey: .action)
            try container.encode(value, forKey: .value)
        case .submitTiles(let ids):
            try container.encode("submit", forKey: .action)
            try container.encode(ids, forKey: .tileIds)
        case .submitRepair(let edits):
            try container.encode("submit", forKey: .action)
            // One fix keeps the original shape, which backends without `edits` still accept.
            if edits.count == 1 {
                try container.encode(edits[0].graphemeIndex, forKey: .graphemeIndex)
                try container.encode(edits[0].replacement, forKey: .replacement)
            } else {
                try container.encode(edits, forKey: .edits)
            }
        case .pair(let left, let right):
            try container.encode("pair", forKey: .action)
            try container.encode(left, forKey: .leftId)
            try container.encode(right, forKey: .rightId)
        case .tapTile(let id):
            try container.encode("tap_tile", forKey: .action)
            try container.encode(id, forKey: .tileId)
        case .removeTile(let id):
            try container.encode("remove_tile", forKey: .action)
            try container.encode(id, forKey: .tileId)
        case .moveTile(let id, let index):
            try container.encode("move_tile", forKey: .action)
            try container.encode(id, forKey: .tileId)
            try container.encode(index, forKey: .toIndex)
        case .hint:
            try container.encode("hint", forKey: .action)
        case .reveal:
            try container.encode("reveal", forKey: .action)
        case .assessed(let id):
            try container.encode("assessed", forKey: .action)
            try container.encode(id, forKey: .assessmentReceiptId)
        case .unavailable(let reason):
            try container.encode("unavailable", forKey: .action)
            try container.encode(reason, forKey: .reason)
        case .transcribed(let transcript):
            try container.encode("transcribed", forKey: .action)
            try container.encode(transcript, forKey: .transcript)
        }
    }
}

struct RepairEdit: Encodable, Equatable {
    let graphemeIndex: Int
    let replacement: String
}

enum DeliveryMode: String, Encodable, Equatable {
    case audio, fallback, none
}

struct TaskResult: Encodable, Equatable {
    let taskId: String
    /// Required for audio prompts; omitted for text prompts.
    let deliveryMode: DeliveryMode?
    let events: [TaskEvent]
}

struct CommitBody: Encodable, Equatable {
    let learnStepsCompleted: [String]
    /// Learn steps marked "I know this word"; omitted when empty so older bodies stay byte-identical.
    var knownLearnSteps: [String]? = nil
    let taskResults: [TaskResult]
}
