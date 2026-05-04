import 'dart:async';
import 'dart:io';

import 'package:fllama/fllama.dart';
import 'package:path_provider/path_provider.dart';

import 'language.dart';
import 'prompt.dart';

/// File name expected at `<app documents>/models/<this>` for the bundled
/// Hy-MT1.5 1.8B Q3_K_M build produced by `tools/convert_hy_mt_to_gguf.sh`.
const String kDefaultModelFileName = 'hy-mt-1.8b.Q3_K_M.gguf';

/// Resolved location for the GGUF on disk, plus a friendly display name.
class ResolvedModel {
  final String path;
  final int sizeBytes;
  ResolvedModel(this.path, this.sizeBytes);
}

/// Translation backend. Loads a GGUF with fllama (native llama.cpp) and
/// streams tokens back to UI.
class TranslatorService {
  TranslatorService();

  String? _activeModelPath;
  String? get activeModelPath => _activeModelPath;
  bool get hasModel => _activeModelPath != null;

  /// Search order:
  ///   1. explicit `customPath` (set via Pick model… in UI)
  ///   2. `<app documents>/models/<kDefaultModelFileName>`
  Future<ResolvedModel?> locateModel({String? customPath}) async {
    final candidates = <String>[];
    if (customPath != null && customPath.isNotEmpty) candidates.add(customPath);
    final docs = await getApplicationDocumentsDirectory();
    candidates.add('${docs.path}/models/$kDefaultModelFileName');

    for (final p in candidates) {
      final f = File(p);
      if (await f.exists()) {
        final st = await f.stat();
        _activeModelPath = p;
        return ResolvedModel(p, st.size);
      }
    }
    return null;
  }

  /// Stream the translation token-by-token. Yields the cumulative text so
  /// the UI can simply assign it to a TextField.
  Stream<String> translate({
    required Language source,
    required Language target,
    required String text,
  }) {
    final ctrl = StreamController<String>();
    final modelPath = _activeModelPath;
    if (modelPath == null) {
      ctrl.addError(StateError('No model loaded'));
      ctrl.close();
      return ctrl.stream;
    }

    final prompt = PromptBuilder.translation(
        source: source, target: target, text: text);

    final request = OpenAiRequest(
      maxTokens: 512,
      // Bypass fllama's chat templating — we feed the raw prompt so the
      // Hy-MT special tokens land verbatim.
      messages: [Message(Role.user, prompt)],
      numGpuLayers: 99,
      modelPath: modelPath,
      frequencyPenalty: 0.0,
      presencePenalty: 1.1,
      topP: 0.9,
      contextSize: 2048,
      temperature: 0.2,
    );

    fllamaChat(request, (response, _, done) {
      if (!ctrl.isClosed) ctrl.add(response);
      if (done && !ctrl.isClosed) ctrl.close();
    });

    return ctrl.stream;
  }
}
