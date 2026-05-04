import 'dart:io' show Directory, File;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'device_frame.dart';
import 'device_specs.dart';
import 'feedback.dart';

/// Top-level desktop scaffold that hosts the simulated device frame.
///
/// Layout (left → right): device sidebar (categorized list), main canvas
/// (toolbar + zoomable device frame + FPS overlay), event log panel.
class SimulatorHost extends StatefulWidget {
  final Widget child;
  final String initialDeviceId;
  const SimulatorHost({
    super.key,
    required this.child,
    this.initialDeviceId = 'iphone15pro',
  });

  @override
  State<SimulatorHost> createState() => _SimulatorHostState();
}

class _SimulatorHostState extends State<SimulatorHost> {
  late DeviceSpec _device;
  SimOrientation _orientation = SimOrientation.portrait;
  Brightness _brightness = Brightness.light;
  double _zoom = 0.7;
  bool _showFps = true;
  bool _showLog = true;
  bool _showStatusBar = true;
  final _boundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _device = deviceById(widget.initialDeviceId);
    SimulatorEventBus.instance.emit(
        '模拟器启动 · 默认设备 ${_device.name}',
        level: SimulatorEventLevel.info);
  }

  void _selectDevice(DeviceSpec d) {
    setState(() {
      _device = d;
      if (!d.supportsRotation) _orientation = SimOrientation.portrait;
    });
    SimulatorEventBus.instance.emit('切换设备 → ${d.name}');
  }

  void _toggleOrientation() {
    if (!_device.supportsRotation) return;
    setState(() => _orientation = _orientation == SimOrientation.portrait
        ? SimOrientation.landscape
        : SimOrientation.portrait);
    SimulatorEventBus.instance.emit(
        '旋转 → ${_orientation == SimOrientation.portrait ? "竖屏" : "横屏"}');
  }

  void _toggleTheme() {
    setState(() => _brightness =
        _brightness == Brightness.light ? Brightness.dark : Brightness.light);
    SimulatorEventBus.instance.emit(
        '主题 → ${_brightness == Brightness.light ? "浅色" : "深色"}');
  }

  Future<void> _screenshot() async {
    final bytes = await captureScreenshot(_boundaryKey, pixelRatio: 2.0);
    if (bytes == null) {
      SimulatorEventBus.instance.emit('截图失败',
          level: SimulatorEventLevel.error);
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/screenshots');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${outDir.path}/sim-${_device.id}-$ts.png');
    await file.writeAsBytes(bytes);
    SimulatorEventBus.instance.emit(
        '截图保存: ${file.path}',
        level: SimulatorEventLevel.success);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('截图已保存到 ${file.path}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1014),
      body: Row(
        children: [
          _DeviceSidebar(selected: _device, onSelect: _selectDevice),
          const VerticalDivider(width: 1, color: Color(0xFF1F2228)),
          Expanded(
            child: Column(
              children: [
                _Toolbar(
                  device: _device,
                  orientation: _orientation,
                  brightness: _brightness,
                  zoom: _zoom,
                  showFps: _showFps,
                  showLog: _showLog,
                  showStatusBar: _showStatusBar,
                  onOrientation: _toggleOrientation,
                  onTheme: _toggleTheme,
                  onZoom: (v) => setState(() => _zoom = v),
                  onFps: (v) => setState(() => _showFps = v),
                  onLog: (v) => setState(() => _showLog = v),
                  onStatusBar: (v) => setState(() => _showStatusBar = v),
                  onScreenshot: _screenshot,
                ),
                Expanded(
                  child: Container(
                    color: const Color(0xFF101418),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Center(
                                  child: Transform.scale(
                                    scale: _zoom,
                                    child: RepaintBoundary(
                                      key: _boundaryKey,
                                      child: DeviceFrame(
                                        spec: _device,
                                        orientation: _orientation,
                                        brightness: _brightness,
                                        showStatusBar: _showStatusBar,
                                        child: widget.child,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_showFps)
                          const Positioned(
                            top: 12,
                            right: 12,
                            child: FpsCounter(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showLog) ...[
            const VerticalDivider(width: 1, color: Color(0xFF1F2228)),
            const EventLogPanel(),
          ],
        ],
      ),
    );
  }
}

class _DeviceSidebar extends StatelessWidget {
  final DeviceSpec selected;
  final ValueChanged<DeviceSpec> onSelect;
  const _DeviceSidebar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final grouped = <DeviceCategory, List<DeviceSpec>>{};
    for (final d in kDevices) {
      grouped.putIfAbsent(d.category, () => []).add(d);
    }
    return Container(
      width: 230,
      color: const Color(0xFF15171B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: const Text('设备类别 · Devices',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                for (final cat in DeviceCategory.values) ...[
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Row(
                      children: [
                        Icon(cat.icon, color: Colors.white54, size: 14),
                        const SizedBox(width: 6),
                        Text(cat.label,
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6)),
                      ],
                    ),
                  ),
                  for (final d in grouped[cat] ?? const <DeviceSpec>[])
                    _DeviceTile(
                      spec: d,
                      selected: d.id == selected.id,
                      onTap: () => onSelect(d),
                    ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF1F2228)),
              ),
            ),
            child: Text(
              '${selected.logicalSize.width.toInt()} × ${selected.logicalSize.height.toInt()} '
              '@${selected.devicePixelRatio}x',
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final DeviceSpec spec;
  final bool selected;
  final VoidCallback onTap;
  const _DeviceTile(
      {required this.spec, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color:
            selected ? const Color(0xFF1E88E5).withValues(alpha: 0.18) : null,
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? const Color(0xFF1E88E5)
                    : Colors.white24,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                spec.name,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final DeviceSpec device;
  final SimOrientation orientation;
  final Brightness brightness;
  final double zoom;
  final bool showFps, showLog, showStatusBar;
  final VoidCallback onOrientation, onTheme, onScreenshot;
  final ValueChanged<double> onZoom;
  final ValueChanged<bool> onFps, onLog, onStatusBar;

  const _Toolbar({
    required this.device,
    required this.orientation,
    required this.brightness,
    required this.zoom,
    required this.showFps,
    required this.showLog,
    required this.showStatusBar,
    required this.onOrientation,
    required this.onTheme,
    required this.onZoom,
    required this.onFps,
    required this.onLog,
    required this.onStatusBar,
    required this.onScreenshot,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      color: const Color(0xFF15171B),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(device.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          _ToolIconBtn(
            tooltip: device.supportsRotation
                ? '旋转 · Rotate'
                : '该设备不支持旋转',
            icon: orientation == SimOrientation.portrait
                ? Icons.stay_current_portrait
                : Icons.stay_current_landscape,
            enabled: device.supportsRotation,
            onPressed: onOrientation,
          ),
          _ToolIconBtn(
            tooltip: brightness == Brightness.light
                ? '切换到深色'
                : '切换到浅色',
            icon: brightness == Brightness.light
                ? Icons.dark_mode
                : Icons.light_mode,
            onPressed: onTheme,
          ),
          _ToolIconBtn(
            tooltip: '截图 · Screenshot',
            icon: Icons.photo_camera,
            onPressed: onScreenshot,
          ),
          const SizedBox(width: 8),
          const VerticalDivider(width: 1, color: Color(0xFF2A2D31)),
          const SizedBox(width: 8),
          _ToggleChip(
              label: 'FPS', value: showFps, onChanged: onFps),
          const SizedBox(width: 6),
          _ToggleChip(
              label: '日志', value: showLog, onChanged: onLog),
          const SizedBox(width: 6),
          _ToggleChip(
              label: '状态栏', value: showStatusBar, onChanged: onStatusBar),
          const SizedBox(width: 12),
          const Icon(Icons.zoom_out, color: Colors.white54, size: 16),
          SizedBox(
            width: 160,
            child: Slider(
              value: zoom,
              min: 0.3,
              max: 1.5,
              divisions: 24,
              activeColor: const Color(0xFF1E88E5),
              label: '${(zoom * 100).round()}%',
              onChanged: onZoom,
            ),
          ),
          const Icon(Icons.zoom_in, color: Colors.white54, size: 16),
          const SizedBox(width: 6),
          Text('${(zoom * 100).round()}%',
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _ToolIconBtn extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;
  const _ToolIconBtn({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      iconSize: 20,
      color: Colors.white,
      disabledColor: Colors.white24,
      icon: Icon(icon),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleChip(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFF1E88E5).withValues(alpha: 0.2)
              : const Color(0xFF1F2228),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value
                ? const Color(0xFF1E88E5)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              color: value ? Colors.white : Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }
}
