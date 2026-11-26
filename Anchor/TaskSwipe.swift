import SwiftUI

#if os(iOS)
import UIKit

/// Wischen an der Aufgabenzeile: nach rechts erledigt (bzw. wieder offen), nach links löschen.
///
/// `.swipeActions` wirkt nur in einer `List`. `TaskCard` steht aber überall in `VStack`s und
/// `ScrollView`s — die Wischaktionen waren deshalb nie erreichbar. Eine Umstellung aller Listen auf
/// `List` hätte Abstände, Karten und das Ziehen auf jedem Bildschirm verändert; diese Geste hängt
/// nur an der Zeile.
///
/// Die Geste ist ein `UIPanGestureRecognizer`, der **nur** beginnt, wenn die Bewegung deutlich
/// waagerecht ist. Senkrechtes Wischen erreicht ihn nie und bleibt beim Scrollen der Liste; ein
/// SwiftUI-`DragGesture` an der Zeile hätte das Scrollen in der `ScrollView` blockiert.
private struct HorizontalPan: UIGestureRecognizerRepresentable {
    var isEnabled: Bool
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        recognizer.isEnabled = isEnabled
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .changed:
            onChanged(translation)
        case .ended:
            onEnded(translation)
        case .cancelled, .failed:
            onEnded(0)
        default:
            break
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 2
        }
    }
}

private struct TaskSwipeModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isEnabled: Bool
    let isDone: Bool
    let onDone: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0

    /// Ab hier löst das Loslassen die Aktion aus.
    private let threshold: CGFloat = 88
    /// Weiter folgt die Zeile dem Finger nicht.
    private let limit: CGFloat = 132

    private var isPastThreshold: Bool { abs(offset) >= threshold }

    func body(content: Content) -> some View {
        content
            // Nur während des Wischens deckend: in losen Bereichen hat die Zeile sonst keinen Grund.
            .background { if offset != 0 { AnkerColor.card } }
            .offset(x: offset)
            .background(alignment: offset >= 0 ? .leading : .trailing) {
                if offset != 0 {
                    revealedAction
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.control, style: .continuous))
            .gesture(HorizontalPan(isEnabled: isEnabled, onChanged: track, onEnded: finish))
            .sensoryFeedback(.impact(weight: .medium), trigger: isPastThreshold) { _, reached in reached }
    }

    /// Erledigt trägt das eine Blau, Löschen die Tinte — keine zweite Farbe.
    private var revealedAction: some View {
        let isDoneSide = offset > 0
        return ZStack(alignment: isDoneSide ? .leading : .trailing) {
            (isDoneSide ? AnkerColor.accentFill : AnkerColor.ink)
            Image(isDoneSide ? (isDone ? AnkerIcon.undo : AnkerIcon.check) : AnkerIcon.delete)
                .ankerIcon(AnkerIconSize.m)
                .foregroundStyle(isDoneSide ? AnkerColor.onAccent : AnkerColor.onInk)
                .opacity(isPastThreshold ? 1 : 0.6)
                .padding(.horizontal, AnkerSpacing.s4)
        }
        .accessibilityHidden(true)
    }

    private func track(_ translation: CGFloat) {
        offset = min(max(translation, -limit), limit)
    }

    private func finish(_ translation: CGFloat) {
        let action: (() -> Void)? = translation >= threshold ? onDone : translation <= -threshold ? onDelete : nil
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.9)) {
            offset = 0
        }
        action?()
    }
}

extension View {
    /// Nach rechts erledigt, nach links löschen — beide mit Undo über den Aufrufer.
    func taskSwipe(isEnabled: Bool, isDone: Bool, onDone: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        modifier(TaskSwipeModifier(isEnabled: isEnabled, isDone: isDone, onDone: onDone, onDelete: onDelete))
    }
}
#endif
