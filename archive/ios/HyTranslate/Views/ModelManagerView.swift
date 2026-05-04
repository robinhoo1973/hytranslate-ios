import SwiftUI

struct ModelManagerView: View {
    @ObservedObject private var store = ModelStore.shared

    var body: some View {
        List {
            if let manifest = store.manifest {
                Section("可用模型") {
                    ForEach(manifest.builds) { build in row(for: build) }
                }
                Section("说明") {
                    Text("模型权重来自腾讯混元 Hy-MT1.5-1.8B，由 Tencent AngelSlim 工具链压缩转换为 GGUF 格式。仅在 Wi-Fi 下下载。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Text("无法加载模型清单")
            }
        }
        .navigationTitle("模型管理")
    }

    @ViewBuilder
    private func row(for build: ModelManifest.Build) -> some View {
        let installed = store.installed.contains(build.id)
        let progress = store.downloadProgress[build.id]
        let isActive = store.activeBuildId == build.id

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading) {
                    Text(build.label)
                    Text(byteString(build.sizeBytes)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let p = progress {
                    ProgressView(value: p).frame(width: 80)
                } else if installed {
                    Menu {
                        if !isActive { Button("设为当前") { store.activeBuildId = build.id } }
                        Button("删除", role: .destructive) { store.delete(build) }
                    } label: {
                        Label(isActive ? "使用中" : "已安装", systemImage: isActive ? "checkmark.circle.fill" : "circle")
                    }
                } else {
                    Button("下载") { store.download(build) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func byteString(_ b: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: b, countStyle: .file)
    }
}
