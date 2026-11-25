import 'dart:typed_data';

import 'package:dds_format/src/bcn/bcn_utils.dart';
import 'package:dds_format/src/bcn_decoder.dart';

/// BC1 (DXT1) block decoder extension on [BcnDecoder].
extension Bc1Decoder on BcnDecoder {
  void decodeBc1(Uint8List src, Uint8List dst, int width, int height) {
    final blocksX = (width + 3) >> 2;
    final blocksY = (height + 3) >> 2;
    final r = Uint8List(4);
    final g = Uint8List(4);
    final b = Uint8List(4);
    final a = Uint8List(4);

    int srcOff = 0;
    for (int by = 0; by < blocksY; by++) {
      final baseY = by << 2;
      for (int bx = 0; bx < blocksX; bx++) {
        final baseX = bx << 2;
        final c0 = src[srcOff] | (src[srcOff + 1] << 8);
        final c1 = src[srcOff + 2] | (src[srcOff + 3] << 8);
        final indices =
            src[srcOff + 4] |
            (src[srcOff + 5] << 8) |
            (src[srcOff + 6] << 16) |
            (src[srcOff + 7] << 24);
        srcOff += 8;

        unpackRgb565(c0, r, g, b, 0);
        unpackRgb565(c1, r, g, b, 1);
        a[0] = 255;
        a[1] = 255;

        if (c0 > c1) {
          r[2] = (2 * r[0] + r[1] + 1) ~/ 3;
          g[2] = (2 * g[0] + g[1] + 1) ~/ 3;
          b[2] = (2 * b[0] + b[1] + 1) ~/ 3;
          a[2] = 255;

          r[3] = (r[0] + 2 * r[1] + 1) ~/ 3;
          g[3] = (g[0] + 2 * g[1] + 1) ~/ 3;
          b[3] = (b[0] + 2 * b[1] + 1) ~/ 3;
          a[3] = 255;
        } else {
          r[2] = (r[0] + r[1]) >> 1;
          g[2] = (g[0] + g[1]) >> 1;
          b[2] = (b[0] + b[1]) >> 1;
          a[2] = 255;

          r[3] = 0;
          g[3] = 0;
          b[3] = 0;
          a[3] = 0;
        }

        for (int py = 0; py < 4; py++) {
          final y = baseY + py;
          if (y >= height) {
            break;
          }
          for (int px = 0; px < 4; px++) {
            final x = baseX + px;
            if (x >= width) {
              continue;
            }
            final idx = (indices >> (((py << 2) + px) << 1)) & 0x3;
            final dstOff = (y * width + x) << 2;
            dst[dstOff] = r[idx];
            dst[dstOff + 1] = g[idx];
            dst[dstOff + 2] = b[idx];
            dst[dstOff + 3] = a[idx];
          }
        }
      }
    }
  }
}
