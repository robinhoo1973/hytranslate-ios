import 'package:flutter/material.dart';

/// Logical category used to group devices in the picker sidebar.
enum DeviceCategory {
  phone('手机 · Phone', Icons.phone_iphone),
  tablet('平板 · Tablet', Icons.tablet_mac),
  foldable('折叠屏 · Foldable', Icons.unfold_more),
  watch('手表 · Watch', Icons.watch),
  desktop('桌面 · Desktop', Icons.desktop_windows);

  final String label;
  final IconData icon;
  const DeviceCategory(this.label, this.icon);
}

enum DevicePlatform { ios, android, watchOS, linux, windows }

enum SimOrientation { portrait, landscape }

/// A frame cutout sitting at the top of the screen (notch / dynamic island /
/// punch-hole). `null` means a clean top edge.
class FrameCutout {
  final double width;
  final double height;
  final double topInset;
  final double cornerRadius;
  final bool circular;
  const FrameCutout({
    required this.width,
    required this.height,
    this.topInset = 8,
    this.cornerRadius = 18,
    this.circular = false,
  });

  static const dynamicIsland =
      FrameCutout(width: 124, height: 36, topInset: 11, cornerRadius: 20);
  static const iphoneNotch =
      FrameCutout(width: 210, height: 30, topInset: 0, cornerRadius: 18);
  static const punchHole =
      FrameCutout(width: 14, height: 14, topInset: 14, circular: true);
}

class DeviceSpec {
  final String id;
  final String name; // 显示名（中英）
  final DeviceCategory category;
  final DevicePlatform platform;

  /// Logical pixels in portrait. (For desktop, this is the window size.)
  final Size logicalSize;
  final double devicePixelRatio;

  /// Safe area in portrait orientation. Landscape is auto-derived.
  final EdgeInsets safeArea;

  final double cornerRadius; // screen corner
  final double bezel; // physical bezel thickness around screen
  final FrameCutout? cutout;
  final bool hasHomeIndicator;
  final bool showStatusBar; // overlay clock/wifi/battery
  final bool supportsRotation;

  /// Chassis (frame) and screen background colors.
  final Color chassisColor;
  final Color screenBackground;

  const DeviceSpec({
    required this.id,
    required this.name,
    required this.category,
    required this.platform,
    required this.logicalSize,
    required this.devicePixelRatio,
    this.safeArea = EdgeInsets.zero,
    this.cornerRadius = 0,
    this.bezel = 14,
    this.cutout,
    this.hasHomeIndicator = false,
    this.showStatusBar = true,
    this.supportsRotation = true,
    this.chassisColor = const Color(0xFF1A1A1C),
    this.screenBackground = Colors.white,
  });

  Size sizeFor(SimOrientation o) => o == SimOrientation.portrait
      ? logicalSize
      : Size(logicalSize.height, logicalSize.width);

  EdgeInsets safeAreaFor(SimOrientation o) {
    if (o == SimOrientation.portrait) return safeArea;
    // Landscape rotation: top-bar shrinks; cutout side gets a chunk of inset.
    final cutoutSide = (cutout?.height ?? 0) + (cutout?.topInset ?? 0);
    return EdgeInsets.fromLTRB(
      cutoutSide,
      hasHomeIndicator ? 0 : safeArea.top * 0.4,
      safeArea.bottom * 0.6,
      hasHomeIndicator ? 21 : 0,
    );
  }
}

/// Curated catalog covering every category. Sizes & insets sourced from
/// Apple/Google human-interface specs (rounded to whole logical pixels).
const kDevices = <DeviceSpec>[
  // ─── Phones ──────────────────────────────────────────────────────────
  DeviceSpec(
    id: 'iphone15pro',
    name: 'iPhone 15 Pro',
    category: DeviceCategory.phone,
    platform: DevicePlatform.ios,
    logicalSize: Size(393, 852),
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.fromLTRB(0, 59, 0, 34),
    cornerRadius: 55,
    bezel: 12,
    cutout: FrameCutout.dynamicIsland,
    hasHomeIndicator: true,
  ),
  DeviceSpec(
    id: 'iphone_se',
    name: 'iPhone SE (3rd)',
    category: DeviceCategory.phone,
    platform: DevicePlatform.ios,
    logicalSize: Size(375, 667),
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.fromLTRB(0, 20, 0, 0),
    cornerRadius: 0,
    bezel: 22,
  ),
  DeviceSpec(
    id: 'pixel8',
    name: 'Pixel 8',
    category: DeviceCategory.phone,
    platform: DevicePlatform.android,
    logicalSize: Size(412, 915),
    devicePixelRatio: 2.625,
    safeArea: EdgeInsets.fromLTRB(0, 40, 0, 24),
    cornerRadius: 38,
    bezel: 10,
    cutout: FrameCutout.punchHole,
    hasHomeIndicator: true,
    chassisColor: Color(0xFF202428),
  ),
  DeviceSpec(
    id: 'galaxy_s24',
    name: 'Galaxy S24 Ultra',
    category: DeviceCategory.phone,
    platform: DevicePlatform.android,
    logicalSize: Size(384, 832),
    devicePixelRatio: 3.0,
    safeArea: EdgeInsets.fromLTRB(0, 36, 0, 24),
    cornerRadius: 14,
    bezel: 8,
    cutout: FrameCutout.punchHole,
    hasHomeIndicator: true,
    chassisColor: Color(0xFF111317),
  ),

  // ─── Tablets ─────────────────────────────────────────────────────────
  DeviceSpec(
    id: 'ipad_pro_11',
    name: 'iPad Pro 11"',
    category: DeviceCategory.tablet,
    platform: DevicePlatform.ios,
    logicalSize: Size(834, 1194),
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.fromLTRB(0, 24, 0, 20),
    cornerRadius: 18,
    bezel: 26,
    hasHomeIndicator: true,
  ),
  DeviceSpec(
    id: 'ipad_pro_13',
    name: 'iPad Pro 13"',
    category: DeviceCategory.tablet,
    platform: DevicePlatform.ios,
    logicalSize: Size(1024, 1366),
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.fromLTRB(0, 24, 0, 20),
    cornerRadius: 18,
    bezel: 28,
    hasHomeIndicator: true,
  ),
  DeviceSpec(
    id: 'galaxy_tab_s9',
    name: 'Galaxy Tab S9',
    category: DeviceCategory.tablet,
    platform: DevicePlatform.android,
    logicalSize: Size(800, 1280),
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.fromLTRB(0, 28, 0, 20),
    cornerRadius: 12,
    bezel: 22,
    chassisColor: Color(0xFF202428),
  ),

  // ─── Foldables ───────────────────────────────────────────────────────
  DeviceSpec(
    id: 'galaxy_zfold5',
    name: 'Galaxy Z Fold5 (展开)',
    category: DeviceCategory.foldable,
    platform: DevicePlatform.android,
    logicalSize: Size(673, 841),
    devicePixelRatio: 2.625,
    safeArea: EdgeInsets.fromLTRB(0, 30, 0, 24),
    cornerRadius: 14,
    bezel: 12,
    cutout: FrameCutout.punchHole,
    hasHomeIndicator: true,
  ),

  // ─── Watches ─────────────────────────────────────────────────────────
  DeviceSpec(
    id: 'watch_ultra',
    name: 'Apple Watch Ultra 49mm',
    category: DeviceCategory.watch,
    platform: DevicePlatform.watchOS,
    logicalSize: Size(205, 251),
    devicePixelRatio: 2.0,
    safeArea: EdgeInsets.fromLTRB(0, 0, 0, 0),
    cornerRadius: 38,
    bezel: 16,
    showStatusBar: false,
    supportsRotation: false,
    screenBackground: Color(0xFF000000),
  ),

  // ─── Desktop ─────────────────────────────────────────────────────────
  DeviceSpec(
    id: 'linux_desktop',
    name: 'Linux 桌面 1280×800',
    category: DeviceCategory.desktop,
    platform: DevicePlatform.linux,
    logicalSize: Size(1280, 800),
    devicePixelRatio: 1.0,
    cornerRadius: 8,
    bezel: 6,
    showStatusBar: false,
    supportsRotation: false,
    chassisColor: Color(0xFF2A2D31),
    screenBackground: Color(0xFFF6F7FB),
  ),
  DeviceSpec(
    id: 'windows_desktop',
    name: 'Windows 桌面 1366×768',
    category: DeviceCategory.desktop,
    platform: DevicePlatform.windows,
    logicalSize: Size(1366, 768),
    devicePixelRatio: 1.0,
    cornerRadius: 4,
    bezel: 6,
    showStatusBar: false,
    supportsRotation: false,
    chassisColor: Color(0xFF1F1F1F),
    screenBackground: Color(0xFFFFFFFF),
  ),
];

DeviceSpec deviceById(String id) =>
    kDevices.firstWhere((d) => d.id == id, orElse: () => kDevices.first);
