import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final bytes = await File('assets/app_logo.png').readAsBytes();
  final image = img.decodeImage(bytes);
  if (image == null) return;

  // 윈도우용 정규 ICO 사이즈들 (16, 32, 48, 256)
  final sizes = [16, 32, 48, 256];
  
  // 여기서는 단순히 가장 큰 256버전을 ico 이름으로 저장하거나, 
  // 라이브러리가 지원한다면 멀티레이어로 저장합니다.
  // flutter_launcher_icons가 내부적으로 사용하는 것과 유사하게 처리하되 
  // 투명도가 유지되도록 옵션을 체크합니다.
  
  for (var size in sizes) {
    final resized = img.copyResize(image, width: size, height: size, interpolation: img.Interpolation.average);
    final icoBytes = img.encodeIco(resized);
    await File('windows/runner/resources/app_icon_$size.ico').writeAsBytes(icoBytes);
  }
  
  // 최종적으로 가장 품질이 좋은 256버전을 메인 아이콘으로 복사
  final mainIco = await File('windows/runner/resources/app_icon_256.ico').readAsBytes();
  await File('windows/runner/resources/app_icon.ico').writeAsBytes(mainIco);
  
  print('ICO generation complete with transparency.');
}