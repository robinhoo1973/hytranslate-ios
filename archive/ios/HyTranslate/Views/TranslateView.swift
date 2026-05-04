import SwiftUI

struct TranslateView: View {
    @StateObject private var vm = TranslationViewModel()
    @State private var showingPicker: PickerTarget?

    enum PickerTarget: Identifiable { case source, target; var id: Int { hashValue } }

    var body: some View {
        VStack(spacing: 0) {
            languageBar
            Divider()
            inputArea
            Divider()
            actionBar
            Divider()
            outputArea
            statusBar
        }
        .navigationTitle("HyTranslate")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $showingPicker) { target in
            LanguagePickerView(selection: target == .source ? $vm.sourceLang : $vm.targetLang,
                               includeAuto: target == .source)
        }
        .alert("出错了", isPresented: .constant(vm.errorMessage != nil), actions: {
            Button("好") { vm.errorMessage = nil }
        }, message: { Text(vm.errorMessage ?? "") })
    }

    private var languageBar: some View {
        HStack {
            Button { showingPicker = .source } label: {
                Label(vm.sourceLang.displayName, systemImage: "chevron.down")
                    .labelStyle(.titleAndIcon)
            }
            Spacer()
            Button { vm.swap() } label: { Image(systemName: "arrow.left.arrow.right") }
                .disabled(vm.sourceLang.id == "auto")
            Spacer()
            Button { showingPicker = .target } label: {
                Label(vm.targetLang.displayName, systemImage: "chevron.down")
            }
        }
        .padding()
        .font(.headline)
    }

    private var inputArea: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $vm.inputText)
                .padding(8)
                .frame(minHeight: 120)
            if vm.inputText.isEmpty {
                Text("输入要翻译的文本…")
                    .foregroundStyle(.tertiary).padding(14)
            }
        }
    }

    private var actionBar: some View {
        HStack {
            Button(role: .destructive) { vm.inputText = "" } label: { Image(systemName: "xmark.circle") }
            Spacer()
            if vm.isTranslating {
                Button("停止", role: .cancel) { vm.cancel() }
                    .buttonStyle(.borderedProminent).tint(.red)
            } else {
                Button { vm.translate() } label: {
                    Label("翻译", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Spacer()
            Button { UIPasteboard.general.string = vm.outputText } label: {
                Image(systemName: "doc.on.doc")
            }.disabled(vm.outputText.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var outputArea: some View {
        ScrollView {
            Text(vm.outputText.isEmpty ? "译文将在此显示" : vm.outputText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(vm.outputText.isEmpty ? .tertiary : .primary)
                .textSelection(.enabled)
                .padding()
        }
        .frame(maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            if vm.isTranslating { ProgressView().controlSize(.small) }
            if vm.lastTPS > 0 {
                Text(String(format: "%.1f tok/s", vm.lastTPS))
            }
            Spacer()
            Text(ModelStore.shared.activeBuildId ?? "未加载模型")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal).padding(.vertical, 6)
    }
}
