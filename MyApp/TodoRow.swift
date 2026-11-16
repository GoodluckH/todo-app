import SwiftUI

struct TodoRow: View {
    let todo: TodoItem
    let onToggle: () -> Void

    /// Plays the completion animation before the task leaves the list.
    @State private var isChecking = false

    private var isChecked: Bool { todo.isDone || isChecking }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: check) {
                CheckCircle(isOn: isChecked)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(todo.isDone ? "Mark as not done" : "Mark as done")

            VStack(alignment: .leading, spacing: 3) {
                StrikeText(todo.title, isStruck: isChecked)

                if let due = todo.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(DueFormat.label(for: due, isAllDay: todo.isAllDay))
                    }
                    .font(.footnote)
                    .foregroundStyle(todo.isOverdue() && !isChecked ? Color.red : Color.secondary)
                    .animation(.easeOut(duration: 0.25), value: isChecked)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        // A soft tap the instant the check lands; the list plays a success haptic as the row leaves.
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.9), trigger: isChecking) { _, new in new }
        .sensoryFeedback(.impact(weight: .light), trigger: todo.isDone) { old, new in old && !new }
    }

    private func check() {
        guard !todo.isDone else {
            onToggle()
            return
        }
        guard !isChecking else { return }
        isChecking = true
        Task {
            // Long enough for the fill, checkmark, ripple, and strikethrough to finish.
            try? await Task.sleep(for: .milliseconds(650))
            onToggle()
            isChecking = false
        }
    }
}

/// Completion indicator: a thin ring that pops into a solid circle, draws a checkmark, and sends out a ripple.
struct CheckCircle: View {
    let isOn: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rippleCount = 0

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.tertiary, lineWidth: 1.5)
                .opacity(isOn ? 0 : 1)

            Circle()
                .fill(.primary)
                .scaleEffect(isOn ? 1 : 0.3)
                .opacity(isOn ? 1 : 0)
                .animation(.spring(response: 0.32, dampingFraction: 0.5), value: isOn)

            Checkmark()
                .trim(from: 0, to: isOn ? 1 : 0)
                .stroke(Color(.systemBackground), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .animation(isOn ? .easeOut(duration: 0.22).delay(0.1) : .easeIn(duration: 0.12), value: isOn)

            Ripple(trigger: rippleCount)
        }
        .frame(width: 22, height: 22)
        .animation(.easeOut(duration: 0.15), value: isOn)
        // Enlarge the tap target without affecting layout.
        .padding(10)
        .contentShape(.rect)
        .padding(-10)
        .onChange(of: isOn) { _, isOn in
            if isOn && !reduceMotion {
                rippleCount += 1
            }
        }
    }
}

/// A thin ring that expands and fades each time `trigger` changes.
private struct Ripple: View {
    let trigger: Int

    private struct Values {
        var scale = 1.0
        var opacity = 0.0
    }

    var body: some View {
        Circle()
            .stroke(.primary, lineWidth: 1.5)
            .keyframeAnimator(initialValue: Values(), trigger: trigger) { content, value in
                content
                    .scaleEffect(value.scale)
                    .opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    LinearKeyframe(1.0, duration: 0.05)
                    CubicKeyframe(2.1, duration: 0.5)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0.45, duration: 0.05)
                    CubicKeyframe(0, duration: 0.5)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A short checkmark sized to its frame, drawn as a single stroke so it can be trimmed on.
private struct Checkmark: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.30, y: rect.height * 0.52))
            path.addLine(to: CGPoint(x: rect.width * 0.44, y: rect.height * 0.66))
            path.addLine(to: CGPoint(x: rect.width * 0.71, y: rect.height * 0.37))
        }
    }
}

/// Text whose strikethrough sweeps in left to right, fading the text to secondary as it passes.
private struct StrikeText: View {
    let text: String
    let isStruck: Bool

    init(_ text: String, isStruck: Bool) {
        self.text = text
        self.isStruck = isStruck
    }

    var body: some View {
        let progress = isStruck ? 1.0 : 0.0

        Text(text)
            .foregroundStyle(.primary)
            .mask {
                Rectangle().scaleEffect(x: 1 - progress, anchor: .trailing)
            }
            .overlay {
                Text(text)
                    .strikethrough(color: .secondary)
                    .foregroundStyle(.secondary)
                    .mask {
                        Rectangle().scaleEffect(x: progress, anchor: .leading)
                    }
            }
            .animation(.easeInOut(duration: 0.35).delay(isStruck ? 0.12 : 0), value: isStruck)
            .accessibilityLabel(text)
    }
}

/// Squishes slightly while pressed.
private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.82 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
