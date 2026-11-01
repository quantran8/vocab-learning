import Foundation
import Observation

struct Topic: Identifiable, Hashable {
    let id: String
    let name: String
    let systemImage: String
}

/// A vocabulary track such as Everyday or IELTS. Learners pick one, then any of its topics.
struct VocabCollection: Identifiable, Hashable {
    let id: String
    let name: String
    let summary: String
    let systemImage: String
    let topics: [Topic]

    var topicIDs: Set<String> { Set(topics.map(\.id)) }
}

/// The live taxonomy. `@Observable` so screens update when the backend's catalog arrives.
@Observable
private final class CatalogState {
    var collections: [VocabCollection]

    init(collections: [VocabCollection]) {
        self.collections = collections
    }
}

/// Starts as the bundled taxonomy, which previews and tests use and which also supplies icons;
/// `update(with:)` swaps in the backend's, whose ids are the ones `PUT /me/scope` accepts.
/// Topic ids are unique across collections; Everyday keeps the original unprefixed ids.
enum TopicCatalog {
    private static let state = CatalogState(collections: bundled)

    static var collections: [VocabCollection] { state.collections }

    static func update(with catalog: [CatalogCollection]) {
        state.collections = catalog.map { collection in
            VocabCollection(
                id: collection.id,
                name: collection.title,
                summary: collection.description ?? "",
                systemImage: icon(slug: collection.slug, fallback: "square.stack"),
                topics: collection.topics.map { topic in
                    Topic(id: topic.id, name: topic.title, systemImage: icon(slug: topic.slug, fallback: "tag"))
                }
            )
        }
    }

    /// The backend has no icons, so slugs matching a bundled entry reuse its symbol.
    private static func icon(slug: String, fallback: String) -> String {
        bundled.first { $0.id == slug }?.systemImage
            ?? bundled.lazy.flatMap(\.topics).first { $0.id == slug }?.systemImage
            ?? fallback
    }

    private static let bundled: [VocabCollection] = [
        VocabCollection(
            id: "everyday",
            name: String(localized: "Everyday"),
            summary: String(localized: "Words for daily conversations and life"),
            systemImage: "sun.max",
            topics: [
                Topic(id: "everyday-english", name: String(localized: "Everyday English"), systemImage: "text.bubble"),
                Topic(id: "travel", name: String(localized: "Travel"), systemImage: "airplane"),
                Topic(id: "food-drink", name: String(localized: "Food & Drink"), systemImage: "fork.knife"),
                Topic(id: "health", name: String(localized: "Health"), systemImage: "heart"),
                Topic(id: "communication", name: String(localized: "Communication"), systemImage: "bubble.left.and.bubble.right"),
                Topic(id: "shopping", name: String(localized: "Shopping"), systemImage: "bag"),
                Topic(id: "home", name: String(localized: "Home"), systemImage: "house"),
                Topic(id: "sports", name: String(localized: "Sports"), systemImage: "trophy"),
                Topic(id: "art-music", name: String(localized: "Art & Music"), systemImage: "music.note"),
            ]
        ),
        VocabCollection(
            id: "ielts",
            name: String(localized: "IELTS"),
            summary: String(localized: "Academic vocabulary for a higher band score"),
            systemImage: "graduationcap",
            topics: [
                Topic(id: "ielts-education", name: String(localized: "Education"), systemImage: "book"),
                Topic(id: "ielts-environment", name: String(localized: "Environment"), systemImage: "leaf"),
                Topic(id: "ielts-technology", name: String(localized: "Technology"), systemImage: "cpu"),
                Topic(id: "ielts-health", name: String(localized: "Health"), systemImage: "heart"),
                Topic(id: "ielts-society", name: String(localized: "Society"), systemImage: "person.3"),
                Topic(id: "ielts-science", name: String(localized: "Science"), systemImage: "atom"),
                Topic(id: "ielts-culture", name: String(localized: "Culture"), systemImage: "globe"),
                Topic(id: "ielts-economy", name: String(localized: "Economy"), systemImage: "chart.line.uptrend.xyaxis"),
            ]
        ),
        VocabCollection(
            id: "toeic",
            name: String(localized: "TOEIC"),
            summary: String(localized: "Workplace English that shows up on the test"),
            systemImage: "checkmark.seal",
            topics: [
                Topic(id: "toeic-office", name: String(localized: "Office"), systemImage: "building.2"),
                Topic(id: "toeic-meetings", name: String(localized: "Meetings"), systemImage: "person.2"),
                Topic(id: "toeic-hiring", name: String(localized: "Hiring"), systemImage: "person.badge.plus"),
                Topic(id: "toeic-purchasing", name: String(localized: "Purchasing"), systemImage: "cart"),
                Topic(id: "toeic-travel", name: String(localized: "Business travel"), systemImage: "airplane"),
                Topic(id: "toeic-dining", name: String(localized: "Dining out"), systemImage: "fork.knife"),
                Topic(id: "toeic-finance", name: String(localized: "Finance"), systemImage: "creditcard"),
            ]
        ),
        VocabCollection(
            id: "business",
            name: String(localized: "Business"),
            summary: String(localized: "Professional language for work and career"),
            systemImage: "briefcase",
            topics: [
                Topic(id: "business", name: String(localized: "General business"), systemImage: "briefcase"),
                Topic(id: "workplace", name: String(localized: "Workplace"), systemImage: "building.2"),
                Topic(id: "marketing", name: String(localized: "Marketing"), systemImage: "megaphone"),
                Topic(id: "finance", name: String(localized: "Finance"), systemImage: "creditcard"),
                Topic(id: "interviews", name: String(localized: "Interviews"), systemImage: "person.2"),
                Topic(id: "negotiation", name: String(localized: "Negotiation"), systemImage: "arrow.left.arrow.right"),
                Topic(id: "productivity", name: String(localized: "Productivity"), systemImage: "checklist"),
            ]
        ),
    ]

    static func collection(id: String) -> VocabCollection? {
        collections.first { $0.id == id }
    }

    static func topic(id: String) -> Topic? {
        collections.lazy.flatMap(\.topics).first { $0.id == id }
    }

    /// Selected topics in catalog order.
    static func topics(ids: Set<String>) -> [Topic] {
        collections.flatMap(\.topics).filter { ids.contains($0.id) }
    }
}
