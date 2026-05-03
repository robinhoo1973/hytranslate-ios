import Foundation

struct ModelManifest: Decodable {
    let baseURL: String
    let defaultForRamGB: DefaultMap
    let builds: [Build]

    struct DefaultMap: Decodable {
        let ge4: String
        let lt4: String
        enum CodingKeys: String, CodingKey { case ge4 = "ge_4", lt4 = "lt_4" }
    }
    struct Build: Decodable, Identifiable {
        let id: String
        let file: String
        let sizeBytes: Int64
        let sha256: String
        let minRamMB: Int
        let label: String
        enum CodingKeys: String, CodingKey {
            case id, file, label
            case sizeBytes = "size_bytes"
            case sha256
            case minRamMB = "min_ram_mb"
        }
    }

    enum CodingKeys: String, CodingKey {
        case baseURL = "base_url"
        case defaultForRamGB = "default_for_ram_gb"
        case builds
    }
}

/// Owns the on-disk model files and remembers the user's active selection.
@MainActor
final class ModelStore: ObservableObject {
    static let shared = ModelStore()

    @Published private(set) var manifest: ModelManifest?
    @Published private(set) var installed: Set<String> = []   // build ids on disk
    @Published var activeBuildId: String? {
        didSet { UserDefaults.standard.set(activeBuildId, forKey: "activeBuildId") }
    }
    @Published var downloadProgress: [String: Double] = [:]   // 0...1 per build id

    private var tasks: [String: URLSessionDownloadTask] = [:]
    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.allowsCellularAccess = false      // models are large; require Wi-Fi
        cfg.waitsForConnectivity = true
        return URLSession(configuration: cfg, delegate: nil, delegateQueue: .main)
    }()

    private init() {
        loadManifest()
        rescanInstalled()
        activeBuildId = UserDefaults.standard.string(forKey: "activeBuildId") ?? recommendedBuildId()
    }

    // MARK: - Paths

    private var modelsDir: URL {
        let base = try! FileManager.default.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func localURL(for build: ModelManifest.Build) -> URL {
        modelsDir.appendingPathComponent(build.file)
    }

    /// Active model file path for the inference engine.
    func activeModelURL() -> URL? {
        guard let id = activeBuildId,
              let build = manifest?.builds.first(where: { $0.id == id }) else { return nil }
        let url = localURL(for: build)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Manifest

    private func loadManifest() {
        guard let url = Bundle.main.url(forResource: "model_manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return }
        manifest = try? JSONDecoder().decode(ModelManifest.self, from: data)
    }

    private func rescanInstalled() {
        guard let manifest else { return }
        installed = Set(manifest.builds
            .filter { FileManager.default.fileExists(atPath: localURL(for: $0).path) }
            .map(\.id))
    }

    // MARK: - Recommendation

    /// Picks the best build for this device based on physical RAM.
    func recommendedBuildId() -> String? {
        guard let manifest else { return nil }
        let ramGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        return ramGB >= 4 ? manifest.defaultForRamGB.ge4 : manifest.defaultForRamGB.lt4
    }

    // MARK: - Download

    func download(_ build: ModelManifest.Build) {
        guard let manifest, tasks[build.id] == nil else { return }
        let url = URL(string: "\(manifest.baseURL)/\(build.file)")!
        downloadProgress[build.id] = 0

        let task = session.downloadTask(with: url) { [weak self] tmp, _, err in
            guard let self else { return }
            self.tasks[build.id] = nil
            self.downloadProgress[build.id] = nil
            guard err == nil, let tmp else { return }
            let dest = self.localURL(for: build)
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.moveItem(at: tmp, to: dest)
            // TODO: verify build.sha256 before flipping installed.
            self.installed.insert(build.id)
            if self.activeBuildId == nil { self.activeBuildId = build.id }
        }
        // Progress observation (KVO).
        task.progress.publisher(for: \.fractionCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] p in self?.downloadProgress[build.id] = p }
            .store(in: &cancellables)
        tasks[build.id] = task
        task.resume()
    }

    func delete(_ build: ModelManifest.Build) {
        try? FileManager.default.removeItem(at: localURL(for: build))
        installed.remove(build.id)
        if activeBuildId == build.id { activeBuildId = nil }
    }

    private var cancellables = Set<AnyCancellable>()
}

// Combine import shim so the file compiles without an extra import header.
import Combine
