import SwiftUI

// Die Fensterrahmung des iPhones — eigene Bausteine statt der Systemleiste.
//
// Warum überhaupt: seit iOS 26 zeichnet die Navigationsleiste ihre Elemente in schwebende
// Glaskapseln. Das ist die Sprache, die der Neuentwurf ersetzt hat, und sie lässt sich nicht
// abstellen: `toolbarBackground`, `UINavigationBarAppearance` und `UIBarButtonItemAppearance`
// wurden gemessen, keines davon greift auf die Kapseln durch. Gemessen wurde außerdem ein
// Rückschritt — mit gesetzter Appearance verschwand der große Blatt-Titel ersatzlos.
//
// Der Mac behält die Systemleiste. Dort ist sie nicht aus Glas, sie trägt die Fensterknöpfe,
// und es gibt keine Entwurfsvorlage, die etwas anderes verlangt.

#if os(iOS)

/// Ein Aktionsknopf in der Kopfzeile. 44pt, weil das Apples Mindestziel ist und der Entwurf es
/// in der Spalte „Mehr als Radius" ausdrücklich nennt.
struct AnkerHeaderButton: View {
    let icon: AnkerIcon
    let label: LocalizedStringKey
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(icon)
                .ankerIcon(AnkerIconSize.m)
                .foregroundStyle(isDisabled ? AnkerColor.inkTertiary : AnkerColor.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(label)
    }
}

/// Die Kopfzeile eines obersten Bildschirms: **nur Aktionen**, kein Titel und keine eigene Kante.
///
/// Beides bewusst. Der Entwurf zeichnet auf dem iPhone gar keine Titelleiste — oben steht die
/// Datumszeile des Inhalts mit ihrer 2px-Kante, und wie der Bildschirm heißt, sagt die Tableiste
/// unten. Ein Titel „Heute" über einer Tableiste, die „Heute" hervorhebt, wäre dieselbe Aussage
/// zweimal; eine zweite 2px-Kante 60pt über der ersten wäre ein Gitter.
struct AnkerPhoneHeader<Actions: View>: View {
    /// Gesetzt, sobald eine Detailansicht auf dem Stapel liegt.
    ///
    /// Ohne die Systemleiste gibt es sonst **keinen** Weg zurueck: `GoalDetailView` hat keine
    /// eigene Schliessen-Schaltflaeche und haette als Sackgasse geendet. Die Wischgeste allein
    /// zaehlt nicht — sie ist unsichtbar.
    var showsBack = false
    @ViewBuilder let actions: () -> Actions

    /// Ueber die Umgebung, **nicht** ueber eine hereingereichte Closure.
    ///
    /// Der Baustein von `navigationDestination` ist escapend: er faengt eine Momentaufnahme der
    /// Wurzelansicht ein, und ein `navigation.popToTopLevel()` darin schreibt in diese Kopie
    /// statt in den lebenden Zustand — der Knopf tat sichtbar nichts. `dismiss` geht an den
    /// Stapel selbst; die Wegnahme laeuft dann durch dieselbe Bindung wie jede andere.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 0) {
            if showsBack {
                AnkerHeaderButton(icon: .chevronLeft, label: "Zurück") { dismiss() }
            }
            Spacer(minLength: 0)
            actions()
        }
        .padding(.horizontal, AnkerSpacing.s3)
        .background(AnkerColor.ground)
    }
}

/// Titel und Kopfzeile eines Blatts.
///
/// Anders als ein oberster Bildschirm hat ein Blatt keine eigene erste Zeile, an der man es
/// erkennt — es braucht seinen Namen und die 2px-Kante darunter selbst.
struct AnkerSheetHeader: View {
    let title: LocalizedStringKey
    var cancel: AnkerSheetAction?
    var confirm: AnkerSheetAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let cancel {
                    Button(cancel.title, action: cancel.perform)
                        .buttonStyle(AnkerButtonStyle.quiet)
                }

                Spacer(minLength: AnkerSpacing.s3)

                if let confirm {
                    Button(confirm.title, action: confirm.perform)
                        .buttonStyle(AnkerButtonStyle.primary)
                        .disabled(confirm.isDisabled)
                        .opacity(confirm.isDisabled ? 0.45 : 1)
                }
            }
            .padding(.horizontal, AnkerSpacing.s3)
            .padding(.top, AnkerSpacing.s2)

            Text(title)
                .ankerType(AnkerType.title3)
                .foregroundStyle(AnkerColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AnkerSpacing.screenPadding)
                .padding(.top, AnkerSpacing.s2)
                .padding(.bottom, AnkerSpacing.s3)
        }
        .background(AnkerColor.ground)
        .ankerEdge(.bottom, color: AnkerColor.ink)
    }
}

#endif

/// Eine Aktion in der Kopfzeile eines Blatts. Plattformneutral, damit die Aufrufstelle keine
/// Fallunterscheidung braucht.
struct AnkerSheetAction {
    let title: LocalizedStringKey
    var isDisabled = false
    let perform: () -> Void

    init(_ title: LocalizedStringKey, isDisabled: Bool = false, perform: @escaping () -> Void) {
        self.title = title
        self.isDisabled = isDisabled
        self.perform = perform
    }
}

extension View {
    /// Die Rahmung eines Blatts — **eine** Aufrufstelle je Blatt, die Plattformweiche steckt hier.
    ///
    /// Auf dem iPhone ersetzt sie die Systemleiste durch `AnkerSheetHeader`; auf dem Mac bleibt
    /// alles beim System. Wer das später auch auf dem Mac umstellen will, ändert diese Funktion
    /// und keine Aufrufstelle.
    @ViewBuilder
    func ankerSheetChrome(
        _ title: LocalizedStringKey,
        cancel: AnkerSheetAction? = nil,
        confirm: AnkerSheetAction? = nil
    ) -> some View {
#if os(iOS)
        self
            .safeAreaInset(edge: .top, spacing: 0) {
                AnkerSheetHeader(title: title, cancel: cancel, confirm: confirm)
            }
            .toolbar(.hidden, for: .navigationBar)
#else
        self
            .navigationTitle(title)
            .toolbar {
                if let cancel {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(cancel.title, action: cancel.perform)
                    }
                }
                if let confirm {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(confirm.title, action: confirm.perform)
                            .disabled(confirm.isDisabled)
                    }
                }
            }
#endif
    }
}
