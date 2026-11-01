import XCTest
@testable import VocabFlow

final class LabLibraryTests: XCTestCase {
    func testBundledLabCoversEveryBackendTemplate() throws {
        let library = try DemoContentRepository().loadLab()
        XCTAssertEqual(Set(library.templates.map(\.id)), Set(TaskTemplate.allCases))
    }

    func testLabTasksUseTheirTemplateAndHaveUniqueIDs() throws {
        let library = try DemoContentRepository().loadLab()
        let ids = library.templates.flatMap { $0.tasks.map(\.id) }
        XCTAssertEqual(ids.count, Set(ids).count)
        for template in library.templates {
            XCTAssertTrue(template.tasks.allSatisfy { $0.template == template.id })
        }
    }

    @MainActor
    func testSandboxPlaysTasksWithoutCommitting() throws {
        let api = StubVocabAPI()
        let store = PracticeSessionStore(api: api, audio: SilentAudioClips(), recorder: NoVoiceRecorder(), haptics: NoOpFeedback())
        var ended = false
        store.onSandboxEnd = { ended = true }
        store.startSandbox([PracticeFixtures.choice()])
        XCTAssertTrue(store.isSandbox)
        store.submitOption(3)
        store.advance()
        XCTAssertTrue(ended)
        XCTAssertTrue(api.commitBodies.isEmpty)
    }
}
