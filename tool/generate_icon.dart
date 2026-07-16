// Generates a simple pill/capsule app icon at assets/icon/icon.png.
// Run with: dart run tool/generate_icon.dart
// Then regenerate launcher icons with: dart run flutter_launcher_icons
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  // RGBA so everything outside the capsule can stay fully transparent
  // (pixels default to (0,0,0,0)) instead of being filled with a background
  // color — only the pill itself is drawn.
  final icon = img.Image(width: size, height: size, numChannels: 4);

  const capsuleRed = (r: 229, g: 57, b: 53);
  const capsuleWhite = (r: 255, g: 255, b: 255);
  const divider = (r: 200, g: 200, b: 200);

  final cx = size / 2;
  final cy = size / 2;
  const halfLength = 260.0; // distance from center to each rounded end
  const radius = 150.0; // capsule thickness / end-cap radius
  const dividerHalfWidth = 6.0;
  const angle = -math.pi / 4; // tilt like the classic pill emoji
  final cosA = math.cos(angle);
  final sinA = math.sin(angle);

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final dx = x - cx;
      final dy = y - cy;
      // Rotate into the capsule's own (unrotated) coordinate frame.
      final rx = dx * cosA + dy * sinA;
      final ry = -dx * sinA + dy * cosA;

      final inMiddle = rx.abs() <= halfLength && ry.abs() <= radius;
      final capEdgeDx = rx.abs() - halfLength;
      final inCap = rx.abs() > halfLength && (capEdgeDx * capEdgeDx + ry * ry) <= radius * radius;

      if (inMiddle || inCap) {
        final color = rx.abs() < dividerHalfWidth
            ? divider
            : (rx < 0 ? capsuleRed : capsuleWhite);
        icon.setPixelRgba(x, y, color.r, color.g, color.b, 255);
      }
      // Outside the capsule: leave the pixel at its default (0,0,0,0) —
      // fully transparent, no background fill.
    }
  }

  final outFile = File('assets/icon/icon.png');
  outFile.createSync(recursive: true);
  outFile.writeAsBytesSync(img.encodePng(icon));
  // ignore: avoid_print
  print('Wrote ${outFile.path}');
}
