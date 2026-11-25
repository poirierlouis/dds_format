import 'dart:typed_data';

import 'package:dds_format/src/dds_header.dart';
import 'package:dds_format/src/dds_texture_format.dart';
import 'package:dds_format/src/pixel_decoder.dart';

/// Exception thrown when a DDS buffer is malformed, truncated, or uses an
/// unsupported format or header configuration.
class DdsFormatException implements FormatException {
  /// Creates a [DdsFormatException] with a descriptive [message] and optional
  /// byte [offset] in [source].
  const DdsFormatException(this.message, [this.offset, this.source]);

  @override
  final String message;

  @override
  final int? offset;

  @override
  final Object? source;

  @override
  String toString() {
    final off = offset;
    if (off != null) {
      return 'DdsFormatException: $message (at byte offset $off)';
    }
    return 'DdsFormatException: $message';
  }
}

/// The texture resource dimensionality and layout of a DDS file.
enum DdsResourceType {
  /// A 2D texture (or 2D texture array when `arraySize > 1`).
  texture2D,

  /// A 3D volume texture with `depth >= 1`.
  texture3D,

  /// A 6-face cubemap texture (or cubemap array when `arraySize > 1`).
  textureCube,
}

/// Synchronous reader for DirectDraw Surface (`.dds`) files backed by an
/// in-memory [Uint8List] buffer.
///
/// Parses the DDS header and indexes all surface byte offsets on construction
/// without copying pixel data.
final class DdsReader {
  /// Parses a DDS file from [bytes] and indexes all declared surfaces.
  ///
  /// Throws [DdsFormatException] if the header is invalid, uses an unsupported
  /// format, or if [bytes] is truncated before the end of the declared surface
  /// data.
  DdsReader(Uint8List bytes) : _bytes = bytes, _header = DdsHeader.parse(bytes) {
    final mipCount = _header.mipCount;
    _mipStartSlice = List<int>.filled(mipCount, 0);
    _mipSliceSizes = List<int>.filled(mipCount, 0);

    int slicesPerFace = 0;
    for (int m = 0; m < mipCount; m++) {
      _mipStartSlice[m] = slicesPerFace;
      final mw = _computeMipDim(_header.width, m);
      final mh = _computeMipDim(_header.height, m);
      final md = _computeMipDim(_header.depth, m);
      _mipSliceSizes[m] = _header.format.mipByteSize(mw, mh);
      slicesPerFace += md;
    }
    _slicesPerFace = slicesPerFace;

    final totalSurfaces = _header.arraySize * _header.faceCount * slicesPerFace;
    _surfaceOffsets = List<int>.filled(totalSurfaces, 0);
    _surfaceLengths = List<int>.filled(totalSurfaces, 0);

    int offset = _header.dataOffset;
    int idx = 0;
    for (int a = 0; a < _header.arraySize; a++) {
      for (int f = 0; f < _header.faceCount; f++) {
        for (int m = 0; m < mipCount; m++) {
          final sliceSize = _mipSliceSizes[m];
          final md = _computeMipDim(_header.depth, m);
          for (int d = 0; d < md; d++) {
            _surfaceOffsets[idx] = offset;
            _surfaceLengths[idx] = sliceSize;
            offset += sliceSize;
            idx++;
          }
        }
      }
    }

    if (bytes.length < offset) {
      throw DdsFormatException(
        'Truncated DDS pixel data: expected at least $offset bytes, '
        'got ${bytes.length}.',
        bytes.length,
      );
    }
  }

  final Uint8List _bytes;
  final DdsHeader _header;
  late final List<int> _mipStartSlice;
  late final List<int> _mipSliceSizes;
  late final int _slicesPerFace;
  late final List<int> _surfaceOffsets;
  late final List<int> _surfaceLengths;

  /// Base texture width in pixels (mip level 0).
  int get width => _header.width;

  /// Base texture height in pixels (mip level 0).
  int get height => _header.height;

  /// Base texture depth in slices (mip level 0; `1` for 2D/cubemap textures).
  int get depth => _header.depth;

  /// Number of mipmap levels (`>= 1`).
  int get mipCount => _header.mipCount;

  /// Number of textures in the array (`1` for non-array textures).
  int get arraySize => _header.arraySize;

  /// Number of faces per array element (`6` for cubemaps, `1` otherwise).
  int get faceCount => _header.faceCount;

  /// Pixel/compression format of the texture.
  DdsTextureFormat get format => _header.format;

  /// Resource dimensionality of the texture.
  DdsResourceType get resourceType => _header.resourceType;

  /// Whether this texture is a 6-face cubemap.
  bool get isCubemap => _header.isCubemap;

  /// Whether the file contained a `DDS_HEADER_DXT10` extended header.
  bool get hasDx10Header => _header.hasDx10Header;

  /// Width in pixels at [mipLevel].
  int mipWidth(int mipLevel) {
    RangeError.checkValueInInterval(mipLevel, 0, mipCount - 1, 'mipLevel');
    return _computeMipDim(width, mipLevel);
  }

  /// Height in pixels at [mipLevel].
  int mipHeight(int mipLevel) {
    RangeError.checkValueInInterval(mipLevel, 0, mipCount - 1, 'mipLevel');
    return _computeMipDim(height, mipLevel);
  }

  /// Depth in slices at [mipLevel].
  int mipDepth(int mipLevel) {
    RangeError.checkValueInInterval(mipLevel, 0, mipCount - 1, 'mipLevel');
    return _computeMipDim(depth, mipLevel);
  }

  /// Returns a zero-copy [Uint8List] view of the raw surface bytes for the
  /// specified [arrayIndex], [face], [mipLevel], and [depthSlice].
  ///
  /// Throws [RangeError] if any index is out of bounds.
  Uint8List readRaw({
    int arrayIndex = 0,
    int face = 0,
    int mipLevel = 0,
    int depthSlice = 0,
  }) {
    final idx = _surfaceIndex(
      arrayIndex: arrayIndex,
      face: face,
      mipLevel: mipLevel,
      depthSlice: depthSlice,
    );
    final offset = _surfaceOffsets[idx];
    final length = _surfaceLengths[idx];
    return Uint8List.sublistView(_bytes, offset, offset + length);
  }

  /// Decodes the requested surface into a tightly packed `R8G8B8A8` [Uint8List]
  /// of length `mipWidth(mipLevel) * mipHeight(mipLevel) * 4`.
  ///
  /// Throws [RangeError] if any index is out of bounds.
  Uint8List readRgba8({
    int arrayIndex = 0,
    int face = 0,
    int mipLevel = 0,
    int depthSlice = 0,
  }) {
    final raw = readRaw(
      arrayIndex: arrayIndex,
      face: face,
      mipLevel: mipLevel,
      depthSlice: depthSlice,
    );
    return PixelDecoder.decodeToRgba8(
      format: format,
      src: raw,
      width: _computeMipDim(width, mipLevel),
      height: _computeMipDim(height, mipLevel),
    );
  }

  int _surfaceIndex({
    required int arrayIndex,
    required int face,
    required int mipLevel,
    required int depthSlice,
  }) {
    RangeError.checkValueInInterval(arrayIndex, 0, arraySize - 1, 'arrayIndex');
    RangeError.checkValueInInterval(face, 0, faceCount - 1, 'face');
    RangeError.checkValueInInterval(mipLevel, 0, mipCount - 1, 'mipLevel');
    final md = _computeMipDim(depth, mipLevel);
    RangeError.checkValueInInterval(depthSlice, 0, md - 1, 'depthSlice');

    return ((arrayIndex * faceCount + face) * _slicesPerFace) +
        _mipStartSlice[mipLevel] +
        depthSlice;
  }

  static int _computeMipDim(int base, int mipLevel) {
    final v = base >> mipLevel;
    return v > 0 ? v : 1;
  }
}
