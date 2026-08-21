import SwiftUI
import SwiftData

struct JournalEntryList: View {
    let entries: [JournalEntryRecord]
    var onDelete: (JournalEntryRecord) -> Void

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("今日手记历史")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .padding(.leading, 2)
                
                VStack(spacing: 8) {
                    ForEach(entries) { entry in
                        JournalEntryCard(entry: entry, onDelete: {
                            onDelete(entry)
                        })
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}
