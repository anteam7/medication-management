// Generates a pill/capsule + round tablet app icon at assets/icon/icon.png.
// Run with: dart run tool/generate_icon.dart
// Then regenerate launcher icons with: dart run flutter_launcher_icons
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  // RGBA so everything outside the two pill shapes can stay fully
  // transparent (pixels default to (0,0,0,0)) instead of being filled with
  // a background color.
  final icon = img.Image(width: size, height: size, numChannels: 4);

  const capsuleRed = (r: 229, g: 57, b: 53);
  const capsuleWhite = (r: 255, g: 255, b: 255);
  const divider = (r: 200, g: 200, b: 200);
  // A solid blue (not white) so the tablet stays clearly visible against
  // both a transparent/light launcher background and the capsule's white
  // half, instead of blending into either.
  const tabletBlue = (r: 66, g: 133, b: 244);
  const tabletBorder = (r: 30, g: 90, b: 190);
  const tabletScoreLine = (r: 30, g: 90, b: 190);

  final cx = size / 2;
  final cy = size / 2;
  // Both shapes are scaled up 35% from the original design (halfLength 260,
  // radius 150, tablet offset/radius 150/140) while keeping their relative
  // proportions and composition — everything below is just those originals
  // times 1.35.
  const scale = 1.35;
  const halfLength = 260.0 * scale; // distance from center to each rounded end
  const radius = 150.0 * scale; // capsule thickness / end-cap radius
  const dividerHalfWidth = 6.0 * scale;
  const angle = -math.pi / 4; // tilt like the classic pill emoji
  final cosA = math.cos(angle);
  final sinA = math.sin(angle);

  // A round blue tablet sits in front of the capsule, overlapping it —
  // drawn/checked first below so it wins over the capsule wherever the two
  // shapes overlap. It gets an extra 30% on top of the shared `scale` (its
  // position stays put — only its own size grows), since it's meant to
  // stand out more than the capsule.
  const tabletScale = 1.3;
  final tabletCx = cx + 150 * scale;
  final tabletCy = cy + 150 * scale;
  const tabletRadius = 140.0 * scale * tabletScale;
  const tabletBorderWidth = 8.0 * scale * tabletScale;
  const scoreLineHalfWidth = 5.0 * scale * tabletScale;

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

      final tdx = x - tabletCx;
      final tdy = y - tabletCy;
      final tabletDistSq = tdx * tdx + tdy * tdy;
      final inTablet = tabletDistSq <= tabletRadius * tabletRadius;
      final inTabletBorder =
          inTablet && tabletDistSq > (tabletRadius - tabletBorderWidth) * (tabletRadius - tabletBorderWidth);

      if (inTablet) {
        final color = inTabletBorder
            ? tabletBorder
            : (tdy.abs() < scoreLineHalfWidth ? tabletScoreLine : tabletBlue);
        icon.setPixelRgba(x, y, color.r, color.g, color.b, 255);
      } else if (inMiddle || inCap) {
        final color = rx.abs() < dividerHalfWidth
            ? divider
            : (rx < 0 ? capsuleRed : capsuleWhite);
        icon.setPixelRgba(x, y, color.r, color.g, color.b, 255);
      }
      // Outside both shapes: leave the pixel at its default (0,0,0,0) —
      // fully transparent, no background fill.
    }
  }

  final outFile = File('assets/icon/icon.png');
  outFile.createSync(recursive: true);
  outFile.writeAsBytesSync(img.encodePng(icon));
  // ignore: avoid_print
  print('Wrote ${outFile.path}');
}
