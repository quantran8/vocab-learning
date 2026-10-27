import Foundation
@testable import VocabFlow

enum TestContent {
    static func demo() throws -> DemoContent {
        try DemoContentRepository().load()
    }

    static func reduce(_ state: SessionState, _ actions: SessionAction..., content: DemoContent) -> (state: SessionState, events: [SessionEvent]) {
        var current = state
        var events: [SessionEvent] = []
        for action in actions {
            let transition = SessionReducer.reduce(state: current, action: action, content: content)
            current = transition.state
            events += transition.events
        }
        return (current, events)
    }

    static func atBuild(_ content: DemoContent) -> SessionState {
        reduce(SessionState(), .start, .learnedNext, .learnedNext, .learnedNext, content: content).state
    }

    static func atRecall(_ content: DemoContent) -> SessionState {
        var state = atBuild(content)
        for challenge in content.buildChallenges {
            state = reduce(state, .buildSubmitted(tileID: challenge.acceptedOptionIDs[0]), .advance, content: content).state
        }
        return state
    }

    static func distractor(_ challenge: BuildChallenge) -> String {
        challenge.options.first { !challenge.acceptedOptionIDs.contains($0.id) }!.id
    }
}
