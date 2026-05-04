import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section {
                NavigationLink("模型管理") { ModelManagerView() }
                NavigationLink("历史记录")  { HistoryView() }
            }
            Section("关于") {
                LabeledContent("版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                Link("Tencent AngelSlim",
                     destination: URL(string: "https://github.com/tencent/AngelSlim")!)
                Link("Hy-MT 模型",
                     destination: URL(string: "https://huggingface.co/AngelSlim")!)
                Link("llama.cpp",
                     destination: URL(string: "https://github.com/ggerganov/llama.cpp")!)
            }
            Section("致谢与许可") {
                Text("本应用使用了 Tencent AngelSlim 工具链对 Hy-MT1.5-1.8B 模型进行量化与转换，并基于 llama.cpp 在设备端进行推理。所有翻译过程均在本地完成，不上传任何文本。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
    }
}
