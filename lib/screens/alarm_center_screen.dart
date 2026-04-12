import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../engine/firestore_service.dart';
import '../engine/schedule_parser.dart';
import '../engine/notification_service.dart';

/// 알람 센터 화면
/// - 시스템이 자동으로 예약한 오늘의 알람 목록을 확인하는 화면
/// - 에디터 텍스트를 파싱하여 시작 시간/종료 시간 기준으로 알람 생성
class AlarmCenterScreen extends StatefulWidget {
  const AlarmCenterScreen({super.key});

  @override
  State<AlarmCenterScreen> createState() => _AlarmCenterScreenState();
}

class _AlarmItem {
  final int id;
  final String time;
  final String label;
  final bool isDigest;

  const _AlarmItem({
    required this.id,
    required this.time,
    required this.label,
    required this.isDigest,
  });
}

class _AlarmCenterScreenState extends State<AlarmCenterScreen> {
  final Map<int, bool> _alarmEnabled = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPink,
      appBar: AppBar(
        backgroundColor: AppColors.sidebarPink,
        elevation: 0,
        title: Row(
          children: const [
            Text('🔔', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text(
              '알림 센터',
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
          final alarms = _buildAlarmItems(dayPlans);
          _syncEnabledState(alarms);

          if (alarms.isEmpty) {
            return _buildEmptyState(context);
          }

          return Column(
            children: [
              _buildInfoCard(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  itemCount: alarms.length,
                  itemBuilder: (context, index) {
                    final alarm = alarms[index];
                    return _buildAlarmTile(alarm, dayPlans);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      children: [
        _buildInfoCard(),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '🔔',
                  style: TextStyle(
                    fontSize: 60,
                    color: AppColors.primaryPink.withOpacity(0.25),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '아직 등록된 알림이 없어요',
                  style: TextStyle(
                    color: AppColors.textGray,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.lightPink.withOpacity(0.3),
            AppColors.primaryPink.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Text('💕', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 예약 알림',
                  style: TextStyle(
                    color: AppColors.deepRose,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '에디터에서 계획을 입력하면 알림이 자동으로 여기 나타납니다.',
                  style: TextStyle(
                    color: AppColors.textGray,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_AlarmItem> _buildAlarmItems(List<DayPlan> dayPlans) {
    final alarms = <_AlarmItem>[];
    final now = DateTime.now();
    final activePlan = ScheduleParser.pickActivePlan(dayPlans, now: now);
    if (activePlan == null) return alarms;

    final baseDate = ScheduleParser.resolvePlanDate(activePlan.dateLabel, now);
    int notificationId = 0;

    DateTime? firstStart;
    for (final block in activePlan.blocks) {
      if (block.startTime == null) continue;
      final candidate = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        block.startTime!.hour,
        block.startTime!.minute,
      );
      if (firstStart == null || candidate.isBefore(firstStart)) {
        firstStart = candidate;
      }
    }

    final digestTime = firstStart?.subtract(const Duration(minutes: 30));
    if (digestTime != null && digestTime.isAfter(now)) {
      alarms.add(_AlarmItem(
        id: notificationId,
        time:
            '${digestTime.hour.toString().padLeft(2, '0')}:${digestTime.minute.toString().padLeft(2, '0')}',
        label: '💕 데일리 다이제스트 - 오늘 하루 브리핑',
        isDigest: true,
      ));
      notificationId++;
    }

    for (final block in activePlan.blocks) {
      if (block.startTime != null) {
        final start = DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          block.startTime!.hour,
          block.startTime!.minute,
        );
        if (start.isAfter(now)) {
          alarms.add(_AlarmItem(
            id: notificationId,
            time: block.startTime.toString(),
            label: block.rawText.split('\n').first.trim(),
            isDigest: false,
          ));
          notificationId++;
        }
      }

      if (block.endTime != null) {
        DateTime? end;
        if (block.isOvernight) {
          end = ScheduleParser.getOvernightEndTime(block, baseDate);
        } else {
          end = DateTime(
            baseDate.year,
            baseDate.month,
            baseDate.day,
            block.endTime!.hour,
            block.endTime!.minute,
          );
        }

        if (end != null && end.isAfter(now)) {
          final timeStr = block.isOvernight
              ? '익일 ${block.endTime.toString().replaceFirst('25:', '01:').replaceFirst('24:', '00:')}'
              : block.endTime.toString();

          alarms.add(_AlarmItem(
            id: notificationId,
            time: timeStr,
            label: '${block.rawText.split('\n').first.trim()} 종료',
            isDigest: false,
          ));
          notificationId++;
        }
      }
    }

    return alarms;
  }

  void _syncEnabledState(List<_AlarmItem> alarms) {
    final validIds = alarms.map((e) => e.id).toSet();
    _alarmEnabled.removeWhere((id, _) => !validIds.contains(id));
    for (final alarm in alarms) {
      _alarmEnabled.putIfAbsent(alarm.id, () => true);
    }
  }

  Widget _buildAlarmTile(_AlarmItem alarm, List<DayPlan> dayPlans) {
    final isDigest = alarm.isDigest;
    final isEnabled = _alarmEnabled[alarm.id] ?? true;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDigest
            ? AppColors.primaryPink.withOpacity(0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDigest ? AppColors.lightPink : AppColors.divider,
          width: isDigest ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDigest
                ? AppColors.primaryPink.withOpacity(0.15)
                : AppColors.sidebarPink,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              isDigest ? '💕' : '🔔',
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        title: Text(
          alarm.time,
          style: TextStyle(
            color: isDigest ? AppColors.primaryPink : AppColors.dateTextColor,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          alarm.label,
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        trailing: Switch(
          value: isEnabled,
          onChanged: (v) async {
            setState(() {
              _alarmEnabled[alarm.id] = v;
            });

            if (!v) {
              await NotificationService.cancelAlarmById(alarm.id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('알림을 껐어요: ${alarm.time}'),
                  backgroundColor: AppColors.primaryPink,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              );
              return;
            }

            await NotificationService.scheduleAlarms(dayPlans);
            if (!mounted) return;
            setState(() {
              for (final item in _buildAlarmItems(dayPlans)) {
                _alarmEnabled[item.id] = true;
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('알림을 다시 켰어요.'),
                backgroundColor: AppColors.primaryPink,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            );
          },
          activeColor: AppColors.primaryPink,
        ),
      ),
    );
  }
}
