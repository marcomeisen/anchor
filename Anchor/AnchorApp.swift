//
//  AnchorApp.swift
//  Anchor
//
//  Created by Marco Meisen on 31.07.26.
//

import SwiftUI
import SwiftData

@main
struct AnchorApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(AnkerSchema.models)
        let modelConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)

#if os(macOS)
        MenuBarExtra("Anker", systemImage: "anchor") {
            QuickCapturePopover(goals: SampleDataPreview.week.goals)
        }
        .menuBarExtraStyle(.window)
#endif
    }
}

enum AnkerSchema {
    static let models: [any PersistentModel.Type] = [
        Goal.self,
        Week.self,
        Day.self,
        AnkerTask.self,
        TimeBlock.self
    ]
}

enum SampleDataPreview {
    @MainActor
    static var week: Week {
        let container = PreviewContainer.shared
        let descriptor = FetchDescriptor<Week>()
        return (try? container.mainContext.fetch(descriptor).first) ?? SampleData.insertReferenceWeek(in: container.mainContext)
    }
}
