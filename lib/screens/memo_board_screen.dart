import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/memo_card.dart';
import '../engine/firestore_service.dart';
import '../engine/schedule_parser.dart';

/// 메모 보드 화면
/// - 메인 에디터에서 ```로 감싼 텍스트들이 날짜별로 정리되어 보임
/// - 실시간으로 Firestore에서 오늘 문서를 감시하여 메모 추출
class MemoBoardScreen extends StatelessWidget {
  const MemoBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPink,
      appBar: AppBar(
        backgroundColor: AppColors.sidebarPink,
        elevation: 0,
        title: Row(
          children: const [
            Text('📝', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text(
              '메모 보드',
              style: TextStyle(
                color: AppColors.deepRose,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<String?>(
        stream: FirestoreService.watchTodayText(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPink),
            );
          }

          final text = snapshot.data ?? '';
          final dayPlans = ScheduleParser.parse(text);

          // 메모가 있는 날짜만 필터링
          final plansWithMemos =
              dayPlans.where((plan) => plan.memos.isNotEmpty).toList();

          if (plansWithMemos.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: plansWithMemos.length,
            itemBuilder: (context, index) {
              final plan = plansWithMemos[index];
              // 만약 날짜 라벨을 명시하지 않은 백틱 메모라면 오늘 날짜로 대체 표시
              final dateLabel =
                  plan.dateLabel.isEmpty ? '오늘의 메모' : plan.dateLabel;

              return MemoCard(
                dateLabel: dateLabel,
                memos: plan.memos,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '📝',
            style: TextStyle(
              fontSize: 60,
              color: AppColors.primaryPink.withOpacity(0.25),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '아직 저장된 메모가 없어요',
            style: TextStyle(
              color: AppColors.textGray,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '에디터에서 ``` 로 메모를 감싸보세요 💕',
            style: TextStyle(
              color: AppColors.textGray.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
