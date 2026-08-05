import SwiftUI

/// Eine 2px-Regel. Ersetzt `Divider()` an gezeichneten Kanten — `Divider()` bleibt nur in
/// Menuebodies, wo es der Systemtrenner ist.
struct AnkerRule: View {
    /// Wofuer die Linie steht. Die Staerke folgt daraus, sie ist keine freie Wahl.
    enum Weight: Equatable {
        /// Sektionsgrenze: 2px. Trennt Bereiche, die verschiedene Fragen beantworten.
        case section
        /// Trenner **innerhalb** einer Liste: 1px. 2px zwischen jeder Zeile liest sich wie ein
        /// Tabellengitter.
        case row

        var thickness: CGFloat {
            switch self {
            case .section: AnkerBorder.rule
            case .row: AnkerBorder.hairline
            }
        }
    }

    var axis: Axis = .horizontal
    var color: Color = AnkerColor.divider
    var weight: Weight = .section

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(
                width: axis == .vertical ? weight.thickness : nil,
                height: axis == .horizontal ? weight.thickness : nil
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

    /// Eine **Karte**: die Flaeche, auf der eine Liste sitzt.
    ///
    /// Runde 3 nimmt „nichts schwebt" fuer diesen einen Fall zurueck, mit Begruendung aus dem
    /// Entwurf: eine Liste, in der jede Zeile eine 2px-Kante traegt, liest sich wie ein
    /// Tabellengitter. Die Karte fasst die Zeilen zusammen, innen genuegen dann Hairlines.
    ///
    /// Elevation **statt** Rahmen — deshalb kein `stroke`. Zwei Schattenlagen wie im Entwurf: die
    /// enge macht die Kante sichtbar, die weite die Ebene. Im Dunkelmodus traegt die hellere
    /// Kartenflaeche die Ebene, der Schatten bleibt trotzdem und faellt kaum auf.
    /// `elevated: false` fuer eine **getoente Hinweisflaeche** — leerer Zustand, Merksatz,
    /// Statusband. Sie ist rund wie eine Karte, aber sie schwebt nicht: sie traegt keinen Inhalt,
    /// den man anfasst, und der Schatten wuerde ihr ein Gewicht geben, das sie nicht hat.
    func ankerCard(
        fill: Color = AnkerColor.card,
        radius: CGFloat = AnkerRadius.card,
        elevated: Bool = true
    ) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: elevated ? AnkerColor.elevationNear : .clear, radius: 1, x: 0, y: 1)
            .shadow(color: elevated ? AnkerColor.elevationFar : .clear, radius: 6, x: 0, y: 4)
    }

    /// Ein Eingabefeld: gerundet, mit Innenkante statt Schatten. Ein Feld schwebt nicht, man
    /// fasst es an — es ist rund, aber flach.
    func ankerField(radius: CGFloat = AnkerRadius.control) -> some View {
        background(AnkerColor.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AnkerColor.cardDivider, lineWidth: AnkerBorder.hairline)
            )
    }

    /// Ein **Bedienelement** mit eigener Flaeche: Knopf, Auswahlkachel, die Wochenanzeige
    /// zwischen zwei Schrittpfeilen.
    ///
    /// Das Gegenstueck zu `ankerCard()`: eine Karte traegt Inhalt und schwebt, ein Bedienelement
    /// liegt auf und wird angefasst. Beide sind rund, aber nur die Karte bekommt Elevation — hier
    /// bleibt die 2px-Kante, denn sie umreisst ein Objekt, sie trennt keine Zeilen.
    ///
    /// `stroke: nil` fuer die gefuellte Auswahl: eine Kante um eine Akzentflaeche waere eine
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
                    shape.stroke(stroke, lineWidth: AnkerBorder.rule)
                }
            }
            .contentShape(shape)
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
            // 8pt und `.continuous`: ein Knopf ist das, was man anfasst — nach Runde 3 also
            // rund. Die Struktur um ihn herum bleibt scharf.
            .background(background(pressed: configuration.isPressed), in: shape)
            .overlay {
                if kind == .secondary {
                    shape.stroke(AnkerColor.dividerStrong, lineWidth: AnkerBorder.rule)
                }
            }
            .contentShape(shape)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AnkerRadius.control, style: .continuous)
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

/// Ein Schalter als Kaestchen statt als Systemkapsel.
///
/// Es ist **dasselbe** Kaestchen wie an einer Aufgabe (`TaskCheckmark`): 4pt fortlaufend gerundet,
/// 2px Tinte, gefuellt mit Haken. Zwei Formen fuer denselben Ja-Nein-Zustand waeren zwei Aussagen
/// ueber eine Sache — der Nutzer lernt das Kaestchen einmal.
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
                    .overlay(shape.stroke(AnkerColor.ink, lineWidth: AnkerBorder.rule))
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
