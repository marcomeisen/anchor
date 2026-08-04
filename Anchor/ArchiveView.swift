import SwiftData
import SwiftUI

/// Das Archiv: abgeschlossene Wochen als Liste, neueste zuerst.
///
/// Der Entwurf macht daraus einen eigenen **Ort**. Der Grund steht dort ausdrücklich: vergangene
/// Wochen brauchen keinen permanenten Baum in der Sidebar, wenn es einen Eintrag gibt, der sie
/// alle zeigt. Die Zeitschiene bleibt dadurch ein Fenster um die laufende Woche.
struct ArchiveView: View {
    let weeks: [Week]
    var onSelectWeek: (Date) -> Void = { _ in }

    private var entries: [AnkerArchive.Entry] {
        AnkerArchive.entries(in: weeks)
    }

    var body: some View {
        let entries = self.entries

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(entries)

                if entries.isEmpty {
                    Text(verbatim: "Noch keine abgeschlossene Woche. Sobald eine Woche vorbei oder abgeschlossen ist, steht sie hier.")
                        .ankerType(AnkerType.body)
                        .foregroundStyle(AnkerColor.inkSecond)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, AnkerSpacing.s5)
                } else {
                    AnkerRule(color: AnkerColor.ink)

                    ForEach(entries) { entry in
                        ArchiveRow(entry: entry) { onSelectWeek(entry.monday) }
                        AnkerRule(weight: .row)
                    }
                }
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
#if os(iOS)
            .padding(.bottom, AnkerSpacing.bottomBarClearance)
#else
            .padding(.bottom, AnkerSpacing.s5)
#endif
        }
        .background(AnkerColor.ground)
        .navigationTitle("Archiv")
    }

    private func header(_ entries: [AnkerArchive.Entry]) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            Text(verbatim: "Archiv · \(entries.count) \(entries.count == 1 ? "Woche" : "Wochen")")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)
                .padding(.top, AnkerSpacing.s4)

            Text(verbatim: headline(entries))
                .ankerType(AnkerType.title3)
                .foregroundStyle(AnkerColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, AnkerSpacing.s4)
        }
    }

    private func headline(_ entries: [AnkerArchive.Entry]) -> String {
        let held = entries.filter(\.isHeld).count
        guard !entries.isEmpty else { return "Nichts abgeschlossen" }
        return "\(held) von \(entries.count) Wochen gehalten"
    }
}

/// Eine archivierte Woche. Der Fortschritt bleibt sichtbar — das Archiv ist ein Nachschlagewerk,
/// keine Ablage.
private struct ArchiveRow: View {
    let entry: AnkerArchive.Entry
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: AnkerSpacing.s4) {
                VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                    HStack(spacing: AnkerSpacing.s2) {
                        Text(verbatim: AnkerDateFormat.calendarWeek(entry.isoWeek))
                            .ankerType(AnkerType.bodyStrong)
                            .foregroundStyle(AnkerColor.ink)

                        if entry.isHeld {
                            Text(verbatim: "gehalten")
                                .ankerType(AnkerType.microLabel)
                                .foregroundStyle(AnkerColor.onAccent)
                                .padding(.horizontal, AnkerSpacing.s1)
                                .background(AnkerColor.accentFill, in: Rectangle())
                        }

                        if entry.hasReflection {
                            Image(.note)
                                .ankerIcon(AnkerIconSize.xs)
                                .foregroundStyle(AnkerColor.inkTertiary)
                                .help("Mit Rückblickantwort")
                        }
                    }

                    Text(verbatim: entry.span)
                        .ankerType(AnkerType.overline)
                        .foregroundStyle(AnkerColor.inkSecond)
                }

                Spacer(minLength: AnkerSpacing.s2)

                VStack(alignment: .trailing, spacing: AnkerSpacing.s1) {
                    Text(verbatim: "\(entry.heldAnchorCount)/\(entry.anchorCount)")
                        .ankerType(AnkerType.numeric)
                        .foregroundStyle(AnkerColor.ink)
                    Text(verbatim: "Anker")
                        .ankerType(AnkerType.microLabel)
                        .foregroundStyle(AnkerColor.inkSecond)
                }

                VStack(alignment: .trailing, spacing: AnkerSpacing.s1) {
                    Text(verbatim: "\(entry.doneTaskCount)/\(entry.taskCount)")
                        .ankerType(AnkerType.numeric)
                        .foregroundStyle(AnkerColor.ink)
                    Text(verbatim: "Aufgaben")
                        .ankerType(AnkerType.microLabel)
                        .foregroundStyle(AnkerColor.inkSecond)
                }
            }
            .padding(.vertical, AnkerSpacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("archiveRow.\(entry.isoWeek)")
        .accessibilityLabel(entry.accessibilityLabel)
        .accessibilityHint("Öffnet die Woche")
    }
}
