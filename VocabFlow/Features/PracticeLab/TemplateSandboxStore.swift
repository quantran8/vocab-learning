import Foundation
import Observation

/// Owns Practice Lab navigation. Each template plays through its own `PracticeSessionStore` in sandbox mode,
/// so the Lab shows exactly what a live session shows but never plans, commits or touches learner progress.
@Observable
@MainActor
final class TemplateSandboxStore {
    let templates: [LabTemplate]
    let session: PracticeSessionStore

    private(set) var isOpen = false
    private(set) var activeTemplate: TaskTemplate?

    init(templates: [LabTemplate], session: PracticeSessionStore) {
        self.templates = templates
        self.session = session
        session.onSandboxEnd = { [weak self] in self?.closeTemplate() }
    }

    func openLab() {
        isOpen = true
    }

    func closeLab() {
        closeTemplate()
        isOpen = false
    }

    /// Every entry starts a fresh run.
    func open(_ kind: TaskTemplate) {
        guard let template = templates.first(where: { $0.id == kind }) else { return }
        session.close()
        activeTemplate = kind
        session.startSandbox(template.tasks)
    }

    func closeTemplate() {
        session.close()
        activeTemplate = nil
    }
}
