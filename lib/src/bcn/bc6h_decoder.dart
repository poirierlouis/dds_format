import 'dart:typed_data';

import 'package:dds_format/src/bcn/bcn_utils.dart';
import 'package:dds_format/src/bcn_decoder.dart';

/// BC6H (UF16 - unsigned half-float) block decoder extension on [BcnDecoder].
extension Bc6hDecoder on BcnDecoder {
  void decodeBc6hUf16(Uint8List src, Uint8List dst, int width, int height) {
    final blocksX = (width + 3) >> 2;
    final blocksY = (height + 3) >> 2;

    final r0 = Int32List(2);
    final g0 = Int32List(2);
    final b0 = Int32List(2);
    final r1 = Int32List(2);
    final g1 = Int32List(2);
    final b1 = Int32List(2);

    int srcOff = 0;
    for (int by = 0; by < blocksY; by++) {
      final baseY = by << 2;
      for (int bx = 0; bx < blocksX; bx++) {
        final baseX = bx << 2;
        final b0Byte = src[srcOff];
        final mode2 = b0Byte & 0x03;
        final int mode5 = b0Byte & 0x1F;

        int mode = -1;
        if (mode2 == 0) {
          mode = 0;
        } else if (mode2 == 1) {
          mode = 1;
        } else {
          switch (mode5) {
            case 2:
              mode = 2;
            case 6:
              mode = 3;
            case 10:
              mode = 4;
            case 14:
              mode = 5;
            case 18:
              mode = 6;
            case 22:
              mode = 7;
            case 26:
              mode = 8;
            case 30:
              mode = 9;
            case 3:
              mode = 10;
            case 7:
              mode = 11;
            case 11:
              mode = 12;
            case 15:
              mode = 13;
          }
        }

        if (mode == -1) {
          fillBlackBlock(dst, width, height, baseX, baseY);
          srcOff += 16;
          continue;
        }

        final isTwoSubset = mode <= 9;
        int partition = 0;
        int epBits = 10;
        int dR = 5;
        int dG = 5;
        int dB = 5;
        bool transformed = true;

        switch (mode) {
          case 0:
            epBits = 10;
            dR = 5;
            dG = 5;
            dB = 5;
            r0[0] = readBits(src, srcOff, 5, 10);
            g0[0] = readBits(src, srcOff, 15, 10);
            b0[0] = readBits(src, srcOff, 25, 10);
            r1[0] = readBits(src, srcOff, 35, 5);
            g1[0] = readBits(src, srcOff, 45, 5);
            b1[0] = readBits(src, srcOff, 55, 5);
            r0[1] = readBits(src, srcOff, 65, 5);
            g0[1] =
                readBits(src, srcOff, 41, 4) |
                (readBits(src, srcOff, 2, 1) << 4);
            b0[1] =
                readBits(src, srcOff, 61, 4) |
                (readBits(src, srcOff, 3, 1) << 4);
            r1[1] = readBits(src, srcOff, 71, 5);
            g1[1] =
                readBits(src, srcOff, 51, 4) |
                (readBits(src, srcOff, 40, 1) << 4);
            b1[1] =
                readBits(src, srcOff, 50, 1) |
                (readBits(src, srcOff, 60, 1) << 1) |
                (readBits(src, srcOff, 70, 1) << 2) |
                (readBits(src, srcOff, 76, 1) << 3) |
                (readBits(src, srcOff, 4, 1) << 4);
          case 1:
            epBits = 7;
            dR = 6;
            dG = 6;
            dB = 6;
            r0[0] = readBits(src, srcOff, 5, 7);
            g0[0] = readBits(src, srcOff, 15, 7);
            b0[0] = readBits(src, srcOff, 25, 7);
            r1[0] = readBits(src, srcOff, 35, 6);
            g1[0] = readBits(src, srcOff, 45, 6);
            b1[0] = readBits(src, srcOff, 55, 6);
            r0[1] = readBits(src, srcOff, 65, 6);
            g0[1] =
                readBits(src, srcOff, 41, 4) |
                (readBits(src, srcOff, 24, 1) << 4) |
                (readBits(src, srcOff, 2, 1) << 5);
            b0[1] =
                readBits(src, srcOff, 61, 4) |
                (readBits(src, srcOff, 14, 1) << 4) |
                (readBits(src, srcOff, 3, 1) << 5);
            r1[1] = readBits(src, srcOff, 71, 6);
            g1[1] =
                readBits(src, srcOff, 51, 4) |
                (readBits(src, srcOff, 4, 1) << 4) |
                (readBits(src, srcOff, 32, 1) << 5);
            b1[1] =
                readBits(src, srcOff, 12, 1) |
                (readBits(src, srcOff, 13, 1) << 1) |
                (readBits(src, srcOff, 22, 1) << 2) |
                (readBits(src, srcOff, 23, 1) << 3) |
                (readBits(src, srcOff, 33, 1) << 4) |
                (readBits(src, srcOff, 34, 1) << 5);
          case 2:
            epBits = 11;
            dR = 5;
            dG = 4;
            dB = 4;
            r0[0] =
                readBits(src, srcOff, 5, 10) |
                (readBits(src, srcOff, 40, 1) << 10);
            g0[0] =
                readBits(src, srcOff, 15, 10) |
                (readBits(src, srcOff, 49, 1) << 10);
            b0[0] =
                readBits(src, srcOff, 25, 10) |
                (readBits(src, srcOff, 59, 1) << 10);
            r1[0] = readBits(src, srcOff, 35, 5);
            g1[0] = readBits(src, srcOff, 45, 4);
            b1[0] = readBits(src, srcOff, 55, 4);
            r0[1] = readBits(src, srcOff, 65, 5);
            g0[1] = readBits(src, srcOff, 41, 4);
            b0[1] = readBits(src, srcOff, 61, 4);
            r1[1] = readBits(src, srcOff, 71, 5);
            g1[1] = readBits(src, srcOff, 51, 4);
            b1[1] =
                readBits(src, srcOff, 50, 1) |
                (readBits(src, srcOff, 60, 1) << 1) |
                (readBits(src, srcOff, 70, 1) << 2) |
                (readBits(src, srcOff, 76, 1) << 3);
          case 3:
            epBits = 11;
            dR = 4;
            dG = 5;
            dB = 4;
            r0[0] =
                readBits(src, srcOff, 5, 10) |
                (readBits(src, srcOff, 39, 1) << 10);
            g0[0] =
                readBits(src, srcOff, 15, 10) |
                (readBits(src, srcOff, 50, 1) << 10);
            b0[0] =
                readBits(src, srcOff, 25, 10) |
                (readBits(src, srcOff, 59, 1) << 10);
            r1[0] = readBits(src, srcOff, 35, 4);
            g1[0] = readBits(src, srcOff, 45, 5);
            b1[0] = readBits(src, srcOff, 55, 4);
            r0[1] = readBits(src, srcOff, 65, 4);
            g0[1] =
                readBits(src, srcOff, 41, 4) |
                (readBits(src, srcOff, 75, 1) << 4);
            b0[1] = readBits(src, srcOff, 61, 4);
            r1[1] = readBits(src, srcOff, 71, 4);
            g1[1] =
                readBits(src, srcOff, 51, 4) |
                (readBits(src, srcOff, 40, 1) << 4);
            b1[1] =
                readBits(src, srcOff, 69, 1) |
                (readBits(src, srcOff, 60, 1) << 1) |
                (readBits(src, srcOff, 70, 1) << 2) |
                (readBits(src, srcOff, 76, 1) << 3);
          case 4:
            epBits = 11;
            dR = 4;
            dG = 4;
            dB = 5;
            r0[0] =
                readBits(src, srcOff, 5, 10) |
                (readBits(src, srcOff, 39, 1) << 10);
            g0[0] =
                readBits(src, srcOff, 15, 10) |
                (readBits(src, srcOff, 49, 1) << 10);
            b0[0] =
                readBits(src, srcOff, 25, 10) |
                (readBits(src, srcOff, 60, 1) << 10);
            r1[0] = readBits(src, srcOff, 35, 4);
            g1[0] = readBits(src, srcOff, 45, 4);
            b1[0] = readBits(src, srcOff, 55, 5);
            r0[1] = readBits(src, srcOff, 65, 4);
            g0[1] = readBits(src, srcOff, 41, 4);
            b0[1] =
                readBits(src, srcOff, 61, 4) |
                (readBits(src, srcOff, 40, 1) << 4);
            r1[1] = readBits(src, srcOff, 71, 4);
            g1[1] = readBits(src, srcOff, 51, 4);
            b1[1] =
                readBits(src, srcOff, 50, 1) |
                (readBits(src, srcOff, 69, 1) << 1) |
                (readBits(src, srcOff, 70, 1) << 2) |
                (readBits(src, srcOff, 76, 1) << 3) |
                (readBits(src, srcOff, 75, 1) << 4);
          case 5:
            epBits = 9;
            dR = 5;
            dG = 5;
            dB = 5;
            r0[0] = readBits(src, srcOff, 5, 9);
            g0[0] = readBits(src, srcOff, 15, 9);
            b0[0] = readBits(src, srcOff, 25, 9);
            r1[0] = readBits(src, srcOff, 35, 5);
            g1[0] = readBits(src, srcOff, 45, 5);
            b1[0] = readBits(src, srcOff, 55, 5);
            r0[1] = readBits(src, srcOff, 65, 5);
            g0[1] =
                readBits(src, srcOff, 41, 4) |
                (readBits(src, srcOff, 24, 1) << 4);
            b0[1] =
                readBits(src, srcOff, 61, 4) |
                (readBits(src, srcOff, 14, 1) << 4);
            r1[1] = readBits(src, srcOff, 71, 5);
            g1[1] =
                readBits(src, srcOff, 51, 4) |
                (readBits(src, srcOff, 40, 1) << 4);
            b1[1] =
                readBits(src, srcOff, 50, 1) |
                (readBits(src, srcOff, 60, 1) << 1) |
                (readBits(src, srcOff, 70, 1) << 2) |
                (readBits(src, srcOff, 76, 1) << 3) |
                (readBits(src, srcOff, 34, 1) << 4);
          case 6:
            epBits = 8;
            dR = 6;
            dG = 5;
            dB = 5;
            r0[0] = readBits(src, srcOff, 5, 8);
            g0[0] = readBits(src, srcOff, 15, 8);
            b0[0] = readBits(src, srcOff, 25, 8);
            r1[0] = readBits(src, srcOff, 35, 6);
            g1[0] = readBits(src, srcOff, 45, 5);
            b1[0] = readBits(src, srcOff, 55, 5);
            r0[1] = readBits(src, srcOff, 65, 6);
            g0[1] =
                readBits(src, srcOff, 41, 4) |
                (readBits(src, srcOff, 24, 1) << 4);
            b0[1] =
                readBits(src, srcOff, 61, 4) |
                (readBits(src, srcOff, 14, 1) << 4);
            r1[1] = readBits(src, srcOff, 71, 6);
            g1[1] =
                readBits(src, srcOff, 51, 4) |
                (readBits(src, srcOff, 13, 1) << 4);
            b1[1] =
                readBits(src, srcOff, 50, 1) |
                (readBits(src, srcOff, 60, 1) << 1) |
                (readBits(src, srcOff, 23, 1) << 2) |
                (readBits(src, srcOff, 33, 1) << 3) |
                (readBits(src, srcOff, 34, 1) << 4);
          case 7:
            epBits = 8;
            dR = 5;
            dG = 6;
            dB = 5;
            r0[0] = readBits(src, srcOff, 5, 8);
            g0[0] = readBits(src, srcOff, 15, 8);
            b0[0] = readBits(src, srcOff, 25, 8);
            r1[0] = readBits(src, srcOff, 35, 5);
            g1[0] = readBits(src, srcOff, 45, 6);
            b1[0] = readBits(src, srcOff, 55, 5);
            r0[1] = readBits(src, srcOff, 65, 5);
            g0[1] =
                readBits(src, srcOff, 41, 4) |
                (readBits(src, srcOff, 24, 1) << 4) |
                (readBits(src, srcOff, 23, 1) << 5);
            b0[1] =
                readBits(src, srcOff, 61, 4) |
                (readBits(src, srcOff, 14, 1) << 4);
            r1[1] = readBits(src, srcOff, 71, 5);
            g1[1] =
                readBits(src, srcOff, 51, 4) |
                (readBits(src, srcOff, 40, 1) << 4) |
                (readBits(src, srcOff, 33, 1) << 5);
            b1[1] =
                readBits(src, srcOff, 13, 1) |
                (readBits(src, srcOff, 60, 1) << 1) |
                (readBits(src, srcOff, 70, 1) << 2) |
                (readBits(src, srcOff, 76, 1) << 3) |
                (readBits(src, srcOff, 34, 1) << 4);
          case 8:
            epBits = 8;
            dR = 5;
            dG = 5;
            dB = 6;
            r0[0] = readBits(src, srcOff, 5, 8);
            g0[0] = readBits(src, srcOff, 15, 8);
            b0[0] = readBits(src, srcOff, 25, 8);
            r1[0] = readBits(src, srcOff, 35, 5);
            g1[0] = readBits(src, srcOff, 45, 5);
            b1[0] = readBits(src, srcOff, 55, 6);
            r0[1] = readBits(src, srcOff, 65, 5);
            g0[1] =
                readBits(src, srcOff, 41, 4) |
                (readBits(src, srcOff, 24, 1) << 4);
            b0[1] =
                readBits(src, srcOff, 61, 4) |
                (readBits(src, srcOff, 14, 1) << 4) |
                (readBits(src, srcOff, 23, 1) << 5);
            r1[1] = readBits(src, srcOff, 71, 5);
            g1[1] =
                readBits(src, srcOff, 51, 4) |
                (readBits(src, srcOff, 40, 1) << 4);
            b1[1] =
                readBits(src, srcOff, 50, 1) |
                (readBits(src, srcOff, 13, 1) << 1) |
                (readBits(src, srcOff, 70, 1) << 2) |
                (readBits(src, srcOff, 76, 1) << 3) |
                (readBits(src, srcOff, 34, 1) << 4) |
                (readBits(src, srcOff, 33, 1) << 5);
          case 9:
            transformed = false;
            epBits = 6;
            dR = 6;
            dG = 6;
            dB = 6;
            r0[0] = readBits(src, srcOff, 5, 6);
            g0[0] = readBits(src, srcOff, 15, 6);
            b0[0] = readBits(src, srcOff, 25, 6);
            r1[0] = readBits(src, srcOff, 35, 6);
            g1[0] = readBits(src, srcOff, 45, 6);
            b1[0] = readBits(src, srcOff, 55, 6);
            r0[1] = readBits(src, srcOff, 65, 6);
            g0[1] =
                readBits(src, srcOff, 41, 4) |
                (readBits(src, srcOff, 24, 1) << 4) |
                (readBits(src, srcOff, 21, 1) << 5);
            b0[1] =
                readBits(src, srcOff, 61, 4) |
                (readBits(src, srcOff, 14, 1) << 4) |
                (readBits(src, srcOff, 11, 1) << 5);
            r1[1] = readBits(src, srcOff, 71, 6);
            g1[1] =
                readBits(src, srcOff, 51, 4) |
                (readBits(src, srcOff, 31, 1) << 4) |
                (readBits(src, srcOff, 32, 1) << 5);
            b1[1] =
                readBits(src, srcOff, 12, 1) |
                (readBits(src, srcOff, 13, 1) << 1) |
                (readBits(src, srcOff, 22, 1) << 2) |
                (readBits(src, srcOff, 23, 1) << 3) |
                (readBits(src, srcOff, 33, 1) << 4) |
                (readBits(src, srcOff, 34, 1) << 5);
          case 10:
            transformed = false;
            epBits = 10;
            r0[0] = readBits(src, srcOff, 5, 10);
            g0[0] = readBits(src, srcOff, 15, 10);
            b0[0] = readBits(src, srcOff, 25, 10);
            r1[0] = readBits(src, srcOff, 35, 10);
            g1[0] = readBits(src, srcOff, 45, 10);
            b1[0] = readBits(src, srcOff, 55, 10);
          case 11:
            epBits = 11;
            dR = 9;
            dG = 9;
            dB = 9;
            r0[0] =
                readBits(src, srcOff, 5, 10) |
                (readBits(src, srcOff, 44, 1) << 10);
            g0[0] =
                readBits(src, srcOff, 15, 10) |
                (readBits(src, srcOff, 54, 1) << 10);
            b0[0] =
                readBits(src, srcOff, 25, 10) |
                (readBits(src, srcOff, 64, 1) << 10);
            r1[0] = readBits(src, srcOff, 35, 9);
            g1[0] = readBits(src, srcOff, 45, 9);
            b1[0] = readBits(src, srcOff, 55, 9);
          case 12:
            epBits = 12;
            dR = 8;
            dG = 8;
            dB = 8;
            r0[0] =
                readBits(src, srcOff, 5, 10) |
                (readBits(src, srcOff, 43, 2) << 10);
            g0[0] =
                readBits(src, srcOff, 15, 10) |
                (readBits(src, srcOff, 53, 2) << 10);
            b0[0] =
                readBits(src, srcOff, 25, 10) |
                (readBits(src, srcOff, 63, 2) << 10);
            r1[0] = readBits(src, srcOff, 35, 8);
            g1[0] = readBits(src, srcOff, 45, 8);
            b1[0] = readBits(src, srcOff, 55, 8);
          case 13:
            epBits = 16;
            dR = 4;
            dG = 4;
            dB = 4;
            r0[0] =
                readBits(src, srcOff, 5, 10) |
                (readBits(src, srcOff, 39, 6) << 10);
            g0[0] =
                readBits(src, srcOff, 15, 10) |
                (readBits(src, srcOff, 49, 6) << 10);
            b0[0] =
                readBits(src, srcOff, 25, 10) |
                (readBits(src, srcOff, 59, 6) << 10);
            r1[0] = readBits(src, srcOff, 35, 4);
            g1[0] = readBits(src, srcOff, 45, 4);
            b1[0] = readBits(src, srcOff, 55, 4);
        }

        if (isTwoSubset) {
          partition = readBits(src, srcOff, 77, 5);
        }

        final mask = (1 << epBits) - 1;
        if (transformed) {
          r1[0] = (r0[0] + _signExtend(r1[0], dR)) & mask;
          g1[0] = (g0[0] + _signExtend(g1[0], dG)) & mask;
          b1[0] = (b0[0] + _signExtend(b1[0], dB)) & mask;
          if (isTwoSubset) {
            r0[1] = (r0[0] + _signExtend(r0[1], dR)) & mask;
            g0[1] = (g0[0] + _signExtend(g0[1], dG)) & mask;
            b0[1] = (b0[0] + _signExtend(b0[1], dB)) & mask;
            r1[1] = (r0[0] + _signExtend(r1[1], dR)) & mask;
            g1[1] = (g0[0] + _signExtend(g1[1], dG)) & mask;
            b1[1] = (b0[0] + _signExtend(b1[1], dB)) & mask;
          }
        }

        final numSubsets = isTwoSubset ? 2 : 1;
        for (int s = 0; s < numSubsets; s++) {
          r0[s] = _unquantizeBc6hUnsigned(r0[s], epBits);
          g0[s] = _unquantizeBc6hUnsigned(g0[s], epBits);
          b0[s] = _unquantizeBc6hUnsigned(b0[s], epBits);
          r1[s] = _unquantizeBc6hUnsigned(r1[s], epBits);
          g1[s] = _unquantizeBc6hUnsigned(g1[s], epBits);
          b1[s] = _unquantizeBc6hUnsigned(b1[s], epBits);
        }

        int bitPos = isTwoSubset ? 82 : 65;
        final indexBits = isTwoSubset ? 3 : 4;
        final weights = isTwoSubset ? bc7Weights3 : bc7Weights4;

        for (int i = 0; i < 16; i++) {
          final subset = isTwoSubset ? bc6hPartition2[partition][i] : 0;
          final isAnchor =
              i == 0 || (isTwoSubset && i == bc7Anchor2[partition]);
          final bitsToRead = isAnchor ? indexBits - 1 : indexBits;
          final idx = readBits(src, srcOff, bitPos, bitsToRead);
          bitPos += bitsToRead;

          final px = i & 3;
          final py = i >> 2;
          final x = baseX + px;
          final y = baseY + py;
          if (x < width && y < height) {
            final w = weights[idx];
            final rQ = ((64 - w) * r0[subset] + w * r1[subset] + 32) >> 6;
            final gQ = ((64 - w) * g0[subset] + w * g1[subset] + 32) >> 6;
            final bQ = ((64 - w) * b0[subset] + w * b1[subset] + 32) >> 6;

            final dstOff = (y * width + x) << 2;
            dst[dstOff] = _f16ToUnorm8(_finishBc6hUnsigned(rQ));
            dst[dstOff + 1] = _f16ToUnorm8(_finishBc6hUnsigned(gQ));
            dst[dstOff + 2] = _f16ToUnorm8(_finishBc6hUnsigned(bQ));
            dst[dstOff + 3] = 255;
          }
        }

        srcOff += 16;
      }
    }
  }

  static int _signExtend(int val, int bits) {
    final signBit = 1 << (bits - 1);
    if ((val & signBit) != 0) {
      return val | (~((1 << bits) - 1));
    }
    return val;
  }

  static int _unquantizeBc6hUnsigned(int val, int bits) {
    if (bits >= 15) {
      return val;
    }
    if (val == 0) {
      return 0;
    }
    if (val == (1 << bits) - 1) {
      return 0xFFFF;
    }
    return ((val << 16) + 0x8000) >> bits;
  }

  static int _finishBc6hUnsigned(int val) {
    return (val * 31) >> 6;
  }

  static int _f16ToUnorm8(int f16) {
    final exp = (f16 >> 10) & 0x1F;
    final mant = f16 & 0x3FF;
    double v;
    if (exp == 0) {
      v = mant / 1024.0 / 16384.0;
    } else if (exp == 31) {
      v = mant == 0 ? 1.0 : 0.0;
    } else {
      final base = exp >= 15
          ? (1.0 + mant / 1024.0) * (1 << (exp - 15))
          : (1.0 + mant / 1024.0) / (1 << (15 - exp));
      v = base;
    }
    final clamped = v.clamp(0.0, 1.0);
    return (clamped * 255.0 + 0.5).toInt();
  }
}
