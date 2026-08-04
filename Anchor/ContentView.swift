import SwiftData
import SwiftUI

struct ContentView: View {
    @Query(sort: \Week.monday) private var weeks: [Week]

    @AppStorage(AppSettingsKey.appearance) private var appearanceRaw = AppearanceMode.system.rawValue

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        AnkerRootView(weeks: weeks)
            // Genau einmal an der Wurzel: fehlgeschlagene Speichervorgaenge landen sonst
            // in keiner Anzeige und die Aenderung waere beim naechsten Start still weg.
            .persistenceFailureAlert()
            .preferredColorScheme(appearance.colorScheme)
            // `preferredColorScheme` deckt SwiftUI-Fenster ab. Auf macOS zieht `apply()`
            // zusaetzlich `NSApp.appearance` nach, woran die Farbtokens und das
            // Statusbar-Popover haengen.
            .onAppear { appearance.apply() }
            .onChange(of: appearanceRaw) { _, _ in appearance.apply() }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewContainer.shared)
}

enum PreviewContainer {
    @MainActor
    static var shared: ModelContainer = {
        let schema = Schema(AnkerSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        SampleData.insertReferenceWeek(in: container.mainContext)
        return container
    }()
}
