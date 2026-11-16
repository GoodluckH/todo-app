import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]

    @State private var showsCompleted = false
    @State private var isConfirmingClear = false
    /// The last task checked off, offered for undo for a few seconds.
    @State private var recentlyCompleted: TodoItem?

    var body: some View {
        let open = todos.filter { !$0.isDone }
        let completed = todos
            .filter(\.isDone)
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        let groups = Dictionary(grouping: open) { DueGroup.of($0) }
            .sorted { $0.key < $1.key }
        let isEmpty = open.isEmpty && (!showsCompleted || completed.isEmpty)

        NavigationStack {
            List {
                ForEach(groups, id: \.key) { group, items in
                    Section {
                        ForEach(items.sorted(by: dueOrder)) { todo in
                            row(for: todo)
                        }
                    } header: {
                        sectionHeader(group.title, count: items.count, isAlert: group == .overdue)
                    }
                }

                if showsCompleted, !completed.isEmpty {
                    Section {
                        ForEach(completed) { todo in
                            row(for: todo)
                        }
                    } header: {
                        sectionHeader("Completed", count: completed.count)
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if isEmpty {
                    ContentUnavailableView(
                        todos.isEmpty ? "No Tasks" : "All Clear",
                        systemImage: "checkmark.circle",
                        description: Text(todos.isEmpty ? "Type a task below. Dates like “Friday at 3pm” are picked up automatically." : "Nothing left to do.")
                    )
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu("More", systemImage: "ellipsis") {
                        Button(showsCompleted ? "Hide Completed" : "Show Completed", systemImage: showsCompleted ? "eye.slash" : "eye") {
                            withAnimation(.snappy) { showsCompleted.toggle() }
                        }
                        Button("Clear Completed", systemImage: "trash", role: .destructive) {
                            isConfirmingClear = true
                        }
                        .disabled(completed.isEmpty)
                    }
                }
            }
            .confirmationDialog(
                "Clear \(completed.count) completed tasks?",
                isPresented: $isConfirmingClear,
                titleVisibility: .visible
            ) {
                Button("Clear Completed", role: .destructive, action: clearCompleted)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if let recentlyCompleted {
                        undoToast(for: recentlyCompleted)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    InputBar(onAdd: add)
                }
            }
            .task(id: recentlyCompleted?.persistentModelID) {
                guard recentlyCompleted != nil else { return }
                do {
                    try await Task.sleep(for: .seconds(4))
                } catch {
                    return
                }
                withAnimation(.snappy) { recentlyCompleted = nil }
            }
            .sensoryFeedback(.success, trigger: completed.count) { old, new in new > old }
            .sensoryFeedback(.impact(weight: .light), trigger: todos.count)
        }
    }

    // MARK: - Subviews

    private func sectionHeader(_ title: LocalizedStringResource, count: Int, isAlert: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(isAlert ? Color.red : Color.primary)
            Text(count, format: .number)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.subheadline.weight(.semibold))
    }

    private func row(for todo: TodoItem) -> some View {
        TodoRow(todo: todo) { toggle(todo) }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button(todo.isDone ? "Undo" : "Done", systemImage: todo.isDone ? "arrow.uturn.backward" : "checkmark") {
                    toggle(todo)
                }
                .tint(todo.isDone ? .gray : .green)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    delete(todo)
                }
            }
            .contextMenu {
                Button(todo.isDone ? "Mark as Not Done" : "Mark as Done", systemImage: todo.isDone ? "circle" : "checkmark.circle") {
                    toggle(todo)
                }
                Menu("Due Date", systemImage: "calendar") {
                    Button("Today") { setDue(todo, daysFromNow: 0) }
                    Button("Tomorrow") { setDue(todo, daysFromNow: 1) }
                    Button("Next Week") { setDue(todo, daysFromNow: 7) }
                    if todo.dueDate != nil {
                        Button("Remove Date", role: .destructive) { setDue(todo, daysFromNow: nil) }
                    }
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    delete(todo)
                }
            }
    }

    private func undoToast(for todo: TodoItem) -> some View {
        HStack(spacing: 6) {
            Text("Completed")
                .foregroundStyle(.secondary)
            Text(todo.title)
                .lineLimit(1)
            Spacer(minLength: 12)
            Button("Undo") {
                withAnimation(.snappy) {
                    todo.toggle()
                    recentlyCompleted = nil
                }
            }
            .fontWeight(.semibold)
        }
        .font(.subheadline)
        .padding(.horizontal, 18)
        .frame(height: 44)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal)
    }

    // MARK: - Ordering

    /// Dated tasks by due date; undated tasks keep the order they were added.
    private func dueOrder(_ lhs: TodoItem, _ rhs: TodoItem) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (l?, r?): l < r
        default: lhs.createdAt < rhs.createdAt
        }
    }

    // MARK: - Actions

    private func add(_ title: String, due: Date?, isAllDay: Bool) {
        withAnimation(.snappy) {
            modelContext.insert(TodoItem(title: title, dueDate: due, isAllDay: isAllDay))
        }
    }

    private func toggle(_ todo: TodoItem) {
        withAnimation(.snappy) {
            todo.toggle()
            recentlyCompleted = todo.isDone ? todo : nil
        }
    }

    private func setDue(_ todo: TodoItem, daysFromNow: Int?) {
        withAnimation(.snappy) {
            if let daysFromNow {
                let today = Calendar.current.startOfDay(for: .now)
                todo.dueDate = Calendar.current.date(byAdding: .day, value: daysFromNow, to: today)
            } else {
                todo.dueDate = nil
            }
            todo.isAllDay = true
        }
    }

    private func delete(_ todo: TodoItem) {
        withAnimation(.snappy) {
            if recentlyCompleted == todo { recentlyCompleted = nil }
            modelContext.delete(todo)
        }
    }

    private func clearCompleted() {
        withAnimation(.snappy) {
            recentlyCompleted = nil
            for todo in todos where todo.isDone {
                modelContext.delete(todo)
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: TodoItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let samples: [(String, Date?, Bool)] = [
        ("Pay rent", calendar.date(byAdding: .day, value: -1, to: today), true),
        ("Call mom", calendar.date(bySettingHour: 17, minute: 0, second: 0, of: today), false),
        ("Buy groceries", today, true),
        ("Submit report", calendar.date(byAdding: .day, value: 1, to: today), true),
        ("Dentist appointment", calendar.date(byAdding: .day, value: 4, to: today), true),
        ("Read a book", nil, true),
    ]
    for (title, due, isAllDay) in samples {
        container.mainContext.insert(TodoItem(title: title, dueDate: due, isAllDay: isAllDay))
    }
    return ContentView()
        .modelContainer(container)
}
