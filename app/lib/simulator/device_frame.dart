import 'package:flutter/material.dart';

import 'device_specs.dart';

/// Renders a physical device chassis (bezel + cutout + home indicator + an
/// optional iOS/Android-style status bar overlay) wrapping a child widget,
/// with `MediaQuery` overridden to mimic the device's logical size, DPR,
/// safe-area insets and platform brightness.
class DeviceFrame extends StatelessWidget {
  final DeviceSpec spec;
  final SimOrientation orientation;
  final Brightness brightness;
  final bool showStatusBar;
  final Widget child;

  const DeviceFrame({
    super.key,
    required this.spec,
    required this.orientation,
    required this.child,
    this.brightness = Brightness.light,
    this.showStatusBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final size = spec.sizeFor(orientation);
    final padding = spec.safeAreaFor(orientation);
    final outerRadius = spec.cornerRadius + spec.bezel;

    final mq = MediaQueryData(
      size: size,
      devicePixelRatio: spec.devicePixelRatio,
      padding: padding,
      viewPadding: padding,
      platformBrightness: brightness,
      textScaler: TextScaler.noScaling,
    );

    return Container(
      width: size.width + spec.bezel * 2,
      height: size.height + spec.bezel * 2,
      decoration: BoxDecoration(
        color: spec.chassisColor,
        borderRadius: BorderRadius.circular(outerRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 40,
            spreadRadius: 4,
            offset: Offset(0, 14),
          ),
        ],
        border: Border.all(color: const Color(0xFF2A2A2E), width: 2),
      ),
      padding: EdgeInsets.all(spec.bezel),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(spec.cornerRadius),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: ColoredBox(
            color: spec.screenBackground,
            child: Stack(
              children: [
                Positioned.fill(
                  child: MediaQuery(
                    data: mq,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: child,
                    ),
                  ),
                ),
                if (spec.showStatusBar &&
                    showStatusBar &&
                    orientation == SimOrientation.portrait)
                  _StatusBar(spec: spec, brightness: brightness),
                if (spec.cutout != null &&
                    orientation == SimOrientation.portrait)
                  _Cutout(cutout: spec.cutout!),
                if (spec.hasHomeIndicator)
                  _HomeIndicator(orientation: orientation),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cutout extends StatelessWidget {
  final FrameCutout cutout;
  const _Cutout({required this.cutout});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: cutout.topInset,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: cutout.width,
          height: cutout.height,
          decoration: BoxDecoration(
            color: Colors.black,
            shape: cutout.circular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: cutout.circular
                ? null
                : BorderRadius.circular(cutout.cornerRadius),
          ),
        ),
      ),
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  final SimOrientation orientation;
  const _HomeIndicator({required this.orientation});

  @override
  Widget build(BuildContext context) {
    final isPortrait = orientation == SimOrientation.portrait;
    return Positioned(
      bottom: isPortrait ? 6 : null,
      left: isPortrait ? 0 : null,
      right: isPortrait ? 0 : 6,
      top: isPortrait ? null : 0,
      child: Center(
        child: Container(
          width: isPortrait ? 134 : 5,
          height: isPortrait ? 5 : 134,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

/// Status bar overlay: 9:41 left (iOS) or center (Android cutout), with
/// signal/wifi/battery glyphs on the right. Drawn outside the app's
/// MediaQuery so it sits on the device chrome layer.
class _StatusBar extends StatelessWidget {
  final DeviceSpec spec;
  final Brightness brightness;
  const _StatusBar({required this.spec, required this.brightness});

  @override
  Widget build(BuildContext context) {
    final fg = brightness == Brightness.dark ? Colors.white : Colors.black87;
    final isAndroid = spec.platform == DevicePlatform.android;
    final timeText = const Text('9:41',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          fontFeatures: [FontFeature.tabularFigures()],
        ));
    final right = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.signal_cellular_alt, size: 14, color: fg),
        const SizedBox(width: 4),
        Icon(Icons.wifi, size: 14, color: fg),
        const SizedBox(width: 4),
        Icon(Icons.battery_full, size: 16, color: fg),
      ],
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: spec.safeArea.top.clamp(20, 60).toDouble(),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg),
        child: IconTheme(
          data: IconThemeData(color: fg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: isAndroid
                  ? [right, const SizedBox.shrink(), timeText]
                  : [timeText, const SizedBox.shrink(), right],
            ),
          ),
        ),
      ),
    );
  }
}
