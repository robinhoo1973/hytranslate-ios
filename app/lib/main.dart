import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'language.dart';
import 'translator.dart';

void main() {
  runApp(const HyTranslateApp());
}

class HyTranslateApp extends StatelessWidget {
  const HyTranslateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HyTranslate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1E88E5),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF1E88E5),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const TranslateScreen(),
    );
  }
}

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});
  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final _service = TranslatorService();
  final _input = TextEditingController();
  Language _source = LanguageCatalog.byId('auto');
  Language _target = LanguageCatalog.byId('en');

  String _output = '';
  String _status = 'Looking for model…';
  bool _busy = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _detectModel();
  }

  Future<void> _detectModel({String? customPath}) async {
    setState(() => _status = customPath != null
        ? 'Loading model…'
        : 'Looking for model…');
    final model = await _service.locateModel(customPath: customPath);
    if (!mounted) return;
    if (model == null) {
      setState(() => _status =
          'No GGUF found. Drop one at <documents>/models/$kDefaultModelFileName or use “Pick model…”.');
    } else {
      final mb = (model.sizeBytes / (1024 * 1024)).toStringAsFixed(1);
      setState(() => _status = 'Model ready · ${model.path}  ($mb MB)');
    }
  }

  Future<void> _pickModel() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gguf'],
    );
    final path = res?.files.single.path;
    if (path == null) return;
    await _detectModel(customPath: path);
  }

  void _swap() {
    if (_source.id == 'auto') return;
    setState(() {
      final s = _source;
      _source = _target;
      _target = s;
    });
  }

  Future<void> _translate() async {
    if (_busy) return;
    final text = _input.text.trim();
    if (text.isEmpty || !_service.hasModel) return;
    setState(() {
      _busy = true;
      _output = '';
    });
    _sub?.cancel();
    _sub = _service
        .translate(source: _source, target: _target, text: text)
        .listen((cumulative) {
      setState(() => _output = cumulative);
    }, onError: (e) {
      setState(() {
        _output = 'Error: $e';
        _busy = false;
      });
    }, onDone: () {
      setState(() => _busy = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('HyTranslate · 离线翻译'),
        actions: [
          IconButton(
            tooltip: 'Pick GGUF model…',
            onPressed: _pickModel,
            icon: const Icon(Icons.folder_open),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LanguageBar(
              source: _source,
              target: _target,
              onSourceChanged: (l) => setState(() => _source = l),
              onTargetChanged: (l) => setState(() => _target = l),
              onSwap: _swap,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _input,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '输入要翻译的文本…',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy || !_service.hasModel ? null : _translate,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.translate),
              label: Text(_busy ? 'Translating…' : 'Translate'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _output.isEmpty ? '译文将出现在这里。' : _output,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(_status, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _LanguageBar extends StatelessWidget {
  final Language source;
  final Language target;
  final ValueChanged<Language> onSourceChanged;
  final ValueChanged<Language> onTargetChanged;
  final VoidCallback onSwap;
  const _LanguageBar({
    required this.source,
    required this.target,
    required this.onSourceChanged,
    required this.onTargetChanged,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LangDropdown(
            value: source,
            options: LanguageCatalog.all,
            onChanged: onSourceChanged,
          ),
        ),
        IconButton(
          tooltip: 'Swap',
          onPressed: source.id == 'auto' ? null : onSwap,
          icon: const Icon(Icons.swap_horiz),
        ),
        Expanded(
          child: _LangDropdown(
            value: target,
            options: LanguageCatalog.targets,
            onChanged: onTargetChanged,
          ),
        ),
      ],
    );
  }
}

class _LangDropdown extends StatelessWidget {
  final Language value;
  final List<Language> options;
  final ValueChanged<Language> onChanged;
  const _LangDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value.id,
      isExpanded: true,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: [
        for (final l in options)
          DropdownMenuItem(
            value: l.id,
            child: Text('${l.displayName} · ${l.nativeName}',
                overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (id) {
        if (id != null) onChanged(LanguageCatalog.byId(id));
      },
    );
  }
}
