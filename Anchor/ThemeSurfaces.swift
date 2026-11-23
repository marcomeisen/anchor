import SwiftUI

/// Eine Haarlinie. Ersetzt `Divider()` an gezeichneten Kanten — `Divider()` bleibt nur in
/// Menuebodies, wo es der Systemtrenner ist.
///
/// In „Blatt" ist jede Linie 1pt. `Weight` bleibt als Aussage erhalten: eine Bereichsgrenze
/// nimmt die etwas kräftigere `divider`-Farbe, ein Zeilentrenner die leisere `cardDivider`.
struct AnkerRule: View {
    enum Weight: Equatable {
        /// Grenze zwischen Bereichen.
        case section
        /// Trenner innerhalb einer Liste.
        case row

        var thickness: CGFloat { AnkerBorder.hairline }
    }

    var axis: Axis = .horizontal
    var color: Color?
    var weight: Weight = .section

    private var resolvedColor: Color {
        color ?? (weight == .section ? AnkerColor.divider : AnkerColor.cardDivider)
    }

    var body: some View {
        Rectangle()
            .fill(resolvedColor)
            .frame(
                width: axis == .vertical ? weight.thickness : nil,
                height: axis == .horizontal ? weight.thickness : nil
            )
            .accessibilityHidden(true)
    }
}

extension View {
    /// Eine Fläche mit Kante — für Leisten und Bänder, die über die ganze Breite laufen.
    func ankerPanel(_ fill: Color = AnkerColor.surface) -> some View {
        background(fill)
            .overlay(Rectangle().stroke(AnkerColor.divider, lineWidth: AnkerBorder.hairline))
    }

    /// Eine **Karte**: weiße Fläche, Haarlinie, 14pt fortlaufend gerundet. Sie schwebt nicht —
    /// die Kante macht die Ebene sichtbar.
    ///
    /// `elevated: false` für eine **getönte Hinweisfläche** ohne Rahmen.
    func ankerCard(
        fill: Color = AnkerColor.card,
        radius: CGFloat = AnkerRadius.card,
        elevated: Bool = true
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(fill, in: shape)
            .overlay {
                if elevated {
                    shape.strokeBorder(AnkerColor.divider, lineWidth: AnkerBorder.hairline)
                }
            }
    }

    /// Der gestrichelte Rahmen für alles, was noch keinen festen Platz hat: „Ohne Anker",
    /// „Noch ohne Tag".
    func ankerLooseArea(radius: CGFloat = AnkerRadius.card) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(AnkerColor.dividerStrong, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
    }

    /// Ein Eingabefeld: weiß, Haarlinie.
    func ankerField(radius: CGFloat = AnkerRadius.control) -> some View {
        background(AnkerColor.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(AnkerColor.divider, lineWidth: AnkerBorder.hairline)
            )
    }

    /// Ein **Bedienelement** mit eigener Fläche: Knopf, Auswahlkachel, Schrittschalter.
    ///
    /// `stroke: nil` für die gefüllte Auswahl.
    func ankerControl(
        fill: Color = AnkerColor.card,
        stroke: Color? = AnkerColor.divider,
        radius: CGFloat = AnkerRadius.control
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(fill, in: shape)
            .overlay {
                if let stroke {
                    shape.strokeBorder(stroke, lineWidth: AnkerBorder.hairline)
                }
            }
            .contentShape(shape)
    }

    /// Eine einzelne Kante statt eines Rahmens — für Leisten, die an einer Seite anliegen.
    func ankerEdge(_ edge: Alignment, color: Color = AnkerColor.divider) -> some View {
        overlay(alignment: edge) {
            AnkerRule(
                axis: edge == .leading || edge == .trailing ? .vertical : .horizontal,
                color: color
            )
        }
    }

    /// Was man gerade zieht, schwebt — die einzige Stelle mit Schatten.
    func ankerLifted() -> some View {
        shadow(color: AnkerColor.elevationFar, radius: 14, x: 0, y: 10)
    }
}

/// Fortschritt als Balken.
struct AnkerProgressBar: View {
    let progress: Double
    var tint: Color = AnkerColor.accentMark
    var track: Color = AnkerColor.divider
    var thickness: CGFloat = 6

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * clamped)
            }
        }
        .frame(height: thickness)
        .accessibilityLabel("\(Int(clamped * 100)) Prozent")
    }
}

/// Fortschritt als Punkte: ein Punkt pro Aufgabe, erledigt gefüllt.
///
/// Das Kernbild von „Blatt" — eine Aufgabe ist ein Punkt bei ihrem Anker. Ab zwölf Aufgaben
/// wird daraus ein Balken, sonst bricht die Reihe um.
struct AnkerPips: View {
    let done: Int
    let total: Int
    var size: CGFloat = 10

    var body: some View {
        Group {
            if total > 12 {
                AnkerProgressBar(progress: total == 0 ? 0 : Double(done) / Double(total), thickness: size * 0.6)
            } else {
                HStack(spacing: size * 0.35) {
                    ForEach(0..<max(total, 0), id: \.self) { index in
                        RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                            .fill(index < done ? AnkerColor.accentMark : Color.clear)
                            .overlay {
                                if index >= done {
                                    RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                                        .strokeBorder(AnkerColor.inkTertiary, lineWidth: 1.5)
                                }
                            }
                            .frame(width: size, height: size)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(done) von \(total) erledigt")
    }
}

/// Schaltflächen des Systems.
///
/// `primary` ist **Tinte**, nicht Blau: das Blau heißt „erledigt" und „heute" und soll nicht
/// auch noch „hier tippen" heißen.
struct AnkerButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet, accent }

    let kind: Kind
    var fillsWidth = false

    static let primary = AnkerButtonStyle(kind: .primary)
    static let secondary = AnkerButtonStyle(kind: .secondary)
    static let quiet = AnkerButtonStyle(kind: .quiet)
    static let accent = AnkerButtonStyle(kind: .accent)
    static let primaryBlock = AnkerButtonStyle(kind: .primary, fillsWidth: true)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .ankerType(AnkerType.label)
            .foregroundStyle(foreground)
            .padding(.horizontal, AnkerSpacing.s4)
            .frame(minHeight: fillsWidth ? 52 : 40)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .background(background, in: shape)
            .overlay {
                if kind == .secondary {
                    shape.strokeBorder(AnkerColor.divider, lineWidth: AnkerBorder.hairline)
                }
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(shape)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: fillsWidth ? 12 : AnkerRadius.control, style: .continuous)
    }

    private var foreground: Color {
        switch kind {
        case .primary: AnkerColor.onInk
        case .secondary: AnkerColor.ink
        case .quiet: AnkerColor.accentInk
        case .accent: AnkerColor.onAccent
        }
    }

    private var background: Color {
        switch kind {
        case .primary: AnkerColor.ink
        case .secondary: AnkerColor.card
        case .quiet: .clear
        case .accent: AnkerColor.accentFill
        }
    }
}

/// Ein Schalter als Kästchen — dasselbe wie an einer Aufgabe.
struct AnkerToggleStyle: ToggleStyle {
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AnkerRadius.check, style: .continuous)
    }

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: AnkerSpacing.s3) {
                configuration.label
                Spacer(minLength: AnkerSpacing.s2)
                shape
                    .fill(configuration.isOn ? AnkerColor.accentFill : Color.clear)
                    .overlay {
                        if !configuration.isOn {
                            shape.strokeBorder(AnkerColor.ink, lineWidth: AnkerBorder.heavy)
                        }
                    }
                    .overlay {
                        if configuration.isOn {
                            Image(.check)
                                .ankerIcon(AnkerIconSize.xs)
                                .foregroundStyle(AnkerColor.onAccent)
                        }
                    }
                    .frame(width: 22, height: 22)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// Ein Segmentschalter in der Sprache von „Blatt": graue Schiene, die Auswahl als weiße Kachel.
struct AnkerSegmented<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    var accessibilityLabel: String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let isOn = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .ankerType(AnkerType.label)
                        .foregroundStyle(AnkerColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .padding(.horizontal, AnkerSpacing.s3)
                        .background {
                            if isOn {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(AnkerColor.card)
                                    .shadow(color: AnkerColor.elevationNear, radius: 1, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .background(AnkerColor.neutral[300].opacity(0.6), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}
