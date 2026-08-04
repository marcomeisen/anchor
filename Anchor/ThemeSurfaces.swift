import SwiftUI

/// Eine 2px-Regel. Ersetzt `Divider()` an gezeichneten Kanten — `Divider()` bleibt nur in
/// Menuebodies, wo es der Systemtrenner ist.
struct AnkerRule: View {
    var axis: Axis = .horizontal
    var color: Color = AnkerColor.divider

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(
                width: axis == .vertical ? AnkerBorder.rule : nil,
                height: axis == .horizontal ? AnkerBorder.rule : nil
            )
            .accessibilityHidden(true)
    }
}

extension View {
    /// Eine Flaeche mit Kante. Der Ersatz fuer jedes `.background(.ultraThinMaterial, in:
    /// RoundedRectangle(...))` samt Schatten: nichts schwebt, die Kante macht die Ebene sichtbar.
    func ankerPanel(_ fill: Color = AnkerColor.surface) -> some View {
        background(fill)
            .overlay(
                Rectangle()
                    .stroke(AnkerColor.divider, lineWidth: AnkerBorder.rule)
            )
    }

    /// Eine einzelne Kante statt eines Rahmens — fuer Leisten, die an einer Seite anliegen.
    func ankerEdge(_ edge: Alignment, color: Color = AnkerColor.divider) -> some View {
        overlay(alignment: edge) {
            AnkerRule(
                axis: edge == .leading || edge == .trailing ? .vertical : .horizontal,
                color: color
            )
        }
    }
}

/// Fortschritt als Balken, nicht als Ring.
///
/// Ein Ring ist eine gerundete, geschmueckte Form; das Systemblatt laesst keine zu. Der Balken
/// sagt dasselbe, laesst sich ueber die ganze Breite lesen und braucht keinen zweiten
/// Zahlenwert daneben.
struct AnkerProgressBar: View {
    let progress: Double
    var tint: Color = AnkerColor.accentMark
    var track: Color = AnkerColor.neutral[300]
    /// Vielfache der Regelstaerke: 6 in Listen, 8 als Kennzahl.
    var thickness: CGFloat = AnkerBorder.rule * 3

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(track)
                Rectangle()
                    .fill(tint)
                    .frame(width: proxy.size.width * clamped)
            }
        }
        .frame(height: thickness)
        .accessibilityLabel("\(Int(clamped * 100)) Prozent")
    }
}

/// Schaltflaechen des Systems. Beschriftung buendig links, kein Radius, Zustaende aus der
/// Akzentrampe.
struct AnkerButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet }

    let kind: Kind
    var fillsWidth = false

    static let primary = AnkerButtonStyle(kind: .primary)
    static let secondary = AnkerButtonStyle(kind: .secondary)
    static let quiet = AnkerButtonStyle(kind: .quiet)
    static let primaryBlock = AnkerButtonStyle(kind: .primary, fillsWidth: true)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .ankerType(AnkerType.label)
            .foregroundStyle(foreground(pressed: configuration.isPressed))
            .padding(.horizontal, AnkerSpacing.s3)
            .padding(.vertical, AnkerSpacing.s2 + 2)
            .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
            .background(background(pressed: configuration.isPressed))
            .overlay {
                if kind == .secondary {
                    Rectangle().stroke(AnkerColor.dividerStrong, lineWidth: AnkerBorder.rule)
                }
            }
            .contentShape(Rectangle())
    }

    private func foreground(pressed: Bool) -> Color {
        switch kind {
        case .primary: AnkerColor.onAccent
        case .secondary: AnkerColor.ink
        case .quiet: pressed ? AnkerColor.accent[800] : AnkerColor.accentInk
        }
    }

    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary: pressed ? AnkerColor.accent[700] : AnkerColor.accentFill
        case .secondary: pressed ? AnkerColor.neutral[200] : .clear
        case .quiet: pressed ? AnkerColor.accent[100] : .clear
        }
    }
}

/// Ein Schalter als Quadrat mit Regel — die Systemkapsel hat einen Radius.
struct AnkerToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: AnkerSpacing.s3) {
                configuration.label
                Spacer(minLength: AnkerSpacing.s2)
                ZStack {
                    Rectangle()
                        .stroke(AnkerColor.ink, lineWidth: AnkerBorder.rule)
                        .frame(width: 22, height: 22)
                    if configuration.isOn {
                        Rectangle()
                            .fill(AnkerColor.ink)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? [.isButton, .isSelected] : .isButton)
    }
}
