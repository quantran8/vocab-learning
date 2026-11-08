import SwiftUI

/// Rules for a password the learner creates (sign up, reset, change). Logging in only checks length,
/// so accounts made before these rules keep working. The backend enforces the same rules.
enum PasswordPolicy {
    enum Rule: CaseIterable, Identifiable {
        case length, letter, digit

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .length: "At least 8 characters"
            case .letter: "At least one letter"
            case .digit: "At least one number"
            }
        }

        func isMet(by password: String) -> Bool {
            switch self {
            case .length: password.count >= AuthStore.passwordLength.lowerBound
            case .letter: password.unicodeScalars.contains { CharacterSet.letters.contains($0) }
            case .digit: password.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }
            }
        }
    }

    static func isTooLong(_ password: String) -> Bool {
        password.count > AuthStore.passwordLength.upperBound
    }

    static func accepts(_ password: String) -> Bool {
        !isTooLong(password) && Rule.allCases.allSatisfy { $0.isMet(by: password) }
    }
}

/// The rules under a new-password field, ticked live as the learner types.
struct PasswordRuleList: View {
    let password: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            ForEach(PasswordPolicy.Rule.allCases) { rule in
                row(rule.title, isMet: rule.isMet(by: password))
            }
            if PasswordPolicy.isTooLong(password) {
                row("At most 72 characters", isMet: false)
            }
        }
        .font(Typography.secondary)
    }

    private func row(_ title: LocalizedStringKey, isMet: Bool) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isMet ? Color.success : Color.mutedInk)
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(isMet ? Color.successInk : Color.mutedInk)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isMet ? Text("Done") : Text("Not yet"))
    }
}
