import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 실시간 파싱 결과를 텍스트에 시각적 효과로 보여주는 엔진
/// - 날짜 줄 → 굵게 + 핑크 + 하트 💕
/// - 백틱(```) 구간 → 노란색 박스 하이라이팅
class TtaTextPainter extends StatelessWidget {
  final String text;

  const TtaTextPainter({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final widgets = <Widget>[];
    // ``` 기준으로 텍스트 전체를 분리 (홀수 인덱스가 백틱 안쪽 컨텐츠)
    final chunks = text.split('```');

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final isMemoBlock = (i % 2 != 0);

      if (chunk.isEmpty && i == chunks.length - 1 && !isMemoBlock) {
        continue;
      }

      if (isMemoBlock) {
        // 메모 블록 안쪽
        widgets.add(_buildMemoStart());
        
        final lines = chunk.split('\n');
        for (var line in lines) {
          widgets.add(_buildMemoLine(line));
        }

        // 덩어리가 마지막이 아니라는 건 닫는 백틱이 쳐졌다는 의미
        if (i < chunks.length - 1) {
          widgets.add(_buildMemoEnd());
        }
      } else {
        // 백틱 바깥쪽 (일반 텍스트 영역)
        final lines = chunk.split('\n');
        for (int j = 0; j < lines.length; j++) {
          final line = lines[j];
          if (line.isEmpty) {
            // 마지막 줄이 아닌 경우 빈 줄 처리
            if (j < lines.length - 1) widgets.add(const SizedBox(height: 24));
            continue;
          }
          if (_isDateLine(line)) {
            widgets.add(_buildDateLine(line));
          } else {
            widgets.add(_buildNormalLine(line));
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// 날짜 줄 판단: 숫자 + 년/월/일 키워드가 함께 있으면 날짜 제목
  bool _isDateLine(String line) {
    final hasNumber = RegExp(r'\d').hasMatch(line);
    final hasDateKeyword =
        line.contains('년') || line.contains('월') || line.contains('일');
    return hasNumber && hasDateKeyword;
  }

  /// 날짜 줄 위젯 (굵게, 핑크, 하트 아이콘)
  Widget _buildDateLine(String line) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                text: line,
                style: const TextStyle(
                  color: AppColors.dateTextColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.8,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 하트 아이콘 - 날짜 인식 피드백
          const _HeartPopWidget(),
        ],
      ),
    );
  }

  /// 일반 줄 위젯
  Widget _buildNormalLine(String line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Text(
        line.isEmpty ? ' ' : line,
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 15,
          height: 1.75,
        ),
      ),
    );
  }

  /// 메모 블록 시작 표시
  Widget _buildMemoStart() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.memoHighlight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        border: Border.all(color: AppColors.memoHighlightBorder, width: 1.2),
      ),
      child: Row(
        children: const [
          Text('📝', style: TextStyle(fontSize: 12)),
          SizedBox(width: 6),
          Text(
            '메모 시작',
            style: TextStyle(
              color: Color(0xFFF57F17),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 메모 블록 끝 표시
  Widget _buildMemoEnd() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.memoHighlight,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        border: Border(
          left: BorderSide(color: AppColors.memoHighlightBorder, width: 1.2),
          right: BorderSide(color: AppColors.memoHighlightBorder, width: 1.2),
          bottom: BorderSide(color: AppColors.memoHighlightBorder, width: 1.2),
        ),
      ),
      child: Row(
        children: const [
          Text('✅', style: TextStyle(fontSize: 12)),
          SizedBox(width: 6),
          Text(
            '메모 저장됨',
            style: TextStyle(
              color: Color(0xFFF57F17),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 메모 블록 안의 줄 위젯 (노란 배경)
  Widget _buildMemoLine(String line) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: const BoxDecoration(
        color: AppColors.memoHighlight,
        border: Border.symmetric(
          vertical: BorderSide(color: AppColors.memoHighlightBorder, width: 1.2),
        ),
      ),
      child: Text(
        line.isEmpty ? ' ' : line,
        style: const TextStyle(
          color: Color(0xFF5D4037),
          fontSize: 15,
          height: 1.75,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

/// 날짜 인식 시 나타나는 작은 하트 애니메이션 위젯
class _HeartPopWidget extends StatefulWidget {
  const _HeartPopWidget();

  @override
  State<_HeartPopWidget> createState() => _HeartPopWidgetState();
}

class _HeartPopWidgetState extends State<_HeartPopWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(
        opacity: _opacity,
        child: const Text('💕', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
