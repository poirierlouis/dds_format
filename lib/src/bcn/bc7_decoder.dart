import 'dart:typed_data';

import 'package:dds_format/src/bcn/bcn_utils.dart';
import 'package:dds_format/src/bcn_decoder.dart';

/// BC7 (BPTC) block decoder extension on [BcnDecoder].
extension Bc7Decoder on BcnDecoder {
  // [subsets, partitionBits, rotationBits, indexSelectionBits,
  //  colorBits, alphaBits, epPBits, spPBits, idxBits, idx2Bits]
  static const List<List<int>> _bc7Modes = [
    [3, 4, 0, 0, 4, 0, 1, 0, 3, 0], // Mode 0
    [2, 6, 0, 0, 6, 0, 0, 1, 3, 0], // Mode 1
    [3, 6, 0, 0, 5, 0, 0, 0, 2, 0], // Mode 2
    [2, 6, 0, 0, 7, 0, 1, 0, 2, 0], // Mode 3
    [1, 0, 2, 1, 5, 6, 0, 0, 2, 3], // Mode 4
    [1, 0, 2, 0, 7, 8, 0, 0, 2, 2], // Mode 5
    [1, 0, 0, 0, 7, 7, 1, 0, 4, 0], // Mode 6
    [2, 6, 0, 0, 5, 5, 1, 0, 2, 0], // Mode 7
  ];

  // Standard 3-subset anchor indices for 64 partitions.
  static const List<int> _bc7Anchor3a = [
    3, 3, 15, 15, 8, 3, 15, 15,
    8, 8, 6, 6, 6, 5, 3, 3,
    3, 3, 8, 15, 3, 3, 6, 10,
    5, 8, 8, 6, 8, 5, 15, 15,
    8, 15, 3, 5, 6, 10, 8, 15,
    15, 3, 15, 5, 15, 15, 15, 15,
    3, 15, 5, 5, 5, 8, 5, 10,
    5, 10, 8, 13, 15, 12, 3, 3,
  ];

  static const List<int> _bc7Anchor3b = [
    15, 8, 8, 3, 15, 15, 3, 8,
    15, 15, 15, 15, 15, 15, 15, 8,
    15, 8, 15, 3, 15, 8, 15, 8,
    3, 15, 6, 10, 15, 15, 10, 8,
    15, 3, 15, 10, 10, 8, 9, 10,
    6, 15, 8, 15, 3, 6, 6, 8,
    15, 3, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 3, 15, 15, 8,
  ];

  // Standard 3-subset partition table (64 entries x 16 texels).
  static const List<List<int>> _bc7Partition3 = [
    [0, 0, 1, 1, 0, 0, 1, 1, 0, 2, 2, 1, 2, 2, 2, 2],
    [0, 0, 0, 1, 0, 0, 1, 1, 2, 2, 1, 1, 2, 2, 2, 1],
    [0, 0, 0, 0, 2, 0, 0, 1, 2, 2, 1, 1, 2, 2, 1, 1],
    [0, 2, 2, 2, 0, 0, 2, 2, 0, 0, 1, 1, 0, 1, 1, 1],
    [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 2, 1, 1, 2, 2],
    [0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 2, 2, 0, 0, 2, 2],
    [0, 0, 2, 2, 0, 0, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1],
    [0, 0, 1, 1, 0, 0, 1, 1, 2, 2, 1, 1, 2, 2, 1, 1],
    [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2],
    [0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2],
    [0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2],
    [0, 0, 1, 2, 0, 0, 1, 2, 0, 0, 1, 2, 0, 0, 1, 2],
    [0, 1, 1, 2, 0, 1, 1, 2, 0, 1, 1, 2, 0, 1, 1, 2],
    [0, 1, 2, 2, 0, 1, 2, 2, 0, 1, 2, 2, 0, 1, 2, 2],
    [0, 0, 1, 1, 0, 1, 1, 2, 1, 1, 2, 2, 1, 2, 2, 2],
    [0, 0, 1, 1, 2, 0, 0, 1, 2, 2, 0, 0, 2, 2, 2, 0],
    [0, 0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 2, 1, 1, 2, 2],
    [0, 1, 1, 1, 0, 0, 1, 1, 2, 0, 0, 1, 2, 2, 0, 0],
    [0, 0, 0, 0, 1, 1, 2, 2, 1, 1, 2, 2, 1, 1, 2, 2],
    [0, 0, 2, 2, 0, 0, 2, 2, 0, 0, 2, 2, 1, 1, 1, 1],
    [0, 1, 1, 1, 0, 1, 1, 1, 0, 2, 2, 2, 0, 2, 2, 2],
    [0, 0, 0, 1, 0, 0, 0, 1, 2, 2, 2, 1, 2, 2, 2, 1],
    [0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 2, 2, 0, 1, 2, 2],
    [0, 0, 0, 0, 1, 1, 0, 0, 2, 2, 1, 0, 2, 2, 1, 0],
    [0, 1, 2, 2, 0, 1, 2, 2, 0, 0, 1, 1, 0, 0, 0, 0],
    [0, 0, 1, 2, 0, 0, 1, 2, 1, 1, 2, 2, 2, 2, 2, 2],
    [0, 1, 1, 0, 1, 2, 2, 1, 1, 2, 2, 1, 0, 1, 1, 0],
    [0, 0, 0, 0, 0, 1, 1, 0, 1, 2, 2, 1, 1, 2, 2, 1],
    [0, 0, 2, 2, 1, 1, 0, 2, 1, 1, 0, 2, 0, 0, 2, 2],
    [0, 1, 1, 0, 0, 1, 1, 0, 2, 0, 0, 2, 2, 2, 2, 2],
    [0, 0, 1, 1, 0, 1, 2, 2, 0, 1, 2, 2, 0, 0, 1, 1],
    [0, 0, 0, 0, 2, 0, 0, 0, 2, 2, 1, 1, 2, 2, 2, 1],
    [0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 2, 2, 1, 2, 2, 2],
    [0, 2, 2, 2, 0, 0, 2, 2, 0, 0, 1, 2, 0, 0, 1, 1],
    [0, 0, 1, 1, 0, 0, 1, 2, 0, 0, 2, 2, 0, 2, 2, 2],
    [0, 1, 2, 0, 0, 1, 2, 0, 0, 1, 2, 0, 0, 1, 2, 0],
    [0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 0, 0, 0, 0],
    [0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2, 0],
    [0, 1, 2, 0, 2, 0, 1, 2, 1, 2, 0, 1, 0, 1, 2, 0],
    [0, 0, 1, 1, 2, 2, 0, 0, 1, 1, 2, 2, 0, 0, 1, 1],
    [0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 0, 0, 0, 0, 1, 1],
    [0, 1, 0, 1, 0, 1, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2],
    [0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 2, 1, 2, 1, 2, 1],
    [0, 0, 2, 2, 1, 1, 2, 2, 0, 0, 2, 2, 1, 1, 2, 2],
    [0, 0, 2, 2, 0, 0, 1, 1, 0, 0, 2, 2, 0, 0, 1, 1],
    [0, 2, 2, 0, 1, 2, 2, 1, 0, 2, 2, 0, 1, 2, 2, 1],
    [0, 1, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 0, 1, 0, 1],
    [0, 0, 0, 0, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1],
    [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 2, 2, 2, 2],
    [0, 2, 2, 2, 0, 1, 1, 1, 0, 2, 2, 2, 0, 1, 1, 1],
    [0, 0, 0, 2, 1, 1, 1, 2, 0, 0, 0, 2, 1, 1, 1, 2],
    [0, 0, 0, 0, 2, 1, 1, 2, 2, 1, 1, 2, 2, 1, 1, 2],
    [0, 2, 2, 2, 0, 1, 1, 1, 0, 1, 1, 1, 0, 2, 2, 2],
    [0, 0, 0, 2, 1, 1, 1, 2, 1, 1, 1, 2, 0, 0, 0, 2],
    [0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 2, 2, 2, 2],
    [0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 2, 2, 1, 1, 2],
    [0, 1, 1, 0, 0, 1, 1, 0, 2, 2, 2, 2, 2, 2, 2, 2],
    [0, 0, 2, 2, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 2, 2],
    [0, 0, 2, 2, 1, 1, 2, 2, 1, 1, 2, 2, 0, 0, 2, 2],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 2],
    [0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 1],
    [0, 2, 2, 2, 1, 2, 2, 2, 0, 2, 2, 2, 1, 2, 2, 2],
    [0, 1, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2],
    [0, 1, 1, 1, 2, 0, 1, 1, 2, 2, 0, 1, 2, 2, 2, 0],
  ];

  void decodeBc7(Uint8List src, Uint8List dst, int width, int height) {
    final blocksX = (width + 3) >> 2;
    final blocksY = (height + 3) >> 2;

    final epR = Uint8List(6);
    final epG = Uint8List(6);
    final epB = Uint8List(6);
    final epA = Uint8List(6);
    final pBits = Uint8List(6);

    int srcOff = 0;
    for (int by = 0; by < blocksY; by++) {
      final baseY = by << 2;
      for (int bx = 0; bx < blocksX; bx++) {
        final baseX = bx << 2;
        final b0 = src[srcOff];
        if (b0 == 0) {
          fillBlackBlock(dst, width, height, baseX, baseY);
          srcOff += 16;
          continue;
        }

        int mode = 0;
        while (((b0 >> mode) & 1) == 0) {
          mode++;
        }

        final desc = _bc7Modes[mode];
        final subsets = desc[0];
        final partBits = desc[1];
        final rotBits = desc[2];
        final idxSelBits = desc[3];
        final colorBits = desc[4];
        final alphaBits = desc[5];
        final epPBits = desc[6];
        final spPBits = desc[7];
        final idxBits = desc[8];
        final idx2Bits = desc[9];

        int bitPos = mode + 1;
        final partition = partBits > 0
            ? readBits(src, srcOff, bitPos, partBits)
            : 0;
        bitPos += partBits;
        final rotation = rotBits > 0
            ? readBits(src, srcOff, bitPos, rotBits)
            : 0;
        bitPos += rotBits;
        final idxSel = idxSelBits > 0
            ? readBits(src, srcOff, bitPos, idxSelBits)
            : 0;
        bitPos += idxSelBits;

        final numEndpoints = subsets * 2;
        for (int i = 0; i < numEndpoints; i++) {
          epR[i] = readBits(src, srcOff, bitPos, colorBits);
          bitPos += colorBits;
        }
        for (int i = 0; i < numEndpoints; i++) {
          epG[i] = readBits(src, srcOff, bitPos, colorBits);
          bitPos += colorBits;
        }
        for (int i = 0; i < numEndpoints; i++) {
          epB[i] = readBits(src, srcOff, bitPos, colorBits);
          bitPos += colorBits;
        }
        if (alphaBits > 0) {
          for (int i = 0; i < numEndpoints; i++) {
            epA[i] = readBits(src, srcOff, bitPos, alphaBits);
            bitPos += alphaBits;
          }
        } else {
          for (int i = 0; i < numEndpoints; i++) {
            epA[i] = 255;
          }
        }

        final hasPBit = epPBits > 0 || spPBits > 0;
        if (epPBits > 0) {
          for (int i = 0; i < numEndpoints; i++) {
            pBits[i] = readBits(src, srcOff, bitPos, 1);
            bitPos += 1;
          }
        } else if (spPBits > 0) {
          for (int s = 0; s < subsets; s++) {
            final p = readBits(src, srcOff, bitPos, 1);
            bitPos += 1;
            pBits[s * 2] = p;
            pBits[s * 2 + 1] = p;
          }
        }

        final cPrecision = colorBits + (hasPBit ? 1 : 0);
        final aPrecision = alphaBits + (hasPBit ? 1 : 0);

        for (int i = 0; i < numEndpoints; i++) {
          int rVal = epR[i];
          int gVal = epG[i];
          int bVal = epB[i];
          if (hasPBit) {
            rVal = (rVal << 1) | pBits[i];
            gVal = (gVal << 1) | pBits[i];
            bVal = (bVal << 1) | pBits[i];
          }
          epR[i] = _unquantizeBc7(rVal, cPrecision);
          epG[i] = _unquantizeBc7(gVal, cPrecision);
          epB[i] = _unquantizeBc7(bVal, cPrecision);

          if (alphaBits > 0) {
            int aVal = epA[i];
            if (hasPBit) {
              aVal = (aVal << 1) | pBits[i];
            }
            epA[i] = _unquantizeBc7(aVal, aPrecision);
          }
        }

        final idx1Start = bitPos;
        final totalIdx1Bits = idxBits * 16 - subsets;
        final idx2Start = idx1Start + totalIdx1Bits;

        int pos1 = idx1Start;
        int pos2 = idx2Start;

        for (int i = 0; i < 16; i++) {
          int subset = 0;
          bool isAnchor = i == 0;
          if (subsets == 2) {
            subset = bc6hPartition2[partition][i];
            isAnchor = isAnchor || i == bc7Anchor2[partition];
          } else if (subsets == 3) {
            subset = _bc7Partition3[partition][i];
            isAnchor =
                isAnchor ||
                i == _bc7Anchor3a[partition] ||
                i == _bc7Anchor3b[partition];
          }

          final bits1 = isAnchor ? idxBits - 1 : idxBits;
          final index1 = readBits(src, srcOff, pos1, bits1);
          pos1 += bits1;

          int index2 = 0;
          if (idx2Bits > 0) {
            final bits2 = i == 0 ? idx2Bits - 1 : idx2Bits;
            index2 = readBits(src, srcOff, pos2, bits2);
            pos2 += bits2;
          }

          final px = i & 3;
          final py = i >> 2;
          final x = baseX + px;
          final y = baseY + py;
          if (x >= width || y >= height) {
            continue;
          }

          final colorIdx = idxSel == 0 ? index1 : index2;
          final alphaIdx = idx2Bits > 0
              ? (idxSel == 0 ? index2 : index1)
              : index1;

          final colorW = _bc7WeightForBits(
            idxSel == 0 ? idxBits : idx2Bits,
            colorIdx,
          );
          final alphaW = idx2Bits > 0
              ? _bc7WeightForBits(idxSel == 0 ? idx2Bits : idxBits, alphaIdx)
              : colorW;

          final e0 = subset * 2;
          final e1 = e0 + 1;
          int r = ((64 - colorW) * epR[e0] + colorW * epR[e1] + 32) >> 6;
          int g = ((64 - colorW) * epG[e0] + colorW * epG[e1] + 32) >> 6;
          int b = ((64 - colorW) * epB[e0] + colorW * epB[e1] + 32) >> 6;
          int a = alphaBits > 0
              ? (((64 - alphaW) * epA[e0] + alphaW * epA[e1] + 32) >> 6)
              : 255;

          if (rotation == 1) {
            final tmp = a;
            a = r;
            r = tmp;
          } else if (rotation == 2) {
            final tmp = a;
            a = g;
            g = tmp;
          } else if (rotation == 3) {
            final tmp = a;
            a = b;
            b = tmp;
          }

          final dstOff = (y * width + x) << 2;
          dst[dstOff] = r;
          dst[dstOff + 1] = g;
          dst[dstOff + 2] = b;
          dst[dstOff + 3] = a;
        }

        srcOff += 16;
      }
    }
  }

  static int _unquantizeBc7(int val, int bits) {
    return ((val << (8 - bits)) | (val >> (2 * bits - 8))) & 0xFF;
  }

  static int _bc7WeightForBits(int bits, int index) {
    switch (bits) {
      case 2:
        return bc7Weights2[index];
      case 3:
        return bc7Weights3[index];
      case 4:
        return bc7Weights4[index];
      default:
        return 0;
    }
  }
}
