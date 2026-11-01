import Foundation

/// One Practice Lab entry: a backend task template with bundled example tasks in the plan wire format,
/// so the Lab renders the same views and rules as a live session.
struct LabTemplate: Decodable, Identifiable, Equatable {
    let id: TaskTemplate
    let title: String
    let action: String
    let systemImage: String
    let tasks: [PracticeTask]
}

struct LabLibrary: Decodable, Equatable {
    let templates: [LabTemplate]

    enum ValidationError: Error, Equatable {
        case emptyTemplate(TaskTemplate)
        case templateMismatch(taskID: String)
        case duplicateTaskID(String)
        case missingTemplate(TaskTemplate)
    }

    /// Every backend template must be playable once, and each task must belong to its entry.
    func validate() throws {
        var seen: Set<String> = []
        for template in templates {
            guard !template.tasks.isEmpty else { throw ValidationError.emptyTemplate(template.id) }
            for task in template.tasks {
                guard task.template == template.id else { throw ValidationError.templateMismatch(taskID: task.id) }
                guard seen.insert(task.id).inserted else { throw ValidationError.duplicateTaskID(task.id) }
            }
        }
        for kind in TaskTemplate.allCases where !templates.contains(where: { $0.id == kind }) {
            throw ValidationError.missingTemplate(kind)
        }
    }
}
