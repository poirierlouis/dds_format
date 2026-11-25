import 'dart:typed_data';

import 'package:dds_format/src/bcn/bcn_utils.dart';
import 'package:dds_format/src/bcn_decoder.dart';

/// BC5 (ATI2) block decoder extension on [BcnDecoder].
extension Bc5Decoder on BcnDecoder {
  void decodeBc5(Uint8List src, Uint8List dst, int width, int height) {
    final blocksX = (width + 3) >> 2;
    final blocksY = (height + 3) >> 2;
    final palette = Uint8List(8);
    final red = Uint8List(16);
    final green = Uint8List(16);

    int srcOff = 0;
    for (int by = 0; by < blocksY; by++) {
      final baseY = by << 2;
      for (int bx = 0; bx < blocksX; bx++) {
        final baseX = bx << 2;
        decodeBc4Block(src, srcOff, palette, red);
        decodeBc4Block(src, srcOff + 8, palette, green);
        srcOff += 16;

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
            final texel = (py << 2) + px;
            final dstOff = (y * width + x) << 2;
            dst[dstOff] = red[texel];
            dst[dstOff + 1] = green[texel];
            dst[dstOff + 2] = 0;
            dst[dstOff + 3] = 255;
          }
        }
      }
    }
  }
}
