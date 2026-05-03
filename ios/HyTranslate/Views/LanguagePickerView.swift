import SwiftUI

struct LanguagePickerView: View {
    @Binding var selection: Language
    let includeAuto: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(filtered) { lang in
                Button {
                    selection = lang
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(lang.displayName)
                            Text(lang.nativeName).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if lang.id == selection.id { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                }
            }
            .searchable(text: $query, prompt: "搜索语言")
            .navigationTitle("选择语言")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }

    private var filtered: [Language] {
        let pool = includeAuto ? LanguageCatalog.all : LanguageCatalog.targets
        guard !query.isEmpty else { return pool }
        return pool.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
            $0.nativeName.localizedCaseInsensitiveContains(query) ||
            $0.id.localizedCaseInsensitiveContains(query)
        }
    }
}
