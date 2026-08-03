import SwiftData
import SwiftUI

struct ContentView: View {
    @Query(sort: \Week.monday) private var weeks: [Week]

    var body: some View {
        AnkerRootView(weeks: weeks)
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
