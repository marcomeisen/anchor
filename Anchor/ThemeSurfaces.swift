import SwiftUI

/// Eine gezeichnete Linie. Ersetzt `Divider()` an gezeichneten Kanten — `Divider()` bleibt nur
/// in Menuebodies, wo es der Systemtrenner ist.
///
/// In Lot sind beide Staerken eine Haarlinie; der Unterschied liegt in der **Farbe**. Das ist
/// der Bruch mit dem Modernist-System, wo 2px gegen 1px die Aussage trug: „weiche Radien und
/// Schatten statt 2-px-Linien". Was einen Bereich abgrenzt, tut das jetzt ueber Flaeche und
/// Hoehe — die Linie sagt nur noch, wo etwas endet.
struct AnkerRule: View {
    /// Wofuer die Linie steht. Farbe und Staerke folgen daraus, sie sind keine freie Wahl.
    enum Weight: Equatable {
        /// Abschnittsgrenze: Haarlinie in `LotHairlineStrong`.
        case section
        /// Trenner **innerhalb** einer Liste: Haarlinie in `LotHairline`.
        case row

        var thickness: CGFloat {
            switch self {
            case .section: AnkerBorder.rule
            case .row: AnkerBorder.hairline
            }
        }

        var defaultColor: Color {
            switch self {
            case .section: AnkerColor.divider
            case .row: AnkerColor.cardDivider
            }
        }
    }

    var axis: Axis = .horizontal
    var color: Color?
    var weight: Weight = .section

    var body: some View {
        Rectangle()
            .fill(color ?? weight.defaultColor)
            .frame(
                width: axis == .vertical ? weight.thickness : nil,
                height: axis == .horizontal ? weight.thickness : nil
            )
            .accessibilityHidden(true)
    }
}

extension View {
    /// Hoehe nach Rolle. Zwei Lagen: die enge macht die Kante sichtbar, die weite die Ebene.
    func ankerElevation(_ elevation: AnkerElevation) -> some View {
        // design-guard: erlaubt — hier *entsteht* die Hoehe des Systems.
        layers(of: elevation)
    }

    private func layers(of elevation: AnkerElevation) -> some View {
        elevation.layers.reduce(AnyView(self)) { view, layer in
            AnyView(view.shadow(color: layer.color, radius: layer.radius, x: 0, y: layer.y))
        }
    }

    /// Eine **Karte**: die Flaeche, auf der Inhalt sitzt. Deckend, gerundet, auf Hoehe 1.
    ///
    /// „Naehe entsteht durch Material und Hoehe, nicht durch Rahmen" — deshalb kein `stroke`.
    /// `elevated: false` fuer eine **getoente Hinweisflaeche** (Tempo-Satz, leerer Zustand,
    /// Statusband): rund wie eine Karte, aber ohne Gewicht, weil sie keinen Inhalt traegt, den
    /// man anfasst.
    func ankerCard(
        fill: Color = AnkerColor.card,
        radius: CGFloat = AnkerRadius.card,
        elevated: Bool = true
    ) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .ankerElevation(elevated ? .card : .flat)
    }

    /// **Glas.** Chrome, das ueber Inhalt schwebt: Kopfzeile, Erfassungsleiste, Tableiste, Sheets.
    ///
    /// Die eine Materialregel des Systems, und die einzige Stelle, an der `Material` vorkommen
    /// darf: **nie Inhalt, nie hinter Fliesstext** — „Text auf Glas ist auf Fotos und beim
    /// Scrollen nicht verlaesslich lesbar". Die Lichtkante sitzt innen an der Kante, an der das
    /// Glas an den Inhalt stoesst.
    func ankerGlass(_ edge: Edge.Set = .top, radius: CGFloat = 0) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background {
            // design-guard: erlaubt — hier *entsteht* das Glas des Systems.
            shape.fill(.ultraThinMaterial)
                .overlay(shape.fill(AnkerColor.glassFill))
        }
        .overlay(alignment: edge == .bottom ? .bottom : .top) {
            Rectangle()
                .fill(AnkerColor.glassSheen)
                .frame(height: AnkerBorder.hairline)
                .accessibilityHidden(true)
        }
    }

    /// Ein Eingabefeld: gerundet, eingelassen, mit Haarlinie statt Hoehe. Ein Feld schwebt
    /// nicht, man fasst es an.
    func ankerField(radius: CGFloat = AnkerRadius.control) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(AnkerColor.surface, in: shape)
            .overlay(shape.stroke(AnkerColor.divider, lineWidth: AnkerBorder.hairline))
    }

    /// Ein **Bedienelement** mit eigener Flaeche: Knopf, Auswahlkachel, Schrittschalter-Anzeige.
    ///
    /// `stroke: nil` fuer die gefuellte Auswahl: eine Kante um eine Bernsteinflaeche waere eine
    /// zweite Aussage ueber dieselbe Sache.
    func ankerControl(
        fill: Color = AnkerColor.surface,
        stroke: Color? = AnkerColor.divider,
        radius: CGFloat = AnkerRadius.control
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(fill, in: shape)
            .overlay {
                if let stroke {
                    shape.stroke(stroke, lineWidth: AnkerBorder.hairline)
                }
            }
            .contentShape(shape)
    }

    /// Eine **Pille**: Filter, Zaehler, Marke. Der Entwurf fuehrt sie als eigene Radiusrolle —
    /// sie ist kein Knopf mit viel Radius, sondern eine Form, die sagt „hier steht wenig".
    func ankerPill(fill: Color = AnkerColor.accentTint, stroke: Color? = nil) -> some View {
        background(fill, in: Capsule(style: .continuous))
            .overlay {
                if let stroke {
                    Capsule(style: .continuous).stroke(stroke, lineWidth: AnkerBorder.hairline)
                }
            }
            .contentShape(Capsule(style: .continuous))
    }

    /// Eine Flaeche mit Kante — der Bestandsname des Modernist-Systems.
    ///
    /// In Lot ist das eine eingelassene Flaeche mit Haarlinie: der Fensterkopf, der Eingangskorb,
    /// eine Leiste, die an den Inhalt anschliesst.
    func ankerPanel(_ fill: Color = AnkerColor.surface) -> some View {
        background(fill)
            .overlay(Rectangle().stroke(AnkerColor.divider, lineWidth: AnkerBorder.hairline))
    }

    /// Eine einzelne Kante statt eines Rahmens — fuer Leisten, die an einer Seite anliegen.
    func ankerEdge(_ edge: Alignment, color: Color? = nil) -> some View {
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
/// „Keine Fortschrittsringe." Der Balken ist eines von genau **zwei** Dingen, die in Lot ohne
/// Radius bleiben: ein rundes Ende luegt ueber den Wert. Das andere ist der Wochenpuls.
struct AnkerProgressBar: View {
    let progress: Double
    var tint: Color = AnkerColor.accentFill
    var track: Color = AnkerColor.ground
    /// 4 in Listen, 5 in der Matrix, 8 als Kennzahl.
    var thickness: CGFloat = 4

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

/// Schaltflaechen des Systems.
///
/// Der primaere Knopf ist eine **Bernsteinflaeche mit Tinte darauf** — nicht Papierweiss, das
/// waeren 2,89:1. Beschriftung mittig: in Lot ist ein Knopf ein Objekt, keine Zeile.
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
            .padding(.horizontal, AnkerSpacing.s4)
            .padding(.vertical, AnkerSpacing.s3)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: AnkerSpacing.touchTarget)
            .background(background(pressed: configuration.isPressed), in: shape)
            .overlay {
                if kind == .secondary {
                    shape.stroke(AnkerColor.divider, lineWidth: AnkerBorder.heavy)
                }
            }
            .contentShape(shape)
            // „Bewegung mit Federn." Der Druck ist die kleinste davon.
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.72), value: configuration.isPressed)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AnkerRadius.control, style: .continuous)
    }

    private func foreground(pressed: Bool) -> Color {
        switch kind {
        case .primary: AnkerColor.onAccent
        case .secondary: AnkerColor.ink
        case .quiet: pressed ? AnkerColor.accentMark : AnkerColor.accentInk
        }
    }

    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary: pressed ? AnkerColor.accentMark : AnkerColor.accentFill
        case .secondary: pressed ? AnkerColor.surface : .clear
        case .quiet: pressed ? AnkerColor.accentTint : .clear
        }
    }
}

/// Ein Schalter als Kaestchen statt als Systemkapsel.
///
/// Es ist **dasselbe** Kaestchen wie an einer Aufgabe (`TaskCheckmark`): 8pt fortlaufend
/// gerundet, gefuellt mit Haken. Zwei Formen fuer denselben Ja-Nein-Zustand waeren zwei
/// Aussagen ueber eine Sache — der Nutzer lernt das Kaestchen einmal.
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
                    .fill(configuration.isOn ? AnkerColor.ink : Color.clear)
                    .overlay(shape.stroke(configuration.isOn ? AnkerColor.ink : AnkerColor.divider,
                                          lineWidth: AnkerBorder.heavy))
                    .overlay {
                        if configuration.isOn {
                            Image(.check)
                                .ankerIcon(AnkerIconSize.xs)
                                .foregroundStyle(AnkerColor.card)
                        }
                    }
                    .frame(width: 22, height: 22)
                    .animation(.spring(response: 0.3, dampingFraction: 0.72), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? [.isButton, .isSelected] : .isButton)
    }
}
