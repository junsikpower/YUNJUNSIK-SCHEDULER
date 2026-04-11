import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

void main() async {
  final bytes = await File('assets/app_logo.png').readAsBytes();
  final srcImage = img.decodeImage(bytes);
  if (srcImage == null) {
    print('Failed to decode image');
    return;
  }

  // 윈도우 작업표시줄과 탐색기에서 요구하는 필수 사이즈들
  final sizes = [16, 32, 48, 256];
  final List<Uint8List> pngDataList = [];

  // 각 사이즈별로 PNG 데이터 생성 (투명도 유지)
  for (var size in sizes) {
    final resized = img.copyResize(srcImage, width: size, height: size, interpolation: img.Interpolation.average);
    pngDataList.add(Uint8List.fromList(img.encodePng(resized)));
  }

  // ICO 파일 생성 (수동 바이너리 패킹)
  final out = BytesBuilder();
  
  // 1. ICO Header (6 bytes)
  out.add([0, 0, 1, 0]); // Reserved(2), Type(2: ICO)
  out.addByte(sizes.length); // Count (low byte)
  out.addByte(0); // Count (high byte)

  int currentOffset = 6 + (sizes.length * 16);

  // 2. Directory Entries (16 bytes per size)
  for (int i = 0; i < sizes.length; i++) {
    int size = sizes[i];
    int dataSize = pngDataList[i].length;

    out.addByte(size == 256 ? 0 : size); // Width (0 means 256)
    out.addByte(size == 256 ? 0 : size); // Height (0 means 256)
    out.addByte(0); // Colors (0 for >256 colors)
    out.addByte(0); // Reserved
    out.add([1, 0]); // Planes (1)
    out.add([32, 0]); // Bitcount (32)
    
    // Size (4 bytes, little-endian)
    out.add([dataSize & 0xFF, (dataSize >> 8) & 0xFF, (dataSize >> 16) & 0xFF, (dataSize >> 24) & 0xFF]);
    
    // Offset (4 bytes, little-endian)
    out.add([currentOffset & 0xFF, (currentOffset >> 8) & 0xFF, (currentOffset >> 16) & 0xFF, (currentOffset >> 24) & 0xFF]);
    
    currentOffset += dataSize;
  }

  // 3. ImageData (실제 PNG 바이너리들)
  for (var data in pngDataList) {
    out.add(data);
  }

  final finalIcon = out.toBytes();
  await File('windows/runner/resources/app_icon.ico').writeAsBytes(finalIcon);
  print('Multi-layer ICO created successfully (Size: ${finalIcon.length} bytes)');
}
