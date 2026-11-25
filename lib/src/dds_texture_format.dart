enum DdsTextureFormat {
  r8g8b8a8Unorm(
    dxgiCode: 28,
    isBlockCompressed: false,
    blockByteSize: 4,
    bytesPerPixel: 4.0,
  ),
  r8g8b8a8UnormSrgb(
    dxgiCode: 29,
    isBlockCompressed: false,
    blockByteSize: 4,
    bytesPerPixel: 4.0,
  ),
  r8Unorm(
    dxgiCode: 61,
    isBlockCompressed: false,
    blockByteSize: 1,
    bytesPerPixel: 1.0,
  ),
  a8Unorm(
    dxgiCode: 65,
    isBlockCompressed: false,
    blockByteSize: 1,
    bytesPerPixel: 1.0,
  ),
  bc1Unorm(
    dxgiCode: 71,
    isBlockCompressed: true,
    blockByteSize: 8,
    bytesPerPixel: 0.5,
  ),
  bc1UnormSrgb(
    dxgiCode: 72,
    isBlockCompressed: true,
    blockByteSize: 8,
    bytesPerPixel: 0.5,
  ),
  bc3Unorm(
    dxgiCode: 77,
    isBlockCompressed: true,
    blockByteSize: 16,
    bytesPerPixel: 1.0,
  ),
  bc3UnormSrgb(
    dxgiCode: 78,
    isBlockCompressed: true,
    blockByteSize: 16,
    bytesPerPixel: 1.0,
  ),
  bc4Unorm(
    dxgiCode: 80,
    isBlockCompressed: true,
    blockByteSize: 8,
    bytesPerPixel: 0.5,
  ),
  bc5Unorm(
    dxgiCode: 83,
    isBlockCompressed: true,
    blockByteSize: 16,
    bytesPerPixel: 1.0,
  ),
  b8g8r8Unorm(
    dxgiCode: null,
    isBlockCompressed: false,
    blockByteSize: 3,
    bytesPerPixel: 3.0,
  ),
  b8g8r8a8Unorm(
    dxgiCode: 87,
    isBlockCompressed: false,
    blockByteSize: 4,
    bytesPerPixel: 4.0,
  ),
  bc6hUf16(
    dxgiCode: 95,
    isBlockCompressed: true,
    blockByteSize: 16,
    bytesPerPixel: 1.0,
  ),
  bc7Unorm(
    dxgiCode: 98,
    isBlockCompressed: true,
    blockByteSize: 16,
    bytesPerPixel: 1.0,
  ),
  bc7UnormSrgb(
    dxgiCode: 99,
    isBlockCompressed: true,
    blockByteSize: 16,
    bytesPerPixel: 1.0,
  );

  const DdsTextureFormat({
    required this.dxgiCode,
    required this.isBlockCompressed,
    required this.blockByteSize,
    required this.bytesPerPixel,
  });

  /// Numeric `DXGI_FORMAT` enum value, or `null` for legacy-only formats.
  final int? dxgiCode;

  /// True for 4x4 block-compressed BCn formats (`BC1`..`BC7`).
  final bool isBlockCompressed;

  /// Bytes per 4x4 block (for BCn) or per pixel (for uncompressed formats).
  final int blockByteSize;

  /// Average bytes per texel (`0.5`, `1.0`, or `4.0`).
  final double bytesPerPixel;

  /// Computes the expected linear byte size for a mip level of [width] x [height].
  int mipByteSize(int width, int height) {
    if (isBlockCompressed) {
      final bw = (width + 3) ~/ 4;
      final bh = (height + 3) ~/ 4;
      return bw * bh * blockByteSize;
    }
    return width * height * blockByteSize;
  }

  static final Map<int, DdsTextureFormat> _byDxgiCode = {
    for (final v in values) ?v.dxgiCode: v,
  };

  @override
  String toString() {
    return name.toUpperCase().replaceAll("UNORM", " ");
  }

  /// Looks up a [DdsTextureFormat] by its `DXGI_FORMAT` integer code.
  static DdsTextureFormat? fromDxgiCode(int code) => _byDxgiCode[code];
}
