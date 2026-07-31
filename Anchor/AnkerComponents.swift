import SwiftUI

struct AnchorGlyph: View {
    var stroke: Color = .white

    var body: some View {
        Image(systemName: "anchor")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(stroke)
            .accessibilityHidden(true)
    }
}

struct AnchorBadge: View {
    var color: Color = AnkerColor.indigo

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(width: 26, height: 26)
            .overlay(AnchorGlyph())
    }
}

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(AnkerColor.muted)
            .textCase(.uppercase)
            .tracking(0.55)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 14)
            .padding(.bottom, 8)
    }
}

struct ProgressRing: View {
    let progress: Double
    var color: Color = AnkerColor.indigo
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle()
                .stroke(AnkerColor.line, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityLabel(Text("\(Int(progress * 100)) Prozent erreicht"))
    }
}

struct GoalBanner: View {
    let label: String
    let title: String
    var badgeColor: Color = AnkerColor.indigo
    var background: LinearGradient = LinearGradient(
        colors: [Color(hex: "#EEF0FF"), Color(hex: "#F7F1E4")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        HStack(spacing: 10) {
            AnchorBadge(color: badgeColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(AnkerColor.indigoDark)
                    .tracking(0.57)
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(AnkerColor.ink)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: AnkerRadius.pill)
                .stroke(Color(hex: "#DCE1FA"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.pill))
        .accessibilityElement(children: .combine)
    }
}

struct PriorityTag: View {
    let priority: Priority

    var color: Color {
        switch priority {
        case .a: AnkerColor.prioA
        case .b: AnkerColor.indigo
        case .c: AnkerColor.muted
        }
    }

    var body: some View {
        Text(priority.label)
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(.white)
            .tracking(0.27)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color, in: RoundedRectangle(cornerRadius: 5))
            .accessibilityLabel("Priorität \(priority.label)")
    }
}

struct TaskCheckmark: View {
    let isDone: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(isDone ? AnkerColor.success : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isDone ? AnkerColor.success : AnkerColor.line, lineWidth: 1.6)
            )
            .overlay {
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 17, height: 17)
            .accessibilityLabel(isDone ? "Erledigt" : "Offen")
    }
}

struct TaskCard: View {
    let task: AnkerTask
    var showPriority = true
    var onToggle: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            if showPriority {
                PriorityTag(priority: task.priority)
                    .padding(.top, 1)
            }

            Button {
                onToggle?()
            } label: {
                TaskCheckmark(isDone: task.isDone)
            }
            .buttonStyle(.plain)
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AnkerColor.ink)
                    .strikethrough(task.isDone, color: AnkerColor.muted)
                    .lineLimit(3)

                if let goal = task.linkedGoal {
                    HStack(spacing: 4) {
                        Image(systemName: "anchor")
                            .font(.system(size: 10, weight: .semibold))
                        Text(goal.title)
                            .lineLimit(1)
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AnkerColor.indigoDark)
                    .accessibilityLabel("Verankert an \(goal.title)")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(AnkerColor.card)
        .overlay(
            RoundedRectangle(cornerRadius: AnkerRadius.card)
                .stroke(AnkerColor.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.card))
        .accessibilityElement(children: .combine)
    }
}

struct WeekDot: View {
    let date: Date
    let isActive: Bool
    let hasGoal: Bool

    private var weekday: String {
        date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.abbreviated))
            .replacing(".", with: "")
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(weekday)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AnkerColor.muted)

            ZStack(alignment: .bottom) {
                Text(date.formatted(.dateTime.day(.twoDigits)))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AnkerColor.ink)
                    .frame(width: 28, height: 28)
                    .background(isActive ? AnkerColor.month[0] : AnkerColor.lineSoft, in: Circle())
                    .overlay {
                        if isActive {
                            Circle()
                                .stroke(AnkerColor.card, lineWidth: 2)
                                .padding(-2)
                            Circle()
                                .stroke(AnkerColor.month[0], lineWidth: 1.5)
                                .padding(-3.5)
                        }
                    }

                if hasGoal {
                    Circle()
                        .fill(AnkerColor.brass)
                        .frame(width: 4, height: 4)
                        .offset(y: 2)
                }
            }
            .frame(width: 32, height: 32)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ChipButton: View {
    let title: String
    var isPrimary = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isPrimary ? AnkerColor.indigoDark : AnkerColor.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isPrimary ? Color(hex: "#EEF0FF") : Color(hex: "#F4F4F7"))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isPrimary ? Color(hex: "#DDE1FA") : AnkerColor.line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}
