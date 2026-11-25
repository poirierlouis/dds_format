import 'dart:typed_data';

/// Unpacks a 16-bit RGB565 color [c] into [r], [g], [b] at [slot].
void unpackRgb565(int c, Uint8List r, Uint8List g, Uint8List b, int slot) {
  final r5 = (c >> 11) & 0x1F;
  final g6 = (c >> 5) & 0x3F;
  final b5 = c & 0x1F;
  r[slot] = (r5 << 3) | (r5 >> 2);
  g[slot] = (g6 << 2) | (g6 >> 4);
  b[slot] = (b5 << 3) | (b5 >> 2);
}

/// Decodes an 8-byte BC4 single-channel block at [offset] in [src] into 16
/// texel values in [out16], using [palette] as an 8-byte scratch buffer.
void decodeBc4Block(
  Uint8List src,
  int offset,
  Uint8List palette,
  Uint8List out16,
) {
  final a0 = src[offset];
  final a1 = src[offset + 1];
  palette[0] = a0;
  palette[1] = a1;

  if (a0 > a1) {
    palette[2] = (6 * a0 + 1 * a1) ~/ 7;
    palette[3] = (5 * a0 + 2 * a1) ~/ 7;
    palette[4] = (4 * a0 + 3 * a1) ~/ 7;
    palette[5] = (3 * a0 + 4 * a1) ~/ 7;
    palette[6] = (2 * a0 + 5 * a1) ~/ 7;
    palette[7] = (1 * a0 + 6 * a1) ~/ 7;
  } else {
    palette[2] = (4 * a0 + 1 * a1) ~/ 5;
    palette[3] = (3 * a0 + 2 * a1) ~/ 5;
    palette[4] = (2 * a0 + 3 * a1) ~/ 5;
    palette[5] = (1 * a0 + 4 * a1) ~/ 5;
    palette[6] = 0;
    palette[7] = 255;
  }

  // 48-bit index stream: two 24-bit halves (8 texels each) to avoid 64-bit
  // shift overflow issues on web/JS if ever compiled there.
  final lo = src[offset + 2] | (src[offset + 3] << 8) | (src[offset + 4] << 16);
  final hi = src[offset + 5] | (src[offset + 6] << 8) | (src[offset + 7] << 16);

  for (int i = 0; i < 8; i++) {
    out16[i] = palette[(lo >> (i * 3)) & 0x7];
    out16[i + 8] = palette[(hi >> (i * 3)) & 0x7];
  }
}

/// Reads [count] little-endian bits starting at [bitPos] within a 16-byte
/// block at [blockOff] in [src].
int readBits(Uint8List src, int blockOff, int bitPos, int count) {
  if (count == 0) {
    return 0;
  }
  int result = 0;
  int remaining = count;
  int pos = bitPos;
  int outShift = 0;
  while (remaining > 0) {
    final byteIdx = pos >> 3;
    final bitInByte = pos & 7;
    final take = remaining < (8 - bitInByte) ? remaining : (8 - bitInByte);
    final mask = (1 << take) - 1;
    final bits = (src[blockOff + byteIdx] >> bitInByte) & mask;
    result |= bits << outShift;
    pos += take;
    outShift += take;
    remaining -= take;
  }
  return result;
}

/// Fills a 4x4 block at ([baseX], [baseY]) with opaque black `(0, 0, 0, 255)`.
void fillBlackBlock(
  Uint8List dst,
  int width,
  int height,
  int baseX,
  int baseY,
) {
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
      final dstOff = (y * width + x) << 2;
      dst[dstOff] = 0;
      dst[dstOff + 1] = 0;
      dst[dstOff + 2] = 0;
      dst[dstOff + 3] = 255;
    }
  }
}

const List<int> bc7Weights2 = [0, 21, 43, 64];
const List<int> bc7Weights3 = [0, 9, 18, 27, 37, 46, 55, 64];
const List<int> bc7Weights4 = [
  0,
  4,
  9,
  13,
  17,
  21,
  26,
  30,
  34,
  38,
  43,
  47,
  51,
  55,
  60,
  64,
];

/// Standard 2-subset anchor indices for 32/64 partitions (BC6H uses first 32).
const List<int> bc7Anchor2 = [
  15,
  15,
  15,
  15,
  15,
  15,
  15,
  15,
  15,
  15,
  15,
  15,
  15,
  15,
  15,
  15,
  15,
  2,
  8,
  2,
  2,
  8,
  8,
  15,
  2,
  8,
  2,
  2,
  8,
  8,
  2,
  2,
  15,
  15,
  6,
  8,
  2,
  8,
  15,
  15,
  2,
  8,
  2,
  2,
  2,
  15,
  15,
  6,
  6,
  2,
  6,
  8,
  15,
  15,
  2,
  2,
  15,
  15,
  15,
  15,
  15,
  2,
  2,
  15,
];

/// Standard 2-subset partition table (64 entries x 16 texels).
const List<List<int>> bc6hPartition2 = [
  [0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1],
  [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1],
  [0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1],
  [0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1, 1, 1],
  [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1],
  [0, 0, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1],
  [0, 0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1],
  [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 1],
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1],
  [0, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
  [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1],
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1],
  [0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
  [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1],
  [0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1],
  [0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1, 1],
  [0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0],
  [0, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0],
  [0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1, 0],
  [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0],
  [0, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 1],
  [0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0],
  [0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0],
  [0, 0, 1, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0],
  [0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0],
  [0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
  [0, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1, 0],
  [0, 0, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 1, 0, 0],
  [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1],
  [0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1],
  [0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0],
  [0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0],
  [0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0],
  [0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0],
  [0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1],
  [0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1],
  [0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0],
  [0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0],
  [0, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 0, 0],
  [0, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 0],
  [0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0],
  [0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1],
  [0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1],
  [0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0],
  [0, 1, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0],
  [0, 0, 1, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0, 1, 0],
  [0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0],
  [0, 1, 1, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1],
  [0, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 0, 1, 0, 0, 1],
  [0, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0],
  [0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 0],
  [0, 1, 1, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 1],
  [0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1],
  [0, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1],
  [0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1],
  [0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1],
  [0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
  [0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0],
  [0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1],
];
