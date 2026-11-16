import SwiftUI

/// A due date chosen manually from the picker.
struct DueSelection: Equatable {
    var date: Date
    var isAllDay: Bool
}

/// Floating Liquid Glass bar for adding tasks.
/// Deadlines typed in plain language ("tomorrow at 5pm") are detected live and shown as a chip above the field.
struct InputBar: View {
    let onAdd: (_ title: String, _ due: Date?, _ isAllDay: Bool) -> Void

    @State private var text = ""
    @State private var manualDue: DueSelection?
    /// A detected phrase the user dismissed; it stays part of the title.
    @State private var dismissedPhrase: String?
    @State private var isPickingDate = false
    @FocusState private var isFocused: Bool
    @Namespace private var glassNamespace

    /// What would be saved if the user submitted right now.
    private var draft: (title: String, due: DueSelection?, detectedPhrase: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let manualDue {
            return (trimmed, manualDue, nil)
        }
        if let deadline = DeadlineParser.parse(text), deadline.phrase != dismissedPhrase {
            return (deadline.title, DueSelection(date: deadline.date, isAllDay: deadline.isAllDay), deadline.phrase)
        }
        return (trimmed, nil, nil)
    }

    var body: some View {
        let draft = draft

        GlassEffectContainer(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                if let due = draft.due {
                    dueChip(due)
                        .transition(.blurReplace)
                }

                HStack(spacing: 10) {
                    field(hasDue: draft.due != nil)
                    if !draft.title.isEmpty {
                        sendButton
                    }
                }
            }
        }
        .animation(.bouncy(duration: 0.35), value: draft.title.isEmpty)
        .animation(.snappy, value: draft.due)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .onChange(of: text) {
            // Typing a different date phrase should be detected again.
            if let dismissedPhrase, !text.contains(dismissedPhrase) {
                self.dismissedPhrase = nil
            }
        }
        .sheet(isPresented: $isPickingDate) {
            DueDatePicker(initial: draft.due) { manualDue = $0 }
        }
    }

    // MARK: - Subviews

    private func field(hasDue: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
                .foregroundStyle(isFocused ? .primary : .secondary)
                .accessibilityHidden(true)

            TextField("Try “Call mom tomorrow at 5pm”", text: $text)
                .focused($isFocused)
                .submitLabel(.return)
                .onSubmit(submit)

            Button("Set Due Date", systemImage: "calendar") {
                isPickingDate = true
            }
            .labelStyle(.iconOnly)
            .foregroundStyle(hasDue ? .primary : .secondary)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .frame(height: 50)
        .glassEffect(.regular.interactive(), in: .capsule)
        .glassEffectID("field", in: glassNamespace)
    }

    private var sendButton: some View {
        Button(action: submit) {
            Image(systemName: "arrow.up")
                .font(.body.weight(.bold))
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 50, height: 50)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(.primary).interactive(), in: .circle)
        .glassEffectID("send", in: glassNamespace)
        .accessibilityLabel("Add task")
    }

    private func dueChip(_ due: DueSelection) -> some View {
        HStack(spacing: 8) {
            Button {
                isPickingDate = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text(DueFormat.label(for: due.date, isAllDay: due.isAllDay))
                        .contentTransition(.opacity)
                }
            }

            Button("Remove Due Date", systemImage: "xmark", action: clearDue)
                .labelStyle(.iconOnly)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(DueFormat.isPast(due.date, isAllDay: due.isAllDay) ? Color.red : Color.primary)
        .padding(.horizontal, 14)
        .frame(height: 36)
        .glassEffect(.regular.interactive(), in: .capsule)
        .glassEffectID("chip", in: glassNamespace)
    }

    // MARK: - Actions

    private func clearDue() {
        if manualDue != nil {
            manualDue = nil
        } else {
            dismissedPhrase = draft.detectedPhrase
        }
    }

    private func submit() {
        let draft = draft
        guard !draft.title.isEmpty else { return }
        onAdd(draft.title, draft.due?.date, draft.due?.isAllDay ?? true)
        text = ""
        manualDue = nil
        dismissedPhrase = nil
        // Keep the keyboard up so several tasks can be added in a row.
        isFocused = true
    }
}

/// Sheet for picking a due date by hand, with an optional time.
struct DueDatePicker: View {
    let onSave: (DueSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var includesTime: Bool

    init(initial: DueSelection?, onSave: @escaping (DueSelection) -> Void) {
        self.onSave = onSave
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
        _date = State(initialValue: initial?.date ?? tomorrow)
        _includesTime = State(initialValue: initial.map { !$0.isAllDay } ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)

                Toggle("Time", isOn: $includesTime.animation())

                if includesTime {
                    DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute)
                }
            }
            .navigationTitle("Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) {
                        let day = includesTime ? date : Calendar.current.startOfDay(for: date)
                        onSave(DueSelection(date: day, isAllDay: !includesTime))
                        dismiss()
                    }
                }
            }
        }
    }
}
