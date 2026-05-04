import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Process-wide event bus the running app can post messages to (e.g. when a
/// translation starts, completes, errors). The simulator's log panel listens.
class SimulatorEventBus {
  SimulatorEventBus._();
  static final instance = SimulatorEventBus._();

  final _controller = StreamController<SimulatorEvent>.broadcast();
  Stream<SimulatorEvent> get stream => _controller.stream;

  void emit(String message, {SimulatorEventLevel level = SimulatorEventLevel.info}) {
    _controller.add(SimulatorEvent(message, level: level));
    if (kDebugMode) debugPrint('[sim] ${level.name}: $message');
  }
}

enum SimulatorEventLevel { info, success, warning, error }

class SimulatorEvent {
  final DateTime ts;
  final String message;
  final SimulatorEventLevel level;
  SimulatorEvent(this.message, {this.level = SimulatorEventLevel.info})
      : ts = DateTime.now();
}

/// FPS sampler — counts frames over a 1s rolling window via Ticker.
class FpsCounter extends StatefulWidget {
  const FpsCounter({super.key});
  @override
  State<FpsCounter> createState() => _FpsCounterState();
}

class _FpsCounterState extends State<FpsCounter>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _stamps = <Duration>[];
  double _fps = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    _stamps.add(elapsed);
    final cutoff = elapsed - const Duration(seconds: 1);
    while (_stamps.isNotEmpty && _stamps.first < cutoff) {
      _stamps.removeAt(0);
    }
    if (_stamps.length % 6 == 0 && mounted) {
      setState(() => _fps = _stamps.length.toDouble());
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _fps >= 55
        ? Colors.greenAccent
        : (_fps >= 30 ? Colors.yellowAccent : Colors.redAccent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('${_fps.toStringAsFixed(0)} fps',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          )),
    );
  }
}

/// Slide-in log panel that mirrors `SimulatorEventBus` events.
class EventLogPanel extends StatefulWidget {
  final double width;
  const EventLogPanel({super.key, this.width = 320});
  @override
  State<EventLogPanel> createState() => _EventLogPanelState();
}

class _EventLogPanelState extends State<EventLogPanel> {
  final _events = <SimulatorEvent>[];
  StreamSubscription<SimulatorEvent>? _sub;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _sub = SimulatorEventBus.instance.stream.listen((e) {
      setState(() {
        _events.add(e);
        if (_events.length > 200) _events.removeAt(0);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Color _color(SimulatorEventLevel l) {
    switch (l) {
      case SimulatorEventLevel.info:
        return Colors.white70;
      case SimulatorEventLevel.success:
        return Colors.greenAccent;
      case SimulatorEventLevel.warning:
        return Colors.amberAccent;
      case SimulatorEventLevel.error:
        return Colors.redAccent;
    }
  }

  String _ts(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      color: const Color(0xFF15171B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFF1F2228),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('事件日志 · Event Log',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: '清空',
                  iconSize: 16,
                  splashRadius: 14,
                  color: Colors.white54,
                  onPressed: () => setState(_events.clear),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
          Expanded(
            child: _events.isEmpty
                ? const Center(
                    child: Text('暂无事件 · No events yet',
                        style: TextStyle(color: Colors.white38, fontSize: 12)))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(8),
                    itemCount: _events.length,
                    itemBuilder: (_, i) {
                      final e = _events[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Colors.white70),
                            children: [
                              TextSpan(
                                  text: '${_ts(e.ts)}  ',
                                  style:
                                      const TextStyle(color: Colors.white38)),
                              TextSpan(
                                  text: e.message,
                                  style: TextStyle(color: _color(e.level))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Captures the widget under [boundaryKey] to a PNG and returns the bytes.
Future<Uint8List?> captureScreenshot(GlobalKey boundaryKey,
    {double pixelRatio = 2.0}) async {
  final boundary = boundaryKey.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) return null;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}
