import SwiftUI

/// Die Tableiste des iPhones: Heute, Woche, Archiv — Text, die Auswahl unterstrichen.
struct AnkerTabBar: View {
    @Binding var selection: AppDestination

    var body: some View {
        HStack(spacing: 0) {
            tab(.today, title: "Heute")
            tab(.week, title: "Woche")
            tab(.archive, title: "Archiv")
        }
        .padding(.horizontal, AnkerSpacing.s4)
        .padding(.top, AnkerSpacing.s1)
        .background(AnkerColor.ground)
        .overlay(alignment: .top) { AnkerRule() }
        .accessibilityElement(children: .contain)
    }

    private func isSelected(_ destination: AppDestination) -> Bool {
        switch (selection, destination) {
        case (.year, .archive), (.review, .archive): true
        default: selection == destination
        }
    }

    private func tab(_ destination: AppDestination, title: LocalizedStringKey) -> some View {
        let isOn = isSelected(destination)
        return Button {
            selection = destination
        } label: {
            Text(title)
                .ankerType(isOn ? AnkerType.label : AnkerType.meta)
                .foregroundStyle(isOn ? AnkerColor.ink : AnkerColor.inkSecond)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(alignment: .bottom) {
                    if isOn {
                        Rectangle().fill(AnkerColor.ink).frame(height: 2)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
