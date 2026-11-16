import SwiftUI

struct TodoRow: View {
    let todo: TodoItem
    let onToggle: () -> Void

    /// Shows the check animation briefly before the task leaves the list.
    @State private var isChecking = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: check) {
                CheckCircle(isOn: todo.isDone || isChecking)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isDone ? "Mark as not done" : "Mark as done")

            VStack(alignment: .leading, spacing: 3) {
                Text(todo.title)
                    .foregroundStyle(todo.isDone ? .secondary : .primary)

                if let due = todo.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(DueFormat.label(for: due, isAllDay: todo.isAllDay))
                    }
                    .font(.footnote)
                    .foregroundStyle(todo.isOverdue() ? Color.red : Color.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
    }

    private func check() {
        guard !todo.isDone else {
            onToggle()
            return
        }
        guard !isChecking else { return }
        isChecking = true
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            onToggle()
            isChecking = false
        }
    }
}

/// A thin ring that fills solid with a checkmark when completed.
struct CheckCircle: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.tertiary, lineWidth: 1.5)
                .opacity(isOn ? 0 : 1)

            Circle()
                .fill(.primary)
                .scaleEffect(isOn ? 1 : 0.3)
                .opacity(isOn ? 1 : 0)

            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(.systemBackground))
                .scaleEffect(isOn ? 1 : 0.4)
                .opacity(isOn ? 1 : 0)
        }
        .frame(width: 22, height: 22)
        // Enlarge the tap target without affecting layout.
        .padding(10)
        .contentShape(.rect)
        .padding(-10)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isOn)
    }
}
