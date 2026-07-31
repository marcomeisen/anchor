import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    var body: some View {
        AnkerRootView(weeks: weeks)
            .task {
                seedIfNeeded()
            }
    }

    private func seedIfNeeded() {
        guard weeks.isEmpty else { return }
        SampleData.insertReferenceWeek(in: modelContext)
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        SampleData.insertReferenceWeek(in: container.mainContext)
        return container
    }()
}
