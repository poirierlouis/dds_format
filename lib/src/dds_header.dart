import 'dart:typed_data';

import 'package:dds_format/src/dds_reader.dart';
import 'package:dds_format/src/dds_texture_format.dart';

/// Internal representation of a parsed DDS header (`DDS_HEADER` + optional
/// `DDS_HEADER_DXT10`).
final class DdsHeader {
  const DdsHeader({
    required this.width,
    required this.height,
    required this.depth,
    required this.mipCount,
    required this.arraySize,
    required this.faceCount,
    required this.format,
    required this.resourceType,
    required this.isCubemap,
    required this.hasDx10Header,
    required this.dataOffset,
  });

  /// Magic number `"DDS "` in little-endian (`0x20534444`).
  static const int _magic = 0x20534444;
  static const int _headerSize = 124;
  static const int _pixelFormatSize = 32;
  static const int _baseTotalHeaderSize = 4 + _headerSize; // 128
  static const int _dx10HeaderSize = 20;

  // DDS_HEADER.dwFlags
  static const int _ddsdDepth = 0x800000;

  // DDS_PIXELFORMAT.dwFlags
  static const int _ddpfAlphaPixels = 0x1;
  static const int _ddpfAlpha = 0x2;
  static const int _ddpfFourCc = 0x4;
  static const int _ddpfRgb = 0x40;
  static const int _ddpfLuminance = 0x20000;

  // FourCC codes (little-endian uint32)
  static const int _fourCcDxt1 = 0x31545844; // 'DXT1'
  static const int _fourCcDxt5 = 0x35545844; // 'DXT5'
  static const int _fourCcAti1 = 0x31495441; // 'ATI1'
  static const int _fourCcBc4u = 0x55344342; // 'BC4U'
  static const int _fourCcAti2 = 0x32495441; // 'ATI2'
  static const int _fourCcBc5u = 0x55354342; // 'BC5U'
  static const int _fourCcDx10 = 0x30315844; // 'DX10'

  // DDS_HEADER.dwCaps2
  static const int _ddscaps2Cubemap = 0x200;
  static const int _ddscaps2Volume = 0x200000;

  // DX10 resourceDimension & miscFlag
  static const int _d3d10ResourceDimensionTexture1D = 2;
  static const int _d3d10ResourceDimensionTexture2D = 3;
  static const int _d3d10ResourceDimensionTexture3D = 4;
  static const int _d3d11ResourceMiscTextureCube = 0x4;

  final int width;
  final int height;
  final int depth;
  final int mipCount;
  final int arraySize;
  final int faceCount;
  final DdsTextureFormat format;
  final DdsResourceType resourceType;
  final bool isCubemap;
  final bool hasDx10Header;
  final int dataOffset;

  /// Parses and validates a DDS header from [bytes].
  static DdsHeader parse(Uint8List bytes) {
    if (bytes.length < _baseTotalHeaderSize) {
      throw DdsFormatException(
        'Buffer too small for DDS header: expected at least '
        '$_baseTotalHeaderSize bytes, got ${bytes.length}.',
        0,
      );
    }

    final view = ByteData.sublistView(bytes);

    final magic = view.getUint32(0, Endian.little);
    if (magic != _magic) {
      throw DdsFormatException(
        'Invalid DDS magic number: 0x${magic.toRadixString(16).padLeft(8, '0')}.',
        0,
      );
    }

    final dwSize = view.getUint32(4, Endian.little);
    if (dwSize != _headerSize) {
      throw DdsFormatException(
        'Invalid DDS_HEADER.dwSize: expected $_headerSize, got $dwSize.',
        4,
      );
    }

    final dwFlags = view.getUint32(8, Endian.little);
    final dwHeight = view.getUint32(12, Endian.little);
    final dwWidth = view.getUint32(16, Endian.little);
    final dwDepth = view.getUint32(24, Endian.little);
    final dwMipMapCount = view.getUint32(28, Endian.little);

    if (dwWidth == 0 || dwHeight == 0) {
      throw DdsFormatException(
        'Invalid texture dimensions: ${dwWidth}x$dwHeight.',
        12,
      );
    }

    // DDS_PIXELFORMAT starts at byte offset 76.
    final pfSize = view.getUint32(76, Endian.little);
    if (pfSize != _pixelFormatSize) {
      throw DdsFormatException(
        'Invalid DDS_PIXELFORMAT.dwSize: expected $_pixelFormatSize, got $pfSize.',
        76,
      );
    }

    final pfFlags = view.getUint32(80, Endian.little);
    final pfFourCc = view.getUint32(84, Endian.little);
    final pfRgbBitCount = view.getUint32(88, Endian.little);
    final pfRBitMask = view.getUint32(92, Endian.little);
    final pfGBitMask = view.getUint32(96, Endian.little);
    final pfBBitMask = view.getUint32(100, Endian.little);
    final pfABitMask = view.getUint32(104, Endian.little);

    final dwCaps2 = view.getUint32(112, Endian.little);

    final hasFourCc = (pfFlags & _ddpfFourCc) != 0;
    final hasDx10 = hasFourCc && pfFourCc == _fourCcDx10;
    final mipCount = dwMipMapCount > 0 ? dwMipMapCount : 1;

    if (hasDx10) {
      const totalWithDx10 = _baseTotalHeaderSize + _dx10HeaderSize;
      if (bytes.length < totalWithDx10) {
        throw DdsFormatException(
          'Buffer too small for DDS_HEADER_DXT10: expected at least '
          '$totalWithDx10 bytes, got ${bytes.length}.',
          _baseTotalHeaderSize,
        );
      }

      final dxgiFormatCode = view.getUint32(128, Endian.little);
      final format = DdsTextureFormat.fromDxgiCode(dxgiFormatCode);
      if (format == null) {
        throw DdsFormatException(
          'Unsupported DXGI_FORMAT code: $dxgiFormatCode.',
          128,
        );
      }

      final resourceDimension = view.getUint32(132, Endian.little);
      final miscFlag = view.getUint32(136, Endian.little);
      final rawArraySize = view.getUint32(140, Endian.little);

      if (resourceDimension != _d3d10ResourceDimensionTexture1D &&
          resourceDimension != _d3d10ResourceDimensionTexture2D &&
          resourceDimension != _d3d10ResourceDimensionTexture3D) {
        throw DdsFormatException(
          'Unsupported D3D10_RESOURCE_DIMENSION: $resourceDimension.',
          132,
        );
      }

      final is3D = resourceDimension == _d3d10ResourceDimensionTexture3D;
      final isCubemap = !is3D && (miscFlag & _d3d11ResourceMiscTextureCube) != 0;
      final resourceType = is3D
          ? DdsResourceType.texture3D
          : (isCubemap
              ? DdsResourceType.textureCube
              : DdsResourceType.texture2D);
      final faceCount = isCubemap ? 6 : 1;
      final depth = is3D ? (dwDepth > 0 ? dwDepth : 1) : 1;
      final arraySize = is3D ? 1 : (rawArraySize > 0 ? rawArraySize : 1);

      return DdsHeader(
        width: dwWidth,
        height: dwHeight,
        depth: depth,
        mipCount: mipCount,
        arraySize: arraySize,
        faceCount: faceCount,
        format: format,
        resourceType: resourceType,
        isCubemap: isCubemap,
        hasDx10Header: true,
        dataOffset: totalWithDx10,
      );
    }

    // Legacy header format resolution.
    final format = _resolveLegacyFormat(
      pfFlags: pfFlags,
      pfFourCc: pfFourCc,
      rgbBitCount: pfRgbBitCount,
      rMask: pfRBitMask,
      gMask: pfGBitMask,
      bMask: pfBBitMask,
      aMask: pfABitMask,
    );

    final isCubemap = (dwCaps2 & _ddscaps2Cubemap) != 0;
    final isVolume =
        !isCubemap &&
        ((dwCaps2 & _ddscaps2Volume) != 0 ||
            ((dwFlags & _ddsdDepth) != 0 && dwDepth > 1));

    final DdsResourceType resourceType;
    final int faceCount;
    final int depth;

    if (isCubemap) {
      resourceType = DdsResourceType.textureCube;
      faceCount = 6;
      depth = 1;
    } else if (isVolume) {
      resourceType = DdsResourceType.texture3D;
      faceCount = 1;
      depth = dwDepth > 0 ? dwDepth : 1;
    } else {
      resourceType = DdsResourceType.texture2D;
      faceCount = 1;
      depth = 1;
    }

    return DdsHeader(
      width: dwWidth,
      height: dwHeight,
      depth: depth,
      mipCount: mipCount,
      arraySize: 1,
      faceCount: faceCount,
      format: format,
      resourceType: resourceType,
      isCubemap: isCubemap,
      hasDx10Header: false,
      dataOffset: _baseTotalHeaderSize,
    );
  }

  static DdsTextureFormat _resolveLegacyFormat({
    required int pfFlags,
    required int pfFourCc,
    required int rgbBitCount,
    required int rMask,
    required int gMask,
    required int bMask,
    required int aMask,
  }) {
    if ((pfFlags & _ddpfFourCc) != 0) {
      return switch (pfFourCc) {
        _fourCcDxt1 => DdsTextureFormat.bc1Unorm,
        _fourCcDxt5 => DdsTextureFormat.bc3Unorm,
        _fourCcAti1 || _fourCcBc4u => DdsTextureFormat.bc4Unorm,
        _fourCcAti2 || _fourCcBc5u => DdsTextureFormat.bc5Unorm,
        _ => throw DdsFormatException(
          'Unsupported DDS FourCC: ${_fourCcToString(pfFourCc)} '
          '(0x${pfFourCc.toRadixString(16).padLeft(8, '0')}).',
          84,
        ),
      };
    }

    final hasAlphaPixels = (pfFlags & _ddpfAlphaPixels) != 0;

    if ((pfFlags & _ddpfRgb) != 0 && rgbBitCount == 32 && hasAlphaPixels) {
      if (rMask == 0x000000ff &&
          gMask == 0x0000ff00 &&
          bMask == 0x00ff0000 &&
          aMask == 0xff000000) {
        return DdsTextureFormat.r8g8b8a8Unorm;
      }
      if (rMask == 0x00ff0000 &&
          gMask == 0x0000ff00 &&
          bMask == 0x000000ff &&
          aMask == 0xff000000) {
        return DdsTextureFormat.b8g8r8a8Unorm;
      }
    }

    if ((pfFlags & _ddpfLuminance) != 0 &&
        rgbBitCount == 8 &&
        !hasAlphaPixels &&
        rMask == 0x000000ff) {
      return DdsTextureFormat.r8Unorm;
    }

    if ((pfFlags & _ddpfAlpha) != 0 &&
        rgbBitCount == 8 &&
        aMask == 0x000000ff) {
      return DdsTextureFormat.a8Unorm;
    }

    throw DdsFormatException(
      'Unsupported legacy DDS_PIXELFORMAT '
      '(flags=0x${pfFlags.toRadixString(16)}, bpp=$rgbBitCount, '
      'masks=0x${rMask.toRadixString(16)}/'
      '0x${gMask.toRadixString(16)}/'
      '0x${bMask.toRadixString(16)}/'
      '0x${aMask.toRadixString(16)}).',
      80,
    );
  }

  static String _fourCcToString(int fourCc) {
    final chars = <int>[
      fourCc & 0xff,
      (fourCc >> 8) & 0xff,
      (fourCc >> 16) & 0xff,
      (fourCc >> 24) & 0xff,
    ];
    return String.fromCharCodes(
      chars.map((c) => (c >= 0x20 && c <= 0x7e) ? c : 0x3f),
    );
  }
}
