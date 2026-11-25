import 'dart:typed_data';

import 'package:dds_format/dds_format.dart';

void main() {
  final ddsBytes = _buildSample2x2Rgba8Dds();
  final reader = DdsReader(ddsBytes);

  print('Resource: ${reader.resourceType}');
  print('Format: ${reader.format}');
  print('Dimensions: ${reader.width}x${reader.height}x${reader.depth}');
  print('Mips: ${reader.mipCount}, Array: ${reader.arraySize}');

  final rawMip0 = reader.readRaw(mipLevel: 0);
  final rgbaMip0 = reader.readRgba8(mipLevel: 0);

  print('Raw mip 0 bytes: ${rawMip0.length}');
  print('RGBA8 mip 0 bytes: ${rgbaMip0.length}');
}

Uint8List _buildSample2x2Rgba8Dds() {
  final bytes = Uint8List(128 + 16);
  final view = ByteData.sublistView(bytes);
  view.setUint32(0, 0x20534444, Endian.little); // "DDS "
  view.setUint32(4, 124, Endian.little); // dwSize
  view.setUint32(
    8,
    0x1007,
    Endian.little,
  ); // CAPS | HEIGHT | WIDTH | PIXELFORMAT
  view.setUint32(12, 2, Endian.little); // height
  view.setUint32(16, 2, Endian.little); // width
  view.setUint32(76, 32, Endian.little); // ddspf.dwSize
  view.setUint32(80, 0x41, Endian.little); // DDPF_RGB | DDPF_ALPHAPIXELS
  view.setUint32(88, 32, Endian.little); // dwRGBBitCount
  view.setUint32(92, 0x000000ff, Endian.little); // R
  view.setUint32(96, 0x0000ff00, Endian.little); // G
  view.setUint32(100, 0x00ff0000, Endian.little); // B
  view.setUint32(104, 0xff000000, Endian.little); // A
  view.setUint32(108, 0x1000, Endian.little); // DDSCAPS_TEXTURE

  // 2x2 RGBA8 pixels (red, green, blue, white)
  bytes.setRange(128, 144, [
    255,
    0,
    0,
    255,
    0,
    255,
    0,
    255,
    0,
    0,
    255,
    255,
    255,
    255,
    255,
    255,
  ]);
  return bytes;
}
