import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 메모 보드에서 날짜별로 묶어서 보여주는 카드 위젯
class MemoCard extends StatelessWidget {
  final String dateLabel;    // 예: "2026년 4월 9일 (목)"
  final List<String> memos; // 해당 날짜에 있는 메모들

  const MemoCard({
    super.key,
    required this.dateLabel,
    required this.memos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPink.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.sidebarPink,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Text('💕', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    color: AppColors.deepRose,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          // 메모 내용 리스트
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: memos.asMap().entries.map((entry) {
                final index = entry.key;
                final memo = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index > 0)
                      Divider(
                        color: AppColors.divider,
                        height: 20,
                        thickness: 0.8,
                      ),
                    Text(
                      memo,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                        height: 1.75,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
