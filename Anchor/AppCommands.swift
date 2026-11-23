import SwiftUI

/// Was die Menübefehle im vordersten Fenster auslösen dürfen. `AnkerRootView` setzt beides
/// über `.focusedSceneValue`; ohne Fenster (oder im Onboarding) fehlen die Werte, und die
/// Befehle sind ausgegraut.
struct AnkerSceneActions {
    var showSearch: () -> Void
    var startWeek: () -> Void
    var review: () -> Void
}

extension FocusedValues {
    @Entry var ankerNavigation: Binding<AnkerNavigationState>?
    @Entry var ankerSceneActions: AnkerSceneActions?
}

/// Menübefehle des Macs (und der iPad-Tastatur): „Gehe zu" mit Bereichen, Wochen, Suche,
/// Setzen und Rückblick.
///
/// Eingehängt in `AnchorApp` über `.commands { AnkerCommands() }`.
struct AnkerCommands: Commands {
    @FocusedValue(\.ankerNavigation) private var navigation
    @FocusedValue(\.ankerSceneActions) private var actions

    var body: some Commands {
        // ⌘N öffnete ein zweites, leeres Fenster derselben Szene. Erfasst wird in der
        // Erfassungszeile, ein zweites Fenster braucht „Blatt" nicht.
        CommandGroup(replacing: .newItem) {}

        CommandMenu("Gehe zu") {
            Button("Heute") { navigation?.wrappedValue.moveToToday() }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(navigation == nil)
            Button("Woche") { navigation?.wrappedValue.select(.week) }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(navigation == nil)
            Button("Archiv") { navigation?.wrappedValue.select(.archive) }
                .keyboardShortcut("3", modifiers: .command)
                .disabled(navigation == nil)

            Divider()

            // In einer Detailansicht gehört ⌘[ dem Zurück-Knopf (`BlattBackBar`); deshalb sind
            // die Wochenschritte dort ausgegraut statt den Kurzbefehl zu überdecken.
            Button("Vorherige Woche") { navigation?.wrappedValue.moveWeek(by: -1) }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(navigation == nil || navigation?.wrappedValue.isPushed == true)
            Button("Nächste Woche") { navigation?.wrappedValue.moveWeek(by: 1) }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(navigation == nil || navigation?.wrappedValue.isPushed == true)

            Divider()

            Button("Suchen …") { actions?.showSearch() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(actions == nil)

            Divider()

            Button("Anker setzen …") { actions?.startWeek() }
                .disabled(actions == nil)
            Button("Rückblick …") { actions?.review() }
                .disabled(actions == nil)
        }
    }
}
