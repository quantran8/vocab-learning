import Foundation

struct Topic: Identifiable, Hashable {
    let id: String
    let name: String
    let systemImage: String
}

struct TopicGroup: Identifiable, Hashable {
    let id: String
    let name: String
    let topics: [Topic]
}

/// Demo taxonomy. The production taxonomy should come from the curated vocabulary database.
enum TopicCatalog {
    static let groups: [TopicGroup] = [
        TopicGroup(id: "daily-life", name: String(localized: "Daily life"), topics: [
            Topic(id: "everyday-english", name: String(localized: "Everyday English"), systemImage: "text.bubble"),
            Topic(id: "travel", name: String(localized: "Travel"), systemImage: "airplane"),
            Topic(id: "food-drink", name: String(localized: "Food & Drink"), systemImage: "fork.knife"),
            Topic(id: "health", name: String(localized: "Health"), systemImage: "heart"),
            Topic(id: "communication", name: String(localized: "Communication"), systemImage: "bubble.left.and.bubble.right"),
            Topic(id: "productivity", name: String(localized: "Productivity"), systemImage: "checklist"),
        ]),
        TopicGroup(id: "work-career", name: String(localized: "Work & career"), topics: [
            Topic(id: "business", name: String(localized: "Business"), systemImage: "briefcase"),
            Topic(id: "workplace", name: String(localized: "Workplace"), systemImage: "building.2"),
            Topic(id: "marketing", name: String(localized: "Marketing"), systemImage: "megaphone"),
            Topic(id: "finance", name: String(localized: "Finance"), systemImage: "creditcard"),
            Topic(id: "interviews", name: String(localized: "Interviews"), systemImage: "person.2"),
            Topic(id: "design", name: String(localized: "Design"), systemImage: "paintpalette"),
        ]),
        TopicGroup(id: "study-ideas", name: String(localized: "Study & ideas"), topics: [
            Topic(id: "academic", name: String(localized: "Academic"), systemImage: "graduationcap"),
            Topic(id: "education", name: String(localized: "Education"), systemImage: "book"),
            Topic(id: "science", name: String(localized: "Science"), systemImage: "atom"),
            Topic(id: "history", name: String(localized: "History"), systemImage: "building.columns"),
            Topic(id: "literature", name: String(localized: "Literature"), systemImage: "books.vertical"),
            Topic(id: "psychology", name: String(localized: "Psychology"), systemImage: "brain.head.profile"),
        ]),
        TopicGroup(id: "culture-interests", name: String(localized: "Culture & interests"), topics: [
            Topic(id: "culture", name: String(localized: "Culture"), systemImage: "globe"),
            Topic(id: "art-music", name: String(localized: "Art & Music"), systemImage: "music.note"),
            Topic(id: "sports", name: String(localized: "Sports"), systemImage: "trophy"),
            Topic(id: "nature", name: String(localized: "Nature"), systemImage: "leaf"),
        ]),
        TopicGroup(id: "tech-world", name: String(localized: "Tech & world"), topics: [
            Topic(id: "technology", name: String(localized: "Technology"), systemImage: "cpu"),
            Topic(id: "environment", name: String(localized: "Environment"), systemImage: "tree"),
        ]),
    ]

    /// Topics whose name matches, or every topic of a group whose name matches. Empty query → everything.
    static func filtered(by query: String, in groups: [TopicGroup] = groups) -> [TopicGroup] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return groups }
        return groups.compactMap { group in
            let groupMatches = group.name.localizedCaseInsensitiveContains(needle)
            let topics = group.topics.filter { groupMatches || $0.name.localizedCaseInsensitiveContains(needle) }
            return topics.isEmpty ? nil : TopicGroup(id: group.id, name: group.name, topics: topics)
        }
    }
}

extension TopicCatalog {
    static func topic(id: String) -> Topic? {
        groups.lazy.flatMap(\.topics).first { $0.id == id }
    }

    /// Selected topics in catalog order.
    static func topics(ids: Set<String>) -> [Topic] {
        groups.flatMap(\.topics).filter { ids.contains($0.id) }
    }
}

/// Search text plus which groups are folded. Search results always show expanded so matches are never hidden.
struct TopicBrowserState: Equatable {
    var query = ""
    private(set) var collapsedGroupIDs: Set<String>

    /// Opens the first group and any group already holding a pick; folds the rest to keep the list short.
    init(selected: Set<String>, groups: [TopicGroup] = TopicCatalog.groups) {
        collapsedGroupIDs = Set(
            groups.dropFirst()
                .filter { group in !group.topics.contains { selected.contains($0.id) } }
                .map(\.id)
        )
    }

    var isSearching: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var visibleGroups: [TopicGroup] { TopicCatalog.filtered(by: query) }

    func isExpanded(_ group: TopicGroup) -> Bool {
        isSearching || !collapsedGroupIDs.contains(group.id)
    }

    mutating func toggleGroup(_ id: String) {
        guard !isSearching else { return }
        if collapsedGroupIDs.contains(id) { collapsedGroupIDs.remove(id) } else { collapsedGroupIDs.insert(id) }
    }
}
