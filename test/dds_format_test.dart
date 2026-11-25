import 'dart:typed_data';

import 'package:dds_format/dds_format.dart';
import 'package:test/test.dart';

int _fourCc(String code) {
  assert(code.length == 4);
  return code.codeUnitAt(0) |
      (code.codeUnitAt(1) << 8) |
      (code.codeUnitAt(2) << 16) |
      (code.codeUnitAt(3) << 24);
}

int _computeMipDim(int base, int mip) {
  final v = base >> mip;
  return v > 0 ? v : 1;
}

Uint8List _buildLegacyDds({
  required int width,
  required int height,
  int depth = 1,
  int mipCount = 1,
  required int pfFlags,
  int fourCc = 0,
  int rgbBitCount = 0,
  int rMask = 0,
  int gMask = 0,
  int bMask = 0,
  int aMask = 0,
  int caps2 = 0,
  required Uint8List payload,
}) {
  final bytes = Uint8List(128 + payload.length);
  final view = ByteData.sublistView(bytes);
  view.setUint32(0, 0x20534444, Endian.little);
  view.setUint32(4, 124, Endian.little);
  int flags = 0x1007;
  if (mipCount > 1) flags |= 0x20000;
  if (depth > 1) flags |= 0x800000;
  view.setUint32(8, flags, Endian.little);
  view.setUint32(12, height, Endian.little);
  view.setUint32(16, width, Endian.little);
  view.setUint32(24, depth, Endian.little);
  view.setUint32(28, mipCount, Endian.little);

  view.setUint32(76, 32, Endian.little);
  view.setUint32(80, pfFlags, Endian.little);
  view.setUint32(84, fourCc, Endian.little);
  view.setUint32(88, rgbBitCount, Endian.little);
  view.setUint32(92, rMask, Endian.little);
  view.setUint32(96, gMask, Endian.little);
  view.setUint32(100, bMask, Endian.little);
  view.setUint32(104, aMask, Endian.little);

  view.setUint32(108, 0x1000, Endian.little);
  view.setUint32(112, caps2, Endian.little);

  bytes.setRange(128, bytes.length, payload);
  return bytes;
}

Uint8List _buildDx10Dds({
  required int width,
  required int height,
  int depth = 1,
  int mipCount = 1,
  int arraySize = 1,
  required int dxgiFormat,
  int resourceDimension = 3, // TEXTURE2D
  int miscFlag = 0,
  required Uint8List payload,
}) {
  final bytes = Uint8List(148 + payload.length);
  final view = ByteData.sublistView(bytes);
  view.setUint32(0, 0x20534444, Endian.little);
  view.setUint32(4, 124, Endian.little);
  int flags = 0x1007;
  if (mipCount > 1) flags |= 0x20000;
  if (depth > 1) flags |= 0x800000;
  view.setUint32(8, flags, Endian.little);
  view.setUint32(12, height, Endian.little);
  view.setUint32(16, width, Endian.little);
  view.setUint32(24, depth, Endian.little);
  view.setUint32(28, mipCount, Endian.little);

  view.setUint32(76, 32, Endian.little);
  view.setUint32(80, 0x4, Endian.little); // DDPF_FOURCC
  view.setUint32(84, _fourCc('DX10'), Endian.little);

  view.setUint32(108, 0x1000, Endian.little);

  view.setUint32(128, dxgiFormat, Endian.little);
  view.setUint32(132, resourceDimension, Endian.little);
  view.setUint32(136, miscFlag, Endian.little);
  view.setUint32(140, arraySize, Endian.little);

  bytes.setRange(148, bytes.length, payload);
  return bytes;
}

int _totalSurfaceBytes(
  DdsTextureFormat format, {
  required int width,
  required int height,
  int depth = 1,
  int mipCount = 1,
  int faceCount = 1,
  int arraySize = 1,
}) {
  int perFace = 0;
  for (int m = 0; m < mipCount; m++) {
    final mw = _computeMipDim(width, m);
    final mh = _computeMipDim(height, m);
    final md = _computeMipDim(depth, m);
    perFace += format.mipByteSize(mw, mh) * md;
  }
  return perFace * faceCount * arraySize;
}

void main() {
  group('Header variants', () {
    test('parses DX10 header for all supported DdsTextureFormat values', () {
      for (final format in DdsTextureFormat.values) {
        final payloadLen = _totalSurfaceBytes(format, width: 4, height: 4);
        final dds = _buildDx10Dds(
          width: 4,
          height: 4,
          dxgiFormat: format.dxgiCode,
          payload: Uint8List(payloadLen),
        );
        final reader = DdsReader(dds);
        expect(reader.format, equals(format));
        expect(reader.hasDx10Header, isTrue);
        expect(reader.resourceType, equals(DdsResourceType.texture2D));
        expect(reader.width, equals(4));
        expect(reader.height, equals(4));
        expect(reader.depth, equals(1));
        expect(reader.mipCount, equals(1));
        expect(reader.arraySize, equals(1));
        expect(reader.faceCount, equals(1));
        expect(reader.isCubemap, isFalse);
      }
    });

    test('parses legacy FourCC codes', () {
      final cases = <String, DdsTextureFormat>{
        'DXT1': DdsTextureFormat.bc1Unorm,
        'DXT5': DdsTextureFormat.bc3Unorm,
        'ATI1': DdsTextureFormat.bc4Unorm,
        'BC4U': DdsTextureFormat.bc4Unorm,
        'ATI2': DdsTextureFormat.bc5Unorm,
        'BC5U': DdsTextureFormat.bc5Unorm,
      };
      for (final entry in cases.entries) {
        final payload = Uint8List(entry.value.mipByteSize(4, 4));
        final dds = _buildLegacyDds(
          width: 4,
          height: 4,
          pfFlags: 0x4,
          fourCc: _fourCc(entry.key),
          payload: payload,
        );
        final reader = DdsReader(dds);
        expect(reader.format, equals(entry.value));
        expect(reader.hasDx10Header, isFalse);
      }
    });

    test('parses legacy bitmask formats (RGBA8, BGRA8, R8, A8)', () {
      final rgba = _buildLegacyDds(
        width: 2,
        height: 2,
        pfFlags: 0x41,
        rgbBitCount: 32,
        rMask: 0x000000ff,
        gMask: 0x0000ff00,
        bMask: 0x00ff0000,
        aMask: 0xff000000,
        payload: Uint8List(16),
      );
      expect(DdsReader(rgba).format, equals(DdsTextureFormat.r8g8b8a8Unorm));

      final bgra = _buildLegacyDds(
        width: 2,
        height: 2,
        pfFlags: 0x41,
        rgbBitCount: 32,
        rMask: 0x00ff0000,
        gMask: 0x0000ff00,
        bMask: 0x000000ff,
        aMask: 0xff000000,
        payload: Uint8List(16),
      );
      expect(DdsReader(bgra).format, equals(DdsTextureFormat.b8g8r8a8Unorm));

      final r8 = _buildLegacyDds(
        width: 2,
        height: 2,
        pfFlags: 0x20000,
        rgbBitCount: 8,
        rMask: 0x000000ff,
        payload: Uint8List(4),
      );
      expect(DdsReader(r8).format, equals(DdsTextureFormat.r8Unorm));

      final a8 = _buildLegacyDds(
        width: 2,
        height: 2,
        pfFlags: 0x2,
        rgbBitCount: 8,
        aMask: 0x000000ff,
        payload: Uint8List(4),
      );
      expect(DdsReader(a8).format, equals(DdsTextureFormat.a8Unorm));
    });
  });

  group('Resource types & surface indexing', () {
    test('2D texture with mipmaps & zero-copy readRaw', () {
      const format = DdsTextureFormat.bc1Unorm;
      final total = _totalSurfaceBytes(
        format,
        width: 6,
        height: 5,
        mipCount: 4,
      );
      final payload = Uint8List(total);
      for (int i = 0; i < payload.length; i++) {
        payload[i] = i & 0xff;
      }

      final dds = _buildDx10Dds(
        width: 6,
        height: 5,
        mipCount: 4,
        dxgiFormat: format.dxgiCode,
        payload: payload,
      );
      final reader = DdsReader(dds);

      expect(reader.mipCount, equals(4));
      expect(reader.mipWidth(0), equals(6));
      expect(reader.mipHeight(0), equals(5));
      expect(reader.mipWidth(1), equals(3));
      expect(reader.mipHeight(1), equals(2));
      expect(reader.mipWidth(2), equals(1));
      expect(reader.mipHeight(2), equals(1));
      expect(reader.mipWidth(3), equals(1));
      expect(reader.mipHeight(3), equals(1));

      // Mip 0: 6x5 -> 2x2 blocks * 8 = 32 bytes
      final raw0 = reader.readRaw();
      expect(raw0.length, equals(32));
      expect(raw0[0], equals(0));
      dds[148] = 0xAB;
      expect(raw0[0], equals(0xAB)); // zero-copy view shares backing memory

      // Mip 1: 3x2 -> 1x1 block * 8 = 8 bytes, starting at offset 32
      final raw1 = reader.readRaw(mipLevel: 1);
      expect(raw1.length, equals(8));
      expect(raw1[0], equals(32));

      // Small mip 3: 1x1 -> 8 bytes, RGBA8 should be 1*1*4 = 4 bytes
      final rgba3 = reader.readRgba8(mipLevel: 3);
      expect(rgba3.length, equals(4));
    });

    test('Legacy and DX10 cubemaps', () {
      const format = DdsTextureFormat.r8Unorm;
      final total = _totalSurfaceBytes(
        format,
        width: 4,
        height: 4,
        mipCount: 2,
        faceCount: 6,
      );
      final payload = Uint8List(total);
      // Tag first byte of each face's mip 0 with face index + 10.
      const faceSize = 16 + 4; // 4x4 + 2x2
      for (int f = 0; f < 6; f++) {
        payload[f * faceSize] = f + 10;
        payload[f * faceSize + 16] = f + 100;
      }

      final legacyCube = _buildLegacyDds(
        width: 4,
        height: 4,
        mipCount: 2,
        pfFlags: 0x20000,
        rgbBitCount: 8,
        rMask: 0xff,
        caps2: 0xfe00, // DDSCAPS2_CUBEMAP | ALLFACES
        payload: payload,
      );
      final r1 = DdsReader(legacyCube);
      expect(r1.resourceType, equals(DdsResourceType.textureCube));
      expect(r1.isCubemap, isTrue);
      expect(r1.faceCount, equals(6));
      for (int f = 0; f < 6; f++) {
        expect(r1.readRaw(face: f, mipLevel: 0)[0], equals(f + 10));
        expect(r1.readRaw(face: f, mipLevel: 1)[0], equals(f + 100));
      }

      final dx10Cube = _buildDx10Dds(
        width: 4,
        height: 4,
        mipCount: 2,
        dxgiFormat: format.dxgiCode,
        miscFlag: 0x4, // D3D11_RESOURCE_MISC_TEXTURECUBE
        payload: payload,
      );
      final r2 = DdsReader(dx10Cube);
      expect(r2.resourceType, equals(DdsResourceType.textureCube));
      expect(r2.faceCount, equals(6));
      expect(r2.readRaw(face: 5, mipLevel: 1)[0], equals(105));
    });

    test('2D texture array', () {
      const format = DdsTextureFormat.r8Unorm;
      final payload = Uint8List(4 * 3); // 3 slices of 2x2
      payload[0] = 11;
      payload[4] = 22;
      payload[8] = 33;

      final dds = _buildDx10Dds(
        width: 2,
        height: 2,
        arraySize: 3,
        dxgiFormat: format.dxgiCode,
        payload: payload,
      );
      final reader = DdsReader(dds);
      expect(reader.resourceType, equals(DdsResourceType.texture2D));
      expect(reader.arraySize, equals(3));
      expect(reader.readRaw(arrayIndex: 0)[0], equals(11));
      expect(reader.readRaw(arrayIndex: 1)[0], equals(22));
      expect(reader.readRaw(arrayIndex: 2)[0], equals(33));
    });

    test('3D volume texture with mipDepth halving', () {
      const format = DdsTextureFormat.r8Unorm;
      // 4x4x4 -> mip 0: 4 slices of 16 bytes = 64
      //          mip 1: 2 slices of 4 bytes = 8
      //          mip 2: 1 slice of 1 byte = 1
      final payload = Uint8List(64 + 8 + 1);
      payload[0] = 1;
      payload[16] = 2;
      payload[32] = 3;
      payload[48] = 4;
      payload[64] = 5;
      payload[68] = 6;
      payload[72] = 7;

      final dds = _buildDx10Dds(
        width: 4,
        height: 4,
        depth: 4,
        mipCount: 3,
        dxgiFormat: format.dxgiCode,
        resourceDimension: 4, // TEXTURE3D
        payload: payload,
      );
      final reader = DdsReader(dds);
      expect(reader.resourceType, equals(DdsResourceType.texture3D));
      expect(reader.depth, equals(4));
      expect(reader.mipDepth(0), equals(4));
      expect(reader.mipDepth(1), equals(2));
      expect(reader.mipDepth(2), equals(1));

      expect(reader.readRaw(mipLevel: 0, depthSlice: 3)[0], equals(4));
      expect(reader.readRaw(mipLevel: 1, depthSlice: 1)[0], equals(6));
      expect(reader.readRaw(mipLevel: 2, depthSlice: 0)[0], equals(7));
    });
  });

  group('Unified RGBA8 decoding', () {
    test('uncompressed RGBA8, BGRA8, R8, A8', () {
      final rgbaDds = _buildDx10Dds(
        width: 1,
        height: 1,
        dxgiFormat: DdsTextureFormat.r8g8b8a8Unorm.dxgiCode,
        payload: Uint8List.fromList([10, 20, 30, 40]),
      );
      expect(
        DdsReader(rgbaDds).readRgba8(),
        equals([10, 20, 30, 40]),
      );

      final bgraDds = _buildDx10Dds(
        width: 1,
        height: 1,
        dxgiFormat: DdsTextureFormat.b8g8r8a8Unorm.dxgiCode,
        payload: Uint8List.fromList([30, 20, 10, 40]),
      );
      expect(
        DdsReader(bgraDds).readRgba8(),
        equals([10, 20, 30, 40]),
      );

      final r8Dds = _buildDx10Dds(
        width: 1,
        height: 1,
        dxgiFormat: DdsTextureFormat.r8Unorm.dxgiCode,
        payload: Uint8List.fromList([128]),
      );
      expect(
        DdsReader(r8Dds).readRgba8(),
        equals([128, 0, 0, 255]),
      );

      final a8Dds = _buildDx10Dds(
        width: 1,
        height: 1,
        dxgiFormat: DdsTextureFormat.a8Unorm.dxgiCode,
        payload: Uint8List.fromList([200]),
      );
      expect(
        DdsReader(a8Dds).readRgba8(),
        equals([0, 0, 0, 200]),
      );
    });

    test('BC1 opaque and 1-bit alpha', () {
      // c0 = 0xF800 (pure red), c1 = 0x001F (pure blue), c0 > c1 (4-color opaque)
      // indices: texel 0 -> 0 (red), texel 1 -> 1 (blue)
      final opaqueBlock = Uint8List.fromList([
        0x00, 0xF8, // c0 = 0xF800
        0x1F, 0x00, // c1 = 0x001F
        0x04, 0x00, 0x00, 0x00, // idx0=0, idx1=1
      ]);
      final opaqueDds = _buildDx10Dds(
        width: 2,
        height: 1,
        dxgiFormat: DdsTextureFormat.bc1Unorm.dxgiCode,
        payload: opaqueBlock,
      );
      expect(
        DdsReader(opaqueDds).readRgba8(),
        equals([255, 0, 0, 255, 0, 0, 255, 255]),
      );

      // c0 <= c1 -> index 3 is transparent black (0, 0, 0, 0)
      final alphaBlock = Uint8List.fromList([
        0x00, 0x00,
        0xFF, 0xFF,
        0x03, 0x00, 0x00, 0x00, // texel 0 -> idx 3
      ]);
      final alphaDds = _buildDx10Dds(
        width: 1,
        height: 1,
        dxgiFormat: DdsTextureFormat.bc1Unorm.dxgiCode,
        payload: alphaBlock,
      );
      expect(
        DdsReader(alphaDds).readRgba8(),
        equals([0, 0, 0, 0]),
      );
    });

    test('BC3, BC4, BC5, BC6H, BC7 decode to expected RGBA8', () {
      // BC3: alpha0=100, alpha1=50, all indices=0 -> alpha=100; color=red
      final bc3Block = Uint8List.fromList([
        100, 50, 0, 0, 0, 0, 0, 0, // alpha block
        0x00, 0xF8, 0x00, 0x00, 0, 0, 0, 0, // color block (red)
      ]);
      final bc3Dds = _buildDx10Dds(
        width: 1,
        height: 1,
        dxgiFormat: DdsTextureFormat.bc3Unorm.dxgiCode,
        payload: bc3Block,
      );
      expect(DdsReader(bc3Dds).readRgba8(), equals([255, 0, 0, 100]));

      // BC4: v0=180, v1=0, indices=0 -> (180, 180, 180, 255)
      final bc4Block = Uint8List.fromList([180, 0, 0, 0, 0, 0, 0, 0]);
      final bc4Dds = _buildDx10Dds(
        width: 1,
        height: 1,
        dxgiFormat: DdsTextureFormat.bc4Unorm.dxgiCode,
        payload: bc4Block,
      );
      expect(DdsReader(bc4Dds).readRgba8(), equals([180, 180, 180, 255]));

      // BC5: R=210, G=90 -> (210, 90, 0, 255)
      final bc5Block = Uint8List.fromList([
        210, 0, 0, 0, 0, 0, 0, 0,
        90, 0, 0, 0, 0, 0, 0, 0,
      ]);
      final bc5Dds = _buildDx10Dds(
        width: 1,
        height: 1,
        dxgiFormat: DdsTextureFormat.bc5Unorm.dxgiCode,
        payload: bc5Block,
      );
      expect(DdsReader(bc5Dds).readRgba8(), equals([210, 90, 0, 255]));

      // BC6H invalid mode (0x1F) fills opaque black
      final bc6hBlock = Uint8List(16)..[0] = 0x1F;
      final bc6hDds = _buildDx10Dds(
        width: 1,
        height: 1,
        dxgiFormat: DdsTextureFormat.bc6hUf16.dxgiCode,
        payload: bc6hBlock,
      );
      expect(DdsReader(bc6hDds).readRgba8(), equals([0, 0, 0, 255]));

      // BC7 b0 == 0 fills opaque black
      final bc7Block = Uint8List(16);
      final bc7Dds = _buildDx10Dds(
        width: 1,
        height: 1,
        dxgiFormat: DdsTextureFormat.bc7Unorm.dxgiCode,
        payload: bc7Block,
      );
      expect(DdsReader(bc7Dds).readRgba8(), equals([0, 0, 0, 255]));
    });
  });

  group('Error handling', () {
    test('throws DdsFormatException on invalid headers and truncation', () {
      expect(
        () => DdsReader(Uint8List(10)),
        throwsA(isA<DdsFormatException>()),
      );

      final badMagic = Uint8List(128);
      expect(
        () => DdsReader(badMagic),
        throwsA(isA<DdsFormatException>()),
      );

      final badDwSize = _buildLegacyDds(
        width: 1,
        height: 1,
        pfFlags: 0x4,
        fourCc: _fourCc('DXT1'),
        payload: Uint8List(8),
      );
      ByteData.sublistView(badDwSize).setUint32(4, 100, Endian.little);
      expect(
        () => DdsReader(badDwSize),
        throwsA(isA<DdsFormatException>()),
      );

      final badPfSize = _buildLegacyDds(
        width: 1,
        height: 1,
        pfFlags: 0x4,
        fourCc: _fourCc('DXT1'),
        payload: Uint8List(8),
      );
      ByteData.sublistView(badPfSize).setUint32(76, 16, Endian.little);
      expect(
        () => DdsReader(badPfSize),
        throwsA(isA<DdsFormatException>()),
      );

      // Missing DX10 header bytes
      final truncatedDx10 = _buildLegacyDds(
        width: 1,
        height: 1,
        pfFlags: 0x4,
        fourCc: _fourCc('DX10'),
        payload: Uint8List(4),
      );
      expect(
        () => DdsReader(truncatedDx10),
        throwsA(isA<DdsFormatException>()),
      );

      // Truncated pixel payload
      final truncatedPayload = _buildDx10Dds(
        width: 4,
        height: 4,
        dxgiFormat: DdsTextureFormat.r8g8b8a8Unorm.dxgiCode,
        payload: Uint8List(10), // needs 64
      );
      expect(
        () => DdsReader(truncatedPayload),
        throwsA(isA<DdsFormatException>()),
      );

      // Unsupported FourCC (DXT3)
      final dxt3 = _buildLegacyDds(
        width: 4,
        height: 4,
        pfFlags: 0x4,
        fourCc: _fourCc('DXT3'),
        payload: Uint8List(16),
      );
      expect(
        () => DdsReader(dxt3),
        throwsA(isA<DdsFormatException>()),
      );

      // Unknown DXGI format
      final unknownDxgi = _buildDx10Dds(
        width: 1,
        height: 1,
        dxgiFormat: 9999,
        payload: Uint8List(16),
      );
      expect(
        () => DdsReader(unknownDxgi),
        throwsA(isA<DdsFormatException>()),
      );
    });

    test('throws RangeError on out-of-bounds indices', () {
      final dds = _buildDx10Dds(
        width: 4,
        height: 4,
        mipCount: 2,
        dxgiFormat: DdsTextureFormat.r8Unorm.dxgiCode,
        payload: Uint8List(16 + 4),
      );
      final reader = DdsReader(dds);

      expect(() => reader.mipWidth(-1), throwsRangeError);
      expect(() => reader.mipWidth(2), throwsRangeError);
      expect(() => reader.readRaw(arrayIndex: 1), throwsRangeError);
      expect(() => reader.readRaw(face: 1), throwsRangeError);
      expect(() => reader.readRaw(mipLevel: 2), throwsRangeError);
      expect(() => reader.readRaw(depthSlice: 1), throwsRangeError);
      expect(() => reader.readRgba8(mipLevel: -1), throwsRangeError);
    });
  });
}
