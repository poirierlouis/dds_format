import 'dart:typed_data';

import 'package:dds_format/src/bcn/bc1_decoder.dart';
import 'package:dds_format/src/bcn/bc3_decoder.dart';
import 'package:dds_format/src/bcn/bc4_decoder.dart';
import 'package:dds_format/src/bcn/bc5_decoder.dart';
import 'package:dds_format/src/bcn/bc6h_decoder.dart';
import 'package:dds_format/src/bcn/bc7_decoder.dart';
import 'package:dds_format/src/dds_texture_format.dart';

/// Decodes block-compressed BCn (`BC1`..`BC7`) texture data into uncompressed
/// 8-bit-per-channel RGBA (`R8G8B8A8`) bytes.
final class BcnDecoder {
  const BcnDecoder._();

  static const BcnDecoder _instance = BcnDecoder._();

  /// Decodes a single mip level of [format] with dimensions [width] x [height]
  /// from [src] into a tightly packed `R8G8B8A8` [Uint8List] of length
  /// `width * height * 4`.
  static Uint8List decodeToRgba8({
    required DdsTextureFormat format,
    required Uint8List src,
    required int width,
    required int height,
  }) {
    final dst = Uint8List(width * height * 4);
    switch (format) {
      case DdsTextureFormat.bc1Unorm:
      case DdsTextureFormat.bc1UnormSrgb:
        _instance.decodeBc1(src, dst, width, height);
      case DdsTextureFormat.bc3Unorm:
      case DdsTextureFormat.bc3UnormSrgb:
        _instance.decodeBc3(src, dst, width, height);
      case DdsTextureFormat.bc4Unorm:
        _instance.decodeBc4(src, dst, width, height);
      case DdsTextureFormat.bc5Unorm:
        _instance.decodeBc5(src, dst, width, height);
      case DdsTextureFormat.bc6hUf16:
        _instance.decodeBc6hUf16(src, dst, width, height);
      case DdsTextureFormat.bc7Unorm:
      case DdsTextureFormat.bc7UnormSrgb:
        _instance.decodeBc7(src, dst, width, height);
      case DdsTextureFormat.r8g8b8a8Unorm:
      case DdsTextureFormat.r8g8b8a8UnormSrgb:
      case DdsTextureFormat.r8Unorm:
      case DdsTextureFormat.a8Unorm:
      case DdsTextureFormat.b8g8r8a8Unorm:
        throw ArgumentError.value(
          format,
          'format',
          'Format is not block-compressed.',
        );
    }
    return dst;
  }
}
