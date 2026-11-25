import 'dart:typed_data';

import 'package:dds_format/src/bcn_decoder.dart';
import 'package:dds_format/src/dds_texture_format.dart';

/// Internal unified pixel decoder converting both block-compressed (BCn) and
/// uncompressed DDS surfaces to tightly packed 8-bit `R8G8B8A8` bytes.
abstract final class PixelDecoder {
  /// Decodes a single 2D surface slice of [format] with dimensions
  /// [width] x [height] from [src] into a new `R8G8B8A8` [Uint8List] of length
  /// `width * height * 4`.
  static Uint8List decodeToRgba8({
    required DdsTextureFormat format,
    required Uint8List src,
    required int width,
    required int height,
  }) {
    if (format.isBlockCompressed) {
      return BcnDecoder.decodeToRgba8(
        format: format,
        src: src,
        width: width,
        height: height,
      );
    }

    final pixelCount = width * height;
    final dst = Uint8List(pixelCount * 4);

    switch (format) {
      case DdsTextureFormat.r8g8b8a8Unorm:
      case DdsTextureFormat.r8g8b8a8UnormSrgb:
        dst.setRange(0, dst.length, src);
      case DdsTextureFormat.b8g8r8Unorm:
        for (int i = 0, srcOff = 0; i < dst.length; i += 4, srcOff += 3) {
          dst[i] = src[srcOff + 2];
          dst[i + 1] = src[srcOff + 1];
          dst[i + 2] = src[srcOff];
          dst[i + 3] = 255;
        }
      case DdsTextureFormat.b8g8r8a8Unorm:
        for (int i = 0; i < dst.length; i += 4) {
          dst[i] = src[i + 2];
          dst[i + 1] = src[i + 1];
          dst[i + 2] = src[i];
          dst[i + 3] = src[i + 3];
        }
      case DdsTextureFormat.r8Unorm:
        for (int i = 0; i < pixelCount; i++) {
          final dstOff = i << 2;
          dst[dstOff] = src[i];
          dst[dstOff + 1] = 0;
          dst[dstOff + 2] = 0;
          dst[dstOff + 3] = 255;
        }
      case DdsTextureFormat.a8Unorm:
        for (int i = 0; i < pixelCount; i++) {
          final dstOff = i << 2;
          dst[dstOff] = 0;
          dst[dstOff + 1] = 0;
          dst[dstOff + 2] = 0;
          dst[dstOff + 3] = src[i];
        }
      case DdsTextureFormat.bc1Unorm:
      case DdsTextureFormat.bc1UnormSrgb:
      case DdsTextureFormat.bc3Unorm:
      case DdsTextureFormat.bc3UnormSrgb:
      case DdsTextureFormat.bc4Unorm:
      case DdsTextureFormat.bc5Unorm:
      case DdsTextureFormat.bc6hUf16:
      case DdsTextureFormat.bc7Unorm:
      case DdsTextureFormat.bc7UnormSrgb:
        throw StateError('Unreachable block-compressed format: $format');
    }

    return dst;
  }
}
