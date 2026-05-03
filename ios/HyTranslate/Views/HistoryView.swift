import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \TranslationRecord.createdAt, order: .reverse) private var records: [TranslationRecord]
    @Environment(\.modelContext) private var ctx
    @State private var query = ""

    var body: some View {
        List {
            ForEach(filtered) { r in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(LanguageCatalog.by(id: r.sourceLangId).displayName) → \(LanguageCatalog.by(id: r.targetLangId).displayName)")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if r.favorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                    }
                    Text(r.sourceText).lineLimit(2)
                    Text(r.translatedText).lineLimit(3).foregroundStyle(.secondary)
                }
                .swipeActions {
                    Button(role: .destructive) { ctx.delete(r) } label: { Label("删除", systemImage: "trash") }
                    Button { r.favorite.toggle() } label: { Label("收藏", systemImage: "star") }.tint(.yellow)
                }
            }
        }
        .searchable(text: $query)
        .navigationTitle("历史记录")
        .overlay {
            if records.isEmpty { ContentUnavailableView("暂无记录", systemImage: "clock") }
        }
    }

    private var filtered: [TranslationRecord] {
        guard !query.isEmpty else { return records }
        return records.filter {
            $0.sourceText.localizedCaseInsensitiveContains(query) ||
            $0.translatedText.localizedCaseInsensitiveContains(query)
        }
    }
}
